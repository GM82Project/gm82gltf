const std = @import("std");
const GLTF = @import("GLTF.zig");
const testing = std.testing;

const GLB = struct {
    arena: std.heap.ArenaAllocator,
    json: std.json.Parsed(GLTF),
    buffers: [][]const u8,
    fn deinit(self: @This()) void {
        self.json.deinit();
    }
};

var g_allocator = std.heap.GeneralPurposeAllocator(.{}){};
var g_gltfs = std.AutoArrayHashMap(i32, GLB).init(g_allocator.allocator());
var g_gltf_next_id: i32 = 0;
var g_stringret: ?[:0]u8 = null;

fn return_string(string: []const u8) [*:0]const u8 {
    // make new string
    const new_string = g_allocator.allocator().allocSentinel(u8, string.len, 0) catch return "";
    std.mem.copyForwards(u8, new_string, string);
    // replace with new string
    if (g_stringret) |stringret| {
        g_allocator.allocator().free(stringret);
    }
    g_stringret = new_string;
    return new_string;
}

// INTERNAL GETTERS

fn array_get(T: type, array: []const T, id: anytype) ?*const T {
    const id_i: usize = if (@TypeOf(id) == usize) id else @intFromFloat(id);
    if (id_i >= array.len) {
        return null;
    }
    return &array[id_i];
}

fn get_gltf(id: f64) ?*const GLTF {
    const glb = g_gltfs.getPtr(@intFromFloat(id)) orelse return null;
    return &glb.*.json.value;
}

fn get_material(gltf_id: f64, material_id: f64) ?*const GLTF.Material {
    const gltf = get_gltf(gltf_id) orelse return null;
    const materials = gltf.materials orelse return null;
    return array_get(GLTF.Material, materials, material_id);
}

fn get_texture(gltf_id: f64, texture_id: f64) ?*const GLTF.Texture {
    const gltf = get_gltf(gltf_id) orelse return null;
    const textures = gltf.textures orelse return null;
    return array_get(GLTF.Texture, textures, texture_id);
}

fn get_node(gltf_id: f64, node_id: f64) ?*const GLTF.Node {
    const gltf = get_gltf(gltf_id) orelse return null;
    const nodes = gltf.nodes orelse return null;
    return array_get(GLTF.Node, nodes, node_id);
}

fn get_node_mesh(gltf_id: f64, node_id: f64) ?*const GLTF.Mesh {
    const gltf = get_gltf(gltf_id) orelse return null;
    const nodes = gltf.nodes orelse return null;
    const meshes = gltf.meshes orelse return null;
    const node = array_get(GLTF.Node, nodes, node_id) orelse return null;
    const mesh_id = node.mesh orelse return null;

    return array_get(GLTF.Mesh, meshes, mesh_id);
}

fn get_node_primitive(gltf_id: f64, node_id: f64, primitive_id: f64) ?*const GLTF.Mesh.Primitive {
    const mesh = get_node_mesh(gltf_id, node_id) orelse return null;
    return array_get(GLTF.Mesh.Primitive, mesh.primitives, primitive_id);
}

fn get_buffer_view(glb: *GLB, id: usize) ?[]const u8 {
    const bufferViews = glb.json.value.bufferViews orelse return null;
    const bv = bufferViews[id];
    return glb.buffers[bv.buffer][bv.byteOffset .. bv.byteOffset + bv.byteLength];
}

// EXPORTS

