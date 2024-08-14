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
var g_gltf_next_id: i32 = 1;
var g_stringret: ?[:0]u8 = null;
var g_matrix: [16]f32 = undefined;

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

fn array_get(T: type, array: ?[]const T, id: anytype) ?*const T {
    const array_real = array orelse return null;
    const id_i: usize = switch (@TypeOf(id)) {
        ?usize => id orelse return null,
        usize => id,
        f64 => @intFromFloat(id),
        else => @compileError("unknown id type"),
    };
    if (id_i >= array_real.len) {
        return null;
    }
    return &array_real[id_i];
}

fn get_glb(id: f64) ?*const GLB {
    return g_gltfs.getPtr(@intFromFloat(id));
}

fn get_gltf(id: f64) ?*const GLTF {
    const glb = get_glb(id) orelse return null;
    return &glb.*.json.value;
}

fn get_material(gltf_id: f64, material_id: f64) ?*const GLTF.Material {
    const gltf = get_gltf(gltf_id) orelse return null;
    return array_get(GLTF.Material, gltf.materials, material_id);
}

fn get_texture(gltf_id: f64, texture_id: f64) ?*const GLTF.Texture {
    const gltf = get_gltf(gltf_id) orelse return null;
    return array_get(GLTF.Texture, gltf.textures, texture_id);
}

fn get_sampler(gltf_id: f64, texture_id: f64) ?*const GLTF.Sampler {
    const gltf = get_gltf(gltf_id) orelse return null;
    const texture = array_get(GLTF.Texture, gltf.textures, texture_id) orelse return null;
    return array_get(GLTF.Sampler, gltf.samplers orelse return null, texture.sampler);
}

fn get_node(gltf_id: f64, node_id: f64) ?*const GLTF.Node {
    const gltf = get_gltf(gltf_id) orelse return null;
    return array_get(GLTF.Node, gltf.nodes, node_id);
}

fn get_camera(gltf_id: f64, camera_id: f64) ?*const GLTF.Camera {
    const gltf = get_gltf(gltf_id) orelse return null;
    return array_get(GLTF.Camera, gltf.cameras, camera_id);
}

fn get_mesh(gltf_id: f64, mesh_id: f64) ?*const GLTF.Mesh {
    const gltf = get_gltf(gltf_id) orelse return null;
    return array_get(GLTF.Mesh, gltf.meshes, mesh_id);
}

fn get_mesh_primitive(gltf_id: f64, mesh_id: f64, primitive_id: f64) ?*const GLTF.Mesh.Primitive {
    const mesh = get_mesh(gltf_id, mesh_id) orelse return null;
    return array_get(GLTF.Mesh.Primitive, mesh.primitives, primitive_id);
}

fn get_accessor(gltf_id: f64, accessor_id: f64) ?*const GLTF.Accessor {
    const gltf = get_gltf(gltf_id) orelse return null;
    return array_get(GLTF.Accessor, gltf.accessors, accessor_id);
}

fn get_buffer_view(glb: *GLB, id: usize) ?[]const u8 {
    const bufferViews = glb.json.value.bufferViews orelse return null;
    const bv = bufferViews[id];
    return glb.buffers[bv.buffer][bv.byteOffset .. bv.byteOffset + bv.byteLength];
}

fn create_transform(node: *GLTF.Node) [16]f32 {
    var out: [16]f32 = undefined;
    const qx = node.rotation[0];
    const qxx = qx * qx;
    const qy = node.rotation[1];
    const qyy = qy * qy;
    const qz = node.rotation[2];
    const qzz = qz * qz;
    const qw = node.rotation[4];

    const scaling_row1 = @Vector(4, f32){ 1 - 2 * qyy - 2 * qzz, 2 * qx * qy - 2 * qz * qw, 2 * qx * qz - 2 * qy * qw, 0 };
    const scaling_row2 = @Vector(4, f32){ 2 * qx * qy, 1 - 2 * qxx - 2 * qzz, 2 * qy * qz + 2 * qx * qw, 0 };
    const scaling_row3 = @Vector(4, f32){ 2 * qx * qz + 2 * qy * qw, 2 * qy * qz - 2 * qx * qw, 1 - 2 * qxx - 2 * qyy, 0 };
    @memcpy(out[0..4], scaling_row1 * @as(@Vector(4, f32), @splat(node.scale[0])));
    @memcpy(out[4..8], scaling_row2 * @as(@Vector(4, f32), @splat(node.scale[1])));
    @memcpy(out[8..12], scaling_row3 * @as(@Vector(4, f32), @splat(node.scale[2])));
    @memcpy(out[12..15], node.translation);
    out[15] = 1;

    return out;
}