export fn gltf_load(filename: [*:0]const u8) f64 {
    // will be deleted if loading fails
    var owned_alloc = std.heap.ArenaAllocator.init(g_allocator.allocator());

    blk: {
        const filename_slice = filename[0..std.mem.len(filename)];
        const filename_absolute = std.fs.path.isAbsolute(filename_slice);
        var file =
            (if (filename_absolute) std.fs.openFileAbsolute(filename_slice, .{}) else std.fs.cwd().openFile(filename_slice, .{})) catch break :blk;

        const filename_dir = std.fs.path.dirname(filename_slice);
        var gltfDir =
            if (filename_absolute) std.fs.openDirAbsolute(filename_dir orelse break :blk, .{}) catch break :blk else if (filename_dir) |dir| std.fs.cwd().openDir(dir, .{}) catch break :blk else std.fs.cwd();
        defer if (filename_dir) |_| {
            gltfDir.close();
        };

        // GLB format
        const magic = file.reader().readInt(u32, .little) catch break :blk;
        if (magic != 0x46546c67) {
            break :blk;
        }

        const version = file.reader().readInt(u32, .little) catch break :blk;
        if (version != 2) {
            break :blk;
        }

        const fileLength = file.reader().readInt(u32, .little) catch break :blk;

        var temp_alloc = std.heap.ArenaAllocator.init(g_allocator.allocator());
        defer temp_alloc.deinit();

        var jsonParsed: ?std.json.Parsed(GLTF) = null;
        var glbBinary: ?[]const u8 = null;

        var remainingLength = fileLength - 12;
        while (remainingLength > 0) {
            const chunkLength = file.reader().readInt(u32, .little) catch break :blk;
            remainingLength -= chunkLength + 8;
            const chunkType = file.reader().readInt(u32, .little) catch break :blk;
            switch (chunkType) {
                0x4e4f534a => { // JSON
                    // there can only be one
                    if (jsonParsed) |_| break :blk;
                    const jsonData = temp_alloc.allocator().alloc(u8, chunkLength) catch break :blk;
                    const jsonSize = file.readAll(jsonData) catch break :blk;
                    if (jsonSize != chunkLength) break :blk;
                    jsonParsed = std.json.parseFromSlice(GLTF, owned_alloc.allocator(), jsonData, .{}) catch |err| {
                        std.log.err("{}", .{err});
                        break :blk;
                    };
                },
                0x004e4942 => { // BIN
                    // there can only be one
                    if (glbBinary) |_| break :blk;
                    const blob = owned_alloc.allocator().alignedAlloc(u8, 4, chunkLength) catch break :blk;
                    const blobSize = file.readAll(blob) catch break :blk;
                    if (blobSize != chunkLength) break :blk;
                    glbBinary = blob;
                },
                else => file.seekBy(chunkLength) catch break :blk,
            }
        }

        const parsed = jsonParsed orelse break :blk;

        const bufferCount = (parsed.value.buffers orelse &[0]GLTF.Buffer{}).len;
        const buffers = g_allocator.allocator().alloc([]const u8, bufferCount) catch break :blk;

        if (parsed.value.buffers) |bufferData| {
            for (bufferData, 0..) |buffer, i| {
                if (i == 0) {
                    if (glbBinary) |blob| {
                        if (buffer.byteLength != blob.len) {
                            break :blk;
                        }
                        buffers[i] = blob;
                        continue;
                    }
                }
                // for now, we count these as invalid
                break :blk;
            }
        }

        const id = g_gltf_next_id;
        g_gltf_next_id += 1;
        g_gltfs.put(id, .{
            .arena = owned_alloc,
            .json = parsed,
            .buffers = buffers,
        }) catch break :blk;
        return @floatFromInt(id);
    }

    owned_alloc.deinit();
    return -1;
}

export fn gltf_destroy(id: f64) f64 {
    const entry = g_gltfs.fetchSwapRemove(@intFromFloat(id)) orelse return 0;
    entry.value.deinit();
    return 0;
}

export fn gltf_get_node(gltf_id: f64, name: [*:0]const u8) f64 {
    const gltf = get_gltf(gltf_id) orelse return -1;
    const nodes = gltf.nodes orelse return -1;
    for (nodes, 0..) |n, i| {
        if (n.name) |n_name| {
            if (std.mem.eql(u8, n_name, name[0..std.mem.len(name)])) {
                return @floatFromInt(i);
            }
        }
    }
    return -1;
}

export fn gltf_node_child_count(gltf_id: f64, node_id: f64) f64 {
    const node = get_node(gltf_id, node_id) orelse return -1;
    const children = node.children orelse return 0;
    return @floatFromInt(children.len);
}

export fn gltf_node_child(gltf_id: f64, node_id: f64, child_id: f64) f64 {
    const node = get_node(gltf_id, node_id) orelse return -1;
    const children = node.children orelse return -1;
    const child = array_get(usize, children, child_id) orelse return -1;
    return @floatFromInt(child.*);
}

export fn gltf_node_primitive_count(gltf_id: f64, node_id: f64) f64 {
    const mesh = get_node_mesh(gltf_id, node_id) orelse return -1;
    return @floatFromInt(mesh.primitives.len);
}

export fn gltf_node_primitive_material(gltf_id: f64, node_id: f64, primitive_id: f64) f64 {
    const primitive = get_node_primitive(gltf_id, node_id, primitive_id) orelse return -1;
    return @floatFromInt(primitive.material orelse return -1);
}

export fn gltf_material_base_texture(gltf_id: f64, material_id: f64) f64 {
    const material = get_material(gltf_id, material_id) orelse return -1;
    const baseColorTexture = material.pbrMetallicRoughness.baseColorTexture orelse return -1;
    return @floatFromInt(baseColorTexture.index);
}

export fn gltf_material_base_texcoord(gltf_id: f64, material_id: f64) f64 {
    const material = get_material(gltf_id, material_id) orelse return -1;
    const baseColorTexture = material.pbrMetallicRoughness.baseColorTexture orelse return -1;
    return @floatFromInt(baseColorTexture.texCoord);
}

test "gltf stuff" {
    // https://github.com/KhronosGroup/glTF-Sample-Models/blob/main/2.0/Box/glTF-Binary/Box.glb
    try testing.expectEqual(0, gltf_load("Box.glb"));
    try testing.expectEqual(1, gltf_node_child_count(0, 0));
    try testing.expectEqual(1, gltf_node_child(0, 0, 0));
    try testing.expectEqual(648, g_gltfs.get(0).?.buffers[0].len);
    try testing.expectEqual(0, gltf_destroy(0));
}