fn multiply_matrices(m_a: [16]f32, m_b: [16]f32) [16]f32 {
    const b_transposed = [4]@Vector(4, f32){
        .{ m_b[0], m_b[4], m_b[8], m_b[12] },
        .{ m_b[1], m_b[5], m_b[9], m_b[13] },
        .{ m_b[2], m_b[6], m_b[10], m_b[14] },
        .{ m_b[3], m_b[7], m_b[11], m_b[15] },
    };
    var out: [16]f32 = undefined;
    for (0..4) |y| {
        const a_row: @Vector(4, f32) = m_a[y * 4 .. y * 4 + 4];
        for (0..4) |x| {
            out[y * 4 + x] = @reduce(.Add, a_row * b_transposed[y]);
        }
    }
    return out;
}

// EXPORTS

export fn __gltf_reset() f64 {
    var it = g_gltfs.iterator();
    while (it.next()) |entry| {
        entry.value_ptr.deinit();
    }
    g_gltfs.clearAndFree();
    g_gltf_next_id = 1;
    return 0;
}

export fn __gltf_load(filename: [*:0]const u8) f64 {
    // will be deleted if loading fails
    var owned_alloc = std.heap.ArenaAllocator.init(g_allocator.allocator());

    blk: {
        const filename_slice = std.mem.span(filename);
        var file = std.fs.cwd().openFile(filename_slice, .{}) catch break :blk;

        const filename_dir = std.fs.path.dirname(filename_slice);
        var gltfDir =
            if (filename_dir) |dir| std.fs.cwd().openDir(dir, .{}) catch break :blk else std.fs.cwd();
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

        var json_parsed: ?std.json.Parsed(GLTF) = null;
        var glb_binary: ?[]const u8 = null;

        var remaining_length = fileLength - 12;
        while (remaining_length > 0) {
            const chunk_length = file.reader().readInt(u32, .little) catch break :blk;
            remaining_length -= chunk_length + 8;
            const chunk_type = file.reader().readInt(u32, .little) catch break :blk;
            switch (chunk_type) {
                0x4e4f534a => { // JSON
                    // there can only be one
                    if (json_parsed) |_| break :blk;
                    const json_data = temp_alloc.allocator().alloc(u8, chunk_length) catch break :blk;
                    const json_size = file.readAll(json_data) catch break :blk;
                    if (json_size != chunk_length) break :blk;
                    json_parsed = std.json.parseFromSlice(GLTF, owned_alloc.allocator(), json_data, .{ .ignore_unknown_fields = true, .allocate = .alloc_always }) catch |err| {
                        std.log.err("{}", .{err});
                        break :blk;
                    };
                },
                0x004e4942 => { // BIN
                    // there can only be one
                    if (glb_binary) |_| break :blk;
                    const blob = owned_alloc.allocator().alignedAlloc(u8, 4, chunk_length) catch break :blk;
                    const blob_size = file.readAll(blob) catch break :blk;
                    if (blob_size != chunk_length) break :blk;
                    glb_binary = blob;
                },
                else => file.seekBy(chunk_length) catch break :blk,
            }
        }

        const parsed = json_parsed orelse break :blk;

        const buffer_count = (parsed.value.buffers orelse &[0]GLTF.Buffer{}).len;
        const buffers = owned_alloc.allocator().alloc([]const u8, buffer_count) catch break :blk;

        if (parsed.value.buffers) |bufferData| {
            for (bufferData, 0..) |buffer, i| {
                if (i == 0) {
                    if (glb_binary) |blob| {
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

export fn gltf_scene(gltf_id: f64) f64 {
    const gltf = get_gltf(gltf_id) orelse return -1;
    return @floatFromInt(gltf.scene orelse return -1);
}

export fn gltf_scene_node_count(gltf_id: f64, scene_id: f64) f64 {
    const gltf = get_gltf(gltf_id) orelse return -1;
    const scene = array_get(GLTF.Scene, gltf.scenes, scene_id) orelse return -1;
    const nodes = scene.nodes orelse return 0;
    return @floatFromInt(nodes.len);
}

export fn gltf_scene_node(gltf_id: f64, scene_id: f64, node_id: f64) f64 {
    const gltf = get_gltf(gltf_id) orelse return -1;
    const scene = array_get(GLTF.Scene, gltf.scenes, scene_id) orelse return -1;
    return @floatFromInt((array_get(usize, scene.nodes, node_id) orelse return -1).*);
}

export fn gltf_get_node(gltf_id: f64, name: [*:0]const u8) f64 {
    const gltf = get_gltf(gltf_id) orelse return -1;
    const nodes = gltf.nodes orelse return -1;
    for (nodes, 0..) |n, i| {
        if (n.name) |n_name| {
            if (std.mem.eql(u8, n_name, std.mem.span(name))) {
                return @floatFromInt(i);
            }
        }
    }
    return -1;
}

export fn gltf_node_tx(gltf_id: f64, node_id: f64) f64 {
    const node = get_node(gltf_id, node_id) orelse return -1;
    return node.translation[0];
}

export fn gltf_node_ty(gltf_id: f64, node_id: f64) f64 {
    const node = get_node(gltf_id, node_id) orelse return -1;
    return node.translation[1];
}

export fn gltf_node_tz(gltf_id: f64, node_id: f64) f64 {
    const node = get_node(gltf_id, node_id) orelse return -1;
    return node.translation[2];
}

export fn gltf_node_rx(gltf_id: f64, node_id: f64) f64 {
    const node = get_node(gltf_id, node_id) orelse return -1;
    return node.rotation[0];
}

export fn gltf_node_ry(gltf_id: f64, node_id: f64) f64 {
    const node = get_node(gltf_id, node_id) orelse return -1;
    return node.rotation[1];
}

export fn gltf_node_rz(gltf_id: f64, node_id: f64) f64 {
    const node = get_node(gltf_id, node_id) orelse return -1;
    return node.rotation[2];
}

export fn gltf_node_rw(gltf_id: f64, node_id: f64) f64 {
    const node = get_node(gltf_id, node_id) orelse return -1;
    return node.rotation[3];
}

export fn gltf_node_sx(gltf_id: f64, node_id: f64) f64 {
    const node = get_node(gltf_id, node_id) orelse return -1;
    return node.scale[0];
}

export fn gltf_node_sy(gltf_id: f64, node_id: f64) f64 {
    const node = get_node(gltf_id, node_id) orelse return -1;
    return node.scale[1];
}

export fn gltf_node_sz(gltf_id: f64, node_id: f64) f64 {
    const node = get_node(gltf_id, node_id) orelse return -1;
    return node.scale[2];
}

export fn gltf_node_child_count(gltf_id: f64, node_id: f64) f64 {
    const node = get_node(gltf_id, node_id) orelse return -1;
    const children = node.children orelse return 0;
    return @floatFromInt(children.len);
}

export fn gltf_node_child(gltf_id: f64, node_id: f64, child_id: f64) f64 {
    const node = get_node(gltf_id, node_id) orelse return -1;
    const child = array_get(usize, node.children, child_id) orelse return -1;
    return @floatFromInt(child.*);
}

export fn gltf_node_camera(gltf_id: f64, node_id: f64) f64 {
    const node = get_node(gltf_id, node_id) orelse return -1;
    return @floatFromInt(node.camera orelse return -1);
}

export fn gltf_node_mesh(gltf_id: f64, node_id: f64) f64 {
    const node = get_node(gltf_id, node_id) orelse return -1;
    return @floatFromInt(node.mesh orelse return -1);
}

export fn gltf_camera_type(gltf_id: f64, camera_id: f64) [*:0]const u8 {
    const camera = get_camera(gltf_id, camera_id) orelse return "";
    return return_string(camera.type);
}

export fn gltf_camera_aspect(gltf_id: f64, camera_id: f64) f64 {
    const camera = get_camera(gltf_id, camera_id) orelse return -1;
    const perspective = camera.perspective orelse return -1;
    return perspective.aspectRatio;
}

export fn gltf_camera_yfov(gltf_id: f64, camera_id: f64) f64 {
    const camera = get_camera(gltf_id, camera_id) orelse return -1;
    const perspective = camera.perspective orelse return -1;
    return perspective.yfov;
}

export fn gltf_camera_zfar(gltf_id: f64, camera_id: f64) f64 {
    const camera = get_camera(gltf_id, camera_id) orelse return -1;
    const perspective = camera.perspective orelse return -1;
    return perspective.zfar;
}

export fn gltf_camera_znear(gltf_id: f64, camera_id: f64) f64 {
    const camera = get_camera(gltf_id, camera_id) orelse return -1;
    const perspective = camera.perspective orelse return -1;
    return perspective.znear;
}

export fn gltf_mesh_count(gltf_id: f64) f64 {
    const gltf = get_gltf(gltf_id) orelse return -1;
    const meshes = gltf.meshes orelse return 0;
    return @floatFromInt(meshes.len);
}

export fn gltf_mesh_primitive_count(gltf_id: f64, mesh_id: f64) f64 {
    const mesh = get_mesh(gltf_id, mesh_id) orelse return -1;
    return @floatFromInt(mesh.primitives.len);
}

export fn gltf_mesh_primitive_material(gltf_id: f64, mesh_id: f64, primitive_id: f64) f64 {
    const primitive = get_mesh_primitive(gltf_id, mesh_id, primitive_id) orelse return -1;
    return @floatFromInt(primitive.material orelse return -1);
}

export fn gltf_mesh_primitive_mode(gltf_id: f64, mesh_id: f64, primitive_id: f64) f64 {
    const primitive = get_mesh_primitive(gltf_id, mesh_id, primitive_id) orelse return -1;
    return @floatFromInt(primitive.mode);
}

export fn gltf_mesh_primitive_indices_accessor(gltf_id: f64, mesh_id: f64, primitive_id: f64) f64 {
    const primitive = get_mesh_primitive(gltf_id, mesh_id, primitive_id) orelse return -1;
    return @floatFromInt(primitive.indices orelse return -1);
}

export fn gltf_mesh_primitive_attribute_count(gltf_id: f64, mesh_id: f64, primitive_id: f64) f64 {
    const primitive = get_mesh_primitive(gltf_id, mesh_id, primitive_id) orelse return -1;
    return @floatFromInt(primitive.attributes.map.count());
}

export fn gltf_mesh_primitive_attribute_semantic(gltf_id: f64, mesh_id: f64, primitive_id: f64, attribute_id: f64) [*:0]const u8 {
    const primitive = get_mesh_primitive(gltf_id, mesh_id, primitive_id) orelse return "";
    const attribute_id_i: usize = @intFromFloat(attribute_id);
    if (attribute_id_i >= primitive.attributes.map.count()) return "";
    return return_string(primitive.attributes.map.entries.get(attribute_id_i).key);
}

export fn gltf_mesh_primitive_attribute_accessor(gltf_id: f64, mesh_id: f64, primitive_id: f64, attribute_id: f64) f64 {
    const primitive = get_mesh_primitive(gltf_id, mesh_id, primitive_id) orelse return -1;
    const attribute_id_i: usize = @intFromFloat(attribute_id);
    if (attribute_id_i >= primitive.attributes.map.count()) return -1;
    return @floatFromInt(primitive.attributes.map.entries.get(attribute_id_i).value);
}

export fn gltf_accessor_type(gltf_id: f64, accessor_id: f64) [*:0]const u8 {
    const accessor = get_accessor(gltf_id, accessor_id) orelse return "";
    return return_string(accessor.type);
}

export fn gltf_accessor_component_type(gltf_id: f64, accessor_id: f64) f64 {
    const accessor = get_accessor(gltf_id, accessor_id) orelse return -1;
    return @floatFromInt(accessor.componentType);
}

export fn gltf_accessor_normalized(gltf_id: f64, accessor_id: f64) f64 {
    const accessor = get_accessor(gltf_id, accessor_id) orelse return -1;
    return @floatFromInt(@intFromBool(accessor.normalized));
}

export fn gltf_accessor_stride(gltf_id: f64, accessor_id: f64) f64 {
    const glb = get_glb(gltf_id) orelse return -1;
    const gltf = &glb.json.value;
    const accessor = array_get(GLTF.Accessor, gltf.accessors, accessor_id) orelse return -1;
    const bv = array_get(GLTF.BufferView, gltf.bufferViews, accessor.bufferView) orelse return -1;
    return @floatFromInt(bv.byteStride orelse return -1);
}

export fn gltf_accessor_copy(gltf_id: f64, accessor_id: f64, address: f64) f64 {
    const glb = get_glb(gltf_id) orelse return -1;
    const gltf = &glb.json.value;
    const accessor = array_get(GLTF.Accessor, gltf.accessors, accessor_id) orelse return -1;
    const bv = array_get(GLTF.BufferView, gltf.bufferViews, accessor.bufferView) orelse return -1;
    const data = array_get([]const u8, glb.buffers, bv.buffer) orelse return -1;
    const address_i: usize = @intFromFloat(address);
    const dest: [*]u8 = @ptrFromInt(address_i);
    // TODO copy accessor instead of buffer view
    @memcpy(dest[0..bv.byteLength], data.*[bv.byteOffset..bv.byteLength]);
    return 0;
}

export fn gltf_accessor_pointer(gltf_id: f64, accessor_id: f64) f64 {
    const glb = get_glb(gltf_id) orelse return -1;
    const gltf = &glb.json.value;
    const accessor = array_get(GLTF.Accessor, gltf.accessors, accessor_id) orelse return -1;
    const bv = array_get(GLTF.BufferView, gltf.bufferViews, accessor.bufferView) orelse return -1;
    const data = array_get([]const u8, glb.buffers, bv.buffer) orelse return -1;
    return @floatFromInt(@intFromPtr(data.ptr) + bv.byteOffset + accessor.byteOffset);
}

export fn gltf_accessor_size(gltf_id: f64, accessor_id: f64) f64 {
    const glb = get_glb(gltf_id) orelse return -1;
    const gltf = &glb.json.value;
    const accessor = array_get(GLTF.Accessor, gltf.accessors, accessor_id) orelse return -1;
    const bv = array_get(GLTF.BufferView, gltf.bufferViews, accessor.bufferView) orelse return -1;
    // TODO calculate using accessor type and such, this is incorrect
    return @floatFromInt(bv.byteLength);
}

export fn gltf_material_base_texture(gltf_id: f64, material_id: f64) f64 {
    const material = get_material(gltf_id, material_id) orelse return -1;
    const baseColorTexture = material.pbrMetallicRoughness.baseColorTexture orelse return -1;
    return @floatFromInt(baseColorTexture.index);
}

export fn gltf_material_base_color_pointer(gltf_id: f64, material_id: f64) f64 {
    const material = get_material(gltf_id, material_id) orelse return -1;
    return @floatFromInt(@intFromPtr(&material.pbrMetallicRoughness.baseColorFactor));
}

export fn gltf_material_base_texcoord(gltf_id: f64, material_id: f64) f64 {
    const material = get_material(gltf_id, material_id) orelse return -1;
    const baseColorTexture = material.pbrMetallicRoughness.baseColorTexture orelse return -1;
    return @floatFromInt(baseColorTexture.texCoord);
}

export fn gltf_material_normal_texture(gltf_id: f64, material_id: f64) f64 {
    const material = get_material(gltf_id, material_id) orelse return -1;
    const normalTexture = material.normalTexture orelse return -1;
    return @floatFromInt(normalTexture.index);
}

export fn gltf_material_normal_texcoord(gltf_id: f64, material_id: f64) f64 {
    const material = get_material(gltf_id, material_id) orelse return -1;
    const normalTexture = material.normalTexture orelse return -1;
    return @floatFromInt(normalTexture.texCoord);
}

export fn gltf_material_normal_scale(gltf_id: f64, material_id: f64) f64 {
    const material = get_material(gltf_id, material_id) orelse return -1;
    const normalTexture = material.normalTexture orelse return -1;
    return normalTexture.scale;
}

export fn gltf_material_occlusion_texture(gltf_id: f64, material_id: f64) f64 {
    const material = get_material(gltf_id, material_id) orelse return -1;
    const occlusionTexture = material.occlusionTexture orelse return -1;
    return @floatFromInt(occlusionTexture.index);
}

export fn gltf_material_occlusion_texcoord(gltf_id: f64, material_id: f64) f64 {
    const material = get_material(gltf_id, material_id) orelse return -1;
    const occlusionTexture = material.occlusionTexture orelse return -1;
    return @floatFromInt(occlusionTexture.texCoord);
}

export fn gltf_material_occlusion_strength(gltf_id: f64, material_id: f64) f64 {
    const material = get_material(gltf_id, material_id) orelse return -1;
    const occlusionTexture = material.occlusionTexture orelse return -1;
    return occlusionTexture.strength;
}

export fn gltf_material_emissive_texture(gltf_id: f64, material_id: f64) f64 {
    const material = get_material(gltf_id, material_id) orelse return -1;
    const emissiveTexture = material.emissiveTexture orelse return -1;
    return @floatFromInt(emissiveTexture.index);
}

export fn gltf_material_emissive_texcoord(gltf_id: f64, material_id: f64) f64 {
    const material = get_material(gltf_id, material_id) orelse return -1;
    const emissiveTexture = material.emissiveTexture orelse return -1;
    return @floatFromInt(emissiveTexture.texCoord);
}

export fn gltf_material_emissive_color_pointer(gltf_id: f64, material_id: f64) f64 {
    const material = get_material(gltf_id, material_id) orelse return -1;
    return @floatFromInt(@intFromPtr(&material.emissiveFactor));
}

export fn gltf_material_alpha_mode(gltf_id: f64, material_id: f64) [*:0]const u8 {
    const material = get_material(gltf_id, material_id) orelse return "";
    return return_string(material.alphaMode);
}

export fn gltf_material_alpha_cutoff(gltf_id: f64, material_id: f64) f64 {
    const material = get_material(gltf_id, material_id) orelse return -1;
    return material.alphaCutoff;
}

export fn gltf_material_double_sided(gltf_id: f64, material_id: f64) f64 {
    const material = get_material(gltf_id, material_id) orelse return -1;
    return @floatFromInt(@intFromBool(material.doubleSided));
}

export fn gltf_texture_count(gltf_id: f64) f64 {
    const gltf = get_gltf(gltf_id) orelse return -1;
    const textures = gltf.textures orelse return 0;
    return @floatFromInt(textures.len);
}

export fn gltf_texture_wrap_h(gltf_id: f64, texture_id: f64) f64 {
    const sampler = get_sampler(gltf_id, texture_id) orelse return 10497;
    return @floatFromInt(sampler.wrapS);
}

export fn gltf_texture_wrap_v(gltf_id: f64, texture_id: f64) f64 {
    const sampler = get_sampler(gltf_id, texture_id) orelse return 10497;
    return @floatFromInt(sampler.wrapT);
}

export fn gltf_texture_interpolation(gltf_id: f64, texture_id: f64) f64 {
    const sampler = get_sampler(gltf_id, texture_id) orelse return 10497;
    return @floatFromInt(@intFromBool(sampler.magFilter != 9728));
}

export fn gltf_texture_type(gltf_id: f64, texture_id: f64) [*:0]const u8 {
    const gltf = get_gltf(gltf_id) orelse return "";
    const texture = array_get(GLTF.Texture, gltf.textures, texture_id) orelse return "";
    const image = array_get(GLTF.Image, gltf.images, texture.source) orelse return "";
    return return_string(image.mimeType orelse return "");
}

export fn gltf_texture_copy(gltf_id: f64, texture_id: f64, dest_address: f64, dest_size: f64) f64 {
    const dest_address_i: usize = @intFromFloat(dest_address);
    const dest_ptr: [*]u8 = @ptrFromInt(dest_address_i);
    const dest: []u8 = dest_ptr[0..@intFromFloat(dest_size)];
    const glb = get_glb(gltf_id) orelse return -1;
    const gltf = &glb.json.value;
    const texture = array_get(GLTF.Texture, gltf.textures, texture_id) orelse return -1;
    const image = array_get(GLTF.Image, gltf.images, texture.source) orelse return -1;
    const bv = array_get(GLTF.BufferView, gltf.bufferViews, image.bufferView) orelse return -1;
    const buffer = array_get([]const u8, glb.buffers, bv.buffer) orelse return -1;
    const data = buffer.*[bv.byteOffset .. bv.byteOffset + bv.byteLength];
    if (dest.len != data.len) {
        return -1;
    }
    std.mem.copyForwards(u8, dest, data);
    return 0;
}

export fn gltf_texture_save(gltf_id: f64, texture_id: f64, filename: [*:0]const u8) f64 {
    const glb = get_glb(gltf_id) orelse return -1;
    const gltf = &glb.json.value;
    const texture = array_get(GLTF.Texture, gltf.textures, texture_id) orelse return -1;
    const image = array_get(GLTF.Image, gltf.images, texture.source) orelse return -1;
    const bv = array_get(GLTF.BufferView, gltf.bufferViews, image.bufferView) orelse return -1;
    const buffer = array_get([]const u8, glb.buffers, bv.buffer) orelse return -1;
    const data = buffer.*[bv.byteOffset .. bv.byteOffset + bv.byteLength];
    const file = std.fs.cwd().createFileZ(filename, .{}) catch return -1;
    file.writeAll(data) catch return -1;
    file.close();
    return 0;
}

export fn gltf_texture_size(gltf_id: f64, texture_id: f64) f64 {
    const glb = get_glb(gltf_id) orelse return -1;
    const gltf = &glb.json.value;
    const texture = array_get(GLTF.Texture, gltf.textures, texture_id) orelse return -1;
    const image = array_get(GLTF.Image, gltf.images, texture.source) orelse return -1;
    const bv = array_get(GLTF.BufferView, gltf.bufferViews, image.bufferView) orelse return -1;
    return @floatFromInt(bv.byteLength);
}

test "gltf stuff" {
    // https://github.com/KhronosGroup/glTF-Sample-Models/blob/main/2.0/Box/glTF-Binary/Box.glb
    try testing.expectEqual(1, __gltf_load("Box.glb"));
    try testing.expectEqual(1, gltf_node_child_count(1, 0));
    try testing.expectEqual(1, gltf_node_child(1, 0, 0));
    try testing.expectEqual(648, g_gltfs.get(1).?.buffers[0].len);
    try testing.expectEqualStrings("NORMAL", std.mem.span(gltf_mesh_primitive_attribute_semantic(1, 0, 0, 0)));
    try testing.expectEqual(0, gltf_destroy(1));
}
