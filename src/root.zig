const std = @import("std");
const GLTF = @import("GLTF.zig");
const testing = std.testing;

const GLB = struct {
    arena: std.heap.ArenaAllocator,
    json: std.json.Parsed(GLTF),
    buffers: [][]align(4) const u8,
    fn deinit(self: @This()) void {
        self.json.deinit();
    }
};

var g_allocator = std.heap.GeneralPurposeAllocator(.{}){};
var g_gltfs = std.AutoArrayHashMap(i32, GLB).init(g_allocator.allocator());
var g_gltf_next_id: i32 = 1;
var g_stringret: ?[:0]u8 = null;
var g_matrices = std.ArrayList([16]f32).init(g_allocator.allocator());
var g_data: ?[]u8 = null;
var g_sorted_weights: ?[]f32 = null;
var g_sorted_weight_ids: ?[]usize = null;

fn return_string(string: []const u8) [*:0]const u8 {
    // make new string
    const new_string = g_allocator.allocator().allocSentinel(u8, string.len, 0) catch return "";
    @memcpy(new_string, string);
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
fn array_get_mut(T: type, array: ?[]T, id: anytype) ?*T {
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

fn create_rotation(quaternion: @Vector(4, f32)) [16]f32 {
    const const1110 = @Vector(4, f32){ 1, 1, 1, 0 };
    const nothing = @Vector(1, f32){0};
    const q0 = quaternion + quaternion;
    const q1 = quaternion * q0;

    var v0 = @shuffle(f32, q1, const1110, @Vector(4, i32){ 1, 0, 0, -4 });
    var v1 = @shuffle(f32, q1, const1110, @Vector(4, f32){ 2, 2, 1, -4 });
    const r0 = const1110 - v0 - v1;

    v0 = @shuffle(f32, quaternion, nothing, @Vector(4, f32){ 0, 0, 1, 3 });
    v1 = @shuffle(f32, q0, nothing, @Vector(4, f32){ 2, 1, 2, 3 });
    v0 *= v1;

    v1 = @splat(quaternion[3]);
    const v2 = @shuffle(f32, q0, nothing, @Vector(4, f32){ 1, 2, 0, 3 });
    v1 *= v2;

    const r1 = v0 + v1;
    const r2 = v0 - v1;

    v0 = @shuffle(f32, r1, r2, @Vector(4, f32){ 1, -1, -2, 2 });
    v1 = @shuffle(f32, r1, r2, @Vector(4, f32){ 0, -3, 0, -3 });

    const out = [4]@Vector(4, f32){ @shuffle(f32, r0, v0, @Vector(4, f32){ 0, -1, -2, 3 }), @shuffle(f32, r0, v0, @Vector(4, f32){ -3, 1, -4, 3 }), @shuffle(f32, r0, v1, @Vector(4, f32){ -1, -2, 2, 3 }), @Vector(4, f32){ 0, 0, 0, 1 } };
    return @bitCast(out);
}

fn create_transform(node: *const GLTF.Node) [16]f32 {
    const rotation = create_rotation(node.rotation);
    const scaling = [16]f32{ node.scale[0], 0, 0, 0, 0, node.scale[1], 0, 0, 0, 0, node.scale[2], 0, 0, 0, 0, 1 };
    const translation = [16]f32{ 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, node.translation[0], node.translation[1], node.translation[2], 1 };

    return multiply_matrices(multiply_matrices(scaling, rotation), translation);
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
        const a_row_slice = m_a[y * 4 .. y * 4 + 4];
        const a_row: @Vector(4, f32) = a_row_slice[0..4].*;
        for (0..4) |x| {
            out[y * 4 + x] = @reduce(.Add, a_row * b_transposed[x]);
        }
    }
    return out;
}

fn create_full_transform(gltf: *const GLTF, node_id: usize, skeleton: ?usize) [16]f32 {
    var node = array_get(GLTF.Node, gltf.nodes, node_id) orelse return std.mem.zeroes([16]f32);
    // should only be here if there are no animations
    if (node.matrix) |matrix| return matrix;
    var matrix = create_transform(node);
    while (node.parent) |parent| {
        if (parent == skeleton) break;
        node = array_get(GLTF.Node, gltf.nodes, node.parent) orelse return std.mem.zeroes([16]f32);
        matrix = multiply_matrices(matrix, create_transform(node));
    }
    return matrix;
}

fn component_type_size(component_type: usize) usize {
    return switch (component_type) {
        5120 => 1,
        5121 => 1,
        5122 => 2,
        5123 => 2,
        5125 => 4,
        5126 => 4,
        else => 0,
    };
}

fn type_count(t: []const u8) usize {
    if (std.mem.eql(u8, t, "SCALAR")) return 1;
    if (std.mem.eql(u8, t, "VEC2")) return 2;
    if (std.mem.eql(u8, t, "VEC3")) return 3;
    if (std.mem.eql(u8, t, "VEC4")) return 4;
    if (std.mem.eql(u8, t, "MAT2")) return 4;
    if (std.mem.eql(u8, t, "MAT3")) return 9;
    if (std.mem.eql(u8, t, "MAT4")) return 16;
    return 0;
}

fn accessor_stride(accessor: *const GLTF.Accessor) usize {
    return component_type_size(accessor.componentType) * type_count(accessor.type);
}

fn setup_weights(gltf_id: f64, node_id: f64) ?void {
    const gltf = get_gltf(gltf_id) orelse return null;
    const node = array_get(GLTF.Node, gltf.nodes, node_id) orelse return null;
    const weights = node.weights orelse return null;

    if (g_sorted_weight_ids) |w| g_allocator.allocator().free(w);
    const new_ids = g_allocator.allocator().alloc(usize, weights.len) catch return null;
    g_sorted_weight_ids = new_ids;
    for (0..new_ids.len) |i| new_ids[i] = i;
    std.sort.insertion(usize, new_ids, weights, struct {
        fn inner(_weights: []const f32, a: usize, b: usize) bool {
            return _weights[a] > _weights[b];
        }
    }.inner);

    if (g_sorted_weights) |w| g_allocator.allocator().free(w);
    const new_weights = g_allocator.allocator().alloc(f32, weights.len) catch return null;
    g_sorted_weights = new_weights;
    for (0..new_weights.len) |i| new_weights[i] = weights[new_ids[i]];
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
        var glb_binary: ?[]align(4) const u8 = null;

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
        const buffers = owned_alloc.allocator().alloc([]align(4) const u8, buffer_count) catch break :blk;

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

        if (parsed.value.nodes) |nodes| {
            // assign parents
            for (nodes, 0..) |node, i| {
                if (node.children) |children| {
                    for (children) |child| {
                        nodes[child].parent = i;
                    }
                }
            }

            // copy weights
            if (parsed.value.meshes) |meshes| {
                for (0..nodes.len) |i| {
                    const node = &nodes[i];
                    if (node.weights == null) {
                        if (node.mesh) |mesh_id| {
                            const mesh = meshes[mesh_id];
                            if (mesh.weights) |weights| {
                                const new_weights = owned_alloc.allocator().alloc(f32, weights.len) catch return -1;
                                node.weights = new_weights;
                                @memcpy(new_weights, weights);
                            }
                        }
                    }
                }
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

export fn gltf_animation_count(gltf_id: f64) f64 {
    const gltf = get_gltf(gltf_id) orelse return -1;
    const animations = gltf.animations orelse return 0;
    return @floatFromInt(animations.len);
}

export fn gltf_get_animation(gltf_id: f64, animation_name: [*:0]const u8) f64 {
    const gltf = get_gltf(gltf_id) orelse return -1;
    const animations = gltf.animations orelse return -1;
    const needle = std.mem.span(animation_name);
    for (animations, 0..) |animation, i| {
        if (animation.name) |a_name| {
            if (std.mem.eql(u8, a_name, needle)) return @floatFromInt(i);
        }
    }
    return -1;
}

export fn gltf_animation_name(gltf_id: f64, animation_id: f64) [*:0]const u8 {
    const gltf = get_gltf(gltf_id) orelse return "";
    const animation = array_get(GLTF.Animation, gltf.animations, animation_id) orelse return "";
    return return_string(animation.name orelse return "");
}

export fn __gltf_animate(gltf_id: f64, animation_id: f64, time: f64) f64 {
    const glb = get_glb(gltf_id) orelse return -1;
    const gltf = &glb.json.value;
    const animation = array_get(GLTF.Animation, gltf.animations, animation_id) orelse return -1;
    var done = true;
    channels: for (animation.channels) |channel| {
        const node = array_get_mut(GLTF.Node, gltf.nodes, channel.target.node) orelse continue;
        const is_rotation = std.mem.eql(u8, channel.target.path, "rotation");
        const output: []f32 = if (is_rotation) &node.rotation else if (std.mem.eql(u8, channel.target.path, "translation")) &node.translation else if (std.mem.eql(u8, channel.target.path, "scale")) &node.scale else if (std.mem.eql(u8, channel.target.path, "weights")) node.weights.? else continue;
        const sampler = animation.samplers[channel.sampler];
        if (std.mem.eql(u8, sampler.interpolation, "CUBICSPLINE")) {
            // unsupported
            continue;
        }
        const is_linear = std.mem.eql(u8, sampler.interpolation, "LINEAR");
        const input_accessor = array_get(GLTF.Accessor, gltf.accessors, sampler.input) orelse continue;
        if (input_accessor.componentType != 5126) {
            // only floats are supported for input
            continue;
        }
        const input_bv = array_get(GLTF.BufferView, gltf.bufferViews, input_accessor.bufferView) orelse continue;
        const input_buffer = array_get([]align(4) const u8, glb.buffers, input_bv.buffer) orelse continue;
        const input_byte_offset = input_bv.byteOffset + input_accessor.byteOffset;
        // we're assuming stride is 4 but that's fine for now
        const input_data = @as([*]const f32, @ptrCast(input_buffer.ptr))[input_byte_offset / 4 .. input_byte_offset / 4 + input_accessor.count];
        const output_accessor = array_get(GLTF.Accessor, gltf.accessors, sampler.output) orelse continue;
        const output_bv = array_get(GLTF.BufferView, gltf.bufferViews, output_accessor.bufferView) orelse continue;
        const output_buffer = array_get([]align(4) const u8, glb.buffers, output_bv.buffer) orelse continue;
        if (output_accessor.componentType != 5126) {
            // let's just pretend only floats exist for now
            continue;
        }
        const output_byte_offset = output_bv.byteOffset + output_accessor.byteOffset;
        for (input_data, 0..) |keyframe_next, i| {
            if (time < keyframe_next) {
                // we've found the next keyframe
                done = false;
                const prev = if (i != 0) i - 1 else 0;
                const output_offset = output_byte_offset + ((output_bv.byteStride orelse 4) * output.len) * prev;
                const output_current = @as([*]const f32, @ptrCast(output_buffer.ptr))[output_offset / 4 .. output_offset / 4 + output.len];
                if (is_linear and i != 0) {
                    const keyframe_prev = input_data[prev];
                    const output_next = @as([*]const f32, @ptrCast(output_buffer.ptr))[output_offset / 4 + output.len .. output_offset + output.len * 2];
                    const lerp = (time - keyframe_prev) / (keyframe_next - keyframe_prev);
                    if (!is_rotation) {
                        // translation, scale, or morph weights -> straight lerp
                        if (output.len == 3) {
                            const current: @Vector(3, f32) = output_current[0..3].*;
                            const current_next: @Vector(3, f32) = output_next[0..3].*;
                            const lerpsplat: @Vector(3, f32) = @splat(@floatCast(lerp));
                            const lerped: @Vector(3, f32) = std.math.lerp(current, current_next, lerpsplat);
                            @memcpy(output[0..3], @as([3]f32, lerped)[0..]);
                        } else {
                            for (0..output.len) |j| {
                                output[j] = std.math.lerp(output_current[j], output_next[j], @as(f32, @floatCast(lerp)));
                            }
                        }
                    } else {
                        // rotation -> slerp
                        const current: @Vector(4, f32) = output_current[0..4].*;
                        const current_next: @Vector(4, f32) = output_next[0..4].*;
                        const dot = @reduce(.Add, current * current_next);
                        const a = std.math.acos(@abs(dot));
                        // "When a is close to zero, spherical linear interpolation turns into regular linear interpolation."
                        if (@abs(a) > 0.001) {
                            const s: @Vector(4, f32) = @splat(dot / @abs(dot));
                            const sina: @Vector(4, f32) = @splat(@sin(a));
                            const sinat: @Vector(4, f32) = @splat(@floatCast(@sin(a * lerp)));
                            const sina1t: @Vector(4, f32) = @splat(@floatCast(@sin(a * (1 - lerp))));
                            const slerped = @mulAdd(@TypeOf(current), sina1t / sina, current, s * (sinat / sina) * current_next);
                            @memcpy(output[0..4], @as([4]f32, slerped)[0..]);
                        } else {
                            const lerpsplat: @Vector(4, f32) = @splat(@floatCast(lerp));
                            const lerped: @Vector(4, f32) = std.math.lerp(current, current_next, lerpsplat);
                            @memcpy(output[0..4], @as([4]f32, lerped)[0..]);
                        }
                    }
                } else {
                    @memcpy(output, output_current);
                }
                continue :channels;
            }
        }
        // we've gone through them all, so we're at the end
        const output_offset = output_byte_offset + ((output_bv.byteStride orelse 4) * output.len) * (input_accessor.count - 1);
        @memcpy(output, @as([*]const f32, @ptrCast(output_buffer.ptr))[output_offset / 4 .. output_offset / 4 + output.len]);
    }
    return @floatFromInt(@intFromBool(done));
}

export fn __gltf_animation_length(gltf_id: f64, animation_id: f64) f64 {
    const glb = get_glb(gltf_id) orelse return -1;
    const gltf = &glb.json.value;
    const animation = array_get(GLTF.Animation, gltf.animations, animation_id) orelse return -1;
    var max: f32 = 0;
    for (animation.channels) |channel| {
        const sampler = animation.samplers[channel.sampler];
        const input_accessor = array_get(GLTF.Accessor, gltf.accessors, sampler.input) orelse continue;
        if (input_accessor.componentType != 5126) {
            // only floats are supported for input
            continue;
        }
        const input_bv = array_get(GLTF.BufferView, gltf.bufferViews, input_accessor.bufferView) orelse continue;
        const input_buffer = array_get([]align(4) const u8, glb.buffers, input_bv.buffer) orelse continue;
        const input_byte_offset = input_bv.byteOffset + input_accessor.byteOffset;
        // we're assuming stride is 4 but that's fine for now
        const input_data = @as([*]const f32, @ptrCast(input_buffer.ptr))[input_byte_offset / 4 ..];
        max = @max(max, input_data[input_accessor.count - 1]);
    }
    return max;
}

export fn gltf_skin_skeleton(gltf_id: f64, skin_id: f64) f64 {
    const gltf = get_gltf(gltf_id) orelse return -1;
    const skin = array_get(GLTF.Skin, gltf.skins, skin_id) orelse return -1;
    return @floatFromInt(skin.skeleton orelse return -1);
}

export fn gltf_skin_joint_count(gltf_id: f64, skin_id: f64) f64 {
    const gltf = get_gltf(gltf_id) orelse return -1;
    const skin = array_get(GLTF.Skin, gltf.skins, skin_id) orelse return -1;
    return @floatFromInt(skin.joints.len);
}

export fn gltf_skin_joints(gltf_id: f64, skin_id: f64) f64 {
    const glb = get_glb(gltf_id) orelse return -1;
    const gltf = &glb.json.value;
    const skin = array_get(GLTF.Skin, gltf.skins, skin_id) orelse return -1;
    var ibm_data: ?[]const f32 = null;
    var ibm_offset: usize = 0;
    var ibm_stride: usize = 0;
    blk: {
        const ibm_accessor = array_get(GLTF.Accessor, gltf.accessors, skin.inverseBindMatrices) orelse break :blk;
        const ibm_bv = array_get(GLTF.BufferView, gltf.bufferViews, ibm_accessor.bufferView) orelse break :blk;
        const ibm_buffer = array_get([]align(4) const u8, glb.buffers, ibm_bv.buffer) orelse break :blk;
        ibm_stride = (ibm_bv.byteStride orelse (16 * 4)) / 4;
        ibm_offset = (ibm_bv.byteOffset + ibm_accessor.byteOffset) / 4;
        ibm_data = @as([*]const f32, @ptrCast(ibm_buffer.ptr))[ibm_offset .. ibm_offset + ibm_accessor.count * ibm_stride];
    }
    g_matrices.clearRetainingCapacity();
    g_matrices.ensureTotalCapacity(skin.joints.len) catch return -1;
    for (skin.joints, 0..) |joint, i| {
        var matrix = create_full_transform(gltf, joint, skin.skeleton);
        if (ibm_data) |data| {
            const matrix_ptr = data[i * ibm_stride ..];
            matrix = multiply_matrices(matrix_ptr[0..16].*, matrix);
        }
        g_matrices.addOneAssumeCapacity().* = matrix;
    }
    return @floatFromInt(@intFromPtr(g_matrices.items.ptr));
}

export fn gltf_scene(gltf_id: f64) f64 {
    const gltf = get_gltf(gltf_id) orelse return -1;
    return @floatFromInt(gltf.scene orelse return -1);
}

export fn gltf_scene_count(gltf_id: f64) f64 {
    const gltf = get_gltf(gltf_id) orelse return -1;
    const scenes = gltf.scenes orelse return 0;
    return @floatFromInt(scenes.len);
}

export fn gltf_get_scene(gltf_id: f64, scene_name: [*:0]const u8) f64 {
    const gltf = get_gltf(gltf_id) orelse return -1;
    const scenes = gltf.scenes orelse return -1;
    const needle = std.mem.span(scene_name);
    for (scenes, 0..) |scene, i| {
        if (scene.name) |s_name| {
            if (std.mem.eql(u8, s_name, needle)) return @floatFromInt(i);
        }
    }
    return -1;
}

export fn gltf_scene_name(gltf_id: f64, scene_id: f64) [*:0]const u8 {
    const gltf = get_gltf(gltf_id) orelse return "";
    const scene = array_get(GLTF.Scene, gltf.scenes, scene_id) orelse return "";
    return return_string(scene.name orelse return "");
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

export fn gltf_node_count(gltf_id: f64) f64 {
    const gltf = get_gltf(gltf_id) orelse return -1;
    const nodes = gltf.nodes orelse return 0;
    return @floatFromInt(nodes.len);
}

export fn gltf_get_node(gltf_id: f64, name: [*:0]const u8) f64 {
    const gltf = get_gltf(gltf_id) orelse return -1;
    const nodes = gltf.nodes orelse return -1;
    const needle = std.mem.span(name);
    for (nodes, 0..) |n, i| {
        if (n.name) |n_name| {
            if (std.mem.eql(u8, n_name, needle)) {
                return @floatFromInt(i);
            }
        }
    }
    return -1;
}

export fn gltf_node_name(gltf_id: f64, node_id: f64) [*:0]const u8 {
    const node = get_node(gltf_id, node_id) orelse return "";
    return return_string(node.name orelse return "");
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

export fn gltf_node_matrix_pointer(gltf_id: f64, node_id: f64) f64 {
    const gltf = get_gltf(gltf_id) orelse return -1;
    // just to make sure all is ok
    _ = array_get(GLTF.Node, gltf.nodes, node_id) orelse return -1;
    g_matrices.clearRetainingCapacity();
    const mat_ptr = g_matrices.addOne() catch return -1;
    mat_ptr.* = create_full_transform(gltf, @intFromFloat(node_id), null);
    return @floatFromInt(@intFromPtr(mat_ptr));
}

export fn gltf_node_parent(gltf_id: f64, node_id: f64) f64 {
    const node = get_node(gltf_id, node_id) orelse return -1;
    return @floatFromInt(node.parent orelse return -1);
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

export fn gltf_node_skin(gltf_id: f64, node_id: f64) f64 {
    const node = get_node(gltf_id, node_id) orelse return -1;
    return @floatFromInt(node.skin orelse return -1);
}

export fn gltf_node_weight_count(gltf_id: f64, node_id: f64) f64 {
    const gltf = get_gltf(gltf_id) orelse return -1;
    const node = array_get(GLTF.Node, gltf.nodes, node_id) orelse return -1;
    const weights = blk: {
        if (node.weights) |weights| break :blk weights;
        const mesh = array_get(GLTF.Mesh, gltf.meshes, node.mesh) orelse return -1;
        break :blk mesh.weights orelse return 0;
    };
    return @floatFromInt(weights.len);
}

export fn gltf_node_sorted_morph(gltf_id: f64, node_id: f64, morph_id: f64) f64 {
    setup_weights(gltf_id, node_id) orelse return -1;
    const id = array_get(usize, g_sorted_weight_ids, morph_id) orelse return -1;
    return @floatFromInt(id.*);
}

export fn gltf_node_sorted_weights_pointer(gltf_id: f64, node_id: f64) f64 {
    setup_weights(gltf_id, node_id) orelse return 0;
    return @floatFromInt(@intFromPtr(g_sorted_weights.?.ptr));
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

export fn gltf_mesh_primitive_morph_count(gltf_id: f64, mesh_id: f64, primitive_id: f64) f64 {
    const primitive = get_mesh_primitive(gltf_id, mesh_id, primitive_id) orelse return -1;
    const targets = primitive.targets orelse return 0;
    return @floatFromInt(targets.len);
}

export fn gltf_mesh_primitive_morph(gltf_id: f64, mesh_id: f64, primitive_id: f64, morph_id: f64, attribute_id: f64) f64 {
    const primitive = get_mesh_primitive(gltf_id, mesh_id, primitive_id) orelse return -1;
    const target = array_get(std.json.ArrayHashMap(usize), primitive.targets, morph_id) orelse return -1;
    const attribute = array_get([]const u8, &[3][]const u8{ "POSITION", "NORMAL", "TANGENT" }, attribute_id) orelse return -1;
    return @floatFromInt(target.map.get(attribute.*) orelse return -1);
}

export fn gltf_mesh_primitive_morph_attribute_count(gltf_id: f64, mesh_id: f64, primitive_id: f64, morph_id: f64) f64 {
    const primitive = get_mesh_primitive(gltf_id, mesh_id, primitive_id) orelse return -1;
    const target = array_get(std.json.ArrayHashMap(usize), primitive.targets, morph_id) orelse return -1;
    return @floatFromInt(target.map.count());
}

export fn gltf_mesh_primitive_morph_attribute_semantic(gltf_id: f64, mesh_id: f64, primitive_id: f64, morph_id: f64, attribute_id: f64) [*:0]const u8 {
    const primitive = get_mesh_primitive(gltf_id, mesh_id, primitive_id) orelse return "";
    const target = array_get(std.json.ArrayHashMap(usize), primitive.targets, morph_id) orelse return "";
    const attribute_id_i: usize = @intFromFloat(attribute_id);
    if (attribute_id_i >= primitive.attributes.map.count()) return "";
    return return_string(target.map.entries.get(attribute_id_i).key);
}

export fn gltf_mesh_primitive_morph_attribute_accessor(gltf_id: f64, mesh_id: f64, primitive_id: f64, morph_id: f64, attribute_id: f64) f64 {
    const primitive = get_mesh_primitive(gltf_id, mesh_id, primitive_id) orelse return -1;
    const target = array_get(std.json.ArrayHashMap(usize), primitive.targets, morph_id) orelse return -1;
    const attribute_id_i: usize = @intFromFloat(attribute_id);
    if (attribute_id_i >= primitive.attributes.map.count()) return -1;
    return @floatFromInt(target.map.entries.get(attribute_id_i).value);
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
    const bv = array_get(GLTF.BufferView, gltf.bufferViews, accessor.bufferView) orelse return @floatFromInt(accessor_stride(accessor));
    return @floatFromInt(bv.byteStride orelse accessor_stride(accessor));
}

export fn gltf_accessor_copy(gltf_id: f64, accessor_id: f64, dest_address: f64, dest_size: f64) f64 {
    const dest_address_i: usize = @intFromFloat(dest_address);
    const dest_ptr: [*]u8 = @ptrFromInt(dest_address_i);
    const dest: []u8 = dest_ptr[0..@intFromFloat(dest_size)];
    const glb = get_glb(gltf_id) orelse return -1;
    const gltf = &glb.json.value;
    const accessor = array_get(GLTF.Accessor, gltf.accessors, accessor_id) orelse return -1;
    const bv = array_get(GLTF.BufferView, gltf.bufferViews, accessor.bufferView) orelse return -1;
    const buffer = array_get([]const u8, glb.buffers, bv.buffer) orelse return -1;
    const offset = bv.byteOffset + accessor.byteOffset;
    const size = (bv.byteStride orelse accessor_stride(accessor)) * accessor.count;
    const data = buffer.*[offset .. offset + size];
    if (dest.len != data.len) {
        return -1;
    }
    @memcpy(dest, data);
    return 0;
}

export fn gltf_accessor_pointer(gltf_id: f64, accessor_id: f64) f64 {
    const glb = get_glb(gltf_id) orelse return -1;
    const gltf = &glb.json.value;
    const accessor = array_get(GLTF.Accessor, gltf.accessors, accessor_id) orelse return -1;
    if (accessor.sparse) |sparse| {
        const bv_maybe = array_get(GLTF.BufferView, gltf.bufferViews, accessor.bufferView);
        const packed_stride = accessor_stride(accessor);
        var stride = packed_stride;
        if (bv_maybe) |bv| {
            if (bv.byteStride) |s| stride = s;
        }
        const size = accessor.count * stride;
        if (g_data) |data| g_allocator.allocator().free(data);
        const data = g_allocator.allocator().alignedAlloc(u8, 4, size) catch return -1;
        g_data = data;
        if (bv_maybe) |bv| {
            const buffer = array_get([]const u8, glb.buffers, bv.buffer) orelse return -1;
            const offset = bv.byteOffset + accessor.byteOffset;
            @memcpy(data, @as([*]const u8, @ptrCast(buffer.ptr))[offset .. offset + size]);
        } else {
            @memset(data, 0);
        }
        const indices_bv = array_get(GLTF.BufferView, gltf.bufferViews, sparse.indices.bufferView) orelse return -1;
        const indices_data: []align(4) const u8 = blk: {
            const buffer = array_get([]align(4) const u8, glb.buffers, indices_bv.buffer) orelse return -1;
            const offset = indices_bv.byteOffset + sparse.indices.byteOffset;
            break :blk @alignCast(buffer.*[offset..]);
        };
        const values_bv = array_get(GLTF.BufferView, gltf.bufferViews, sparse.values.bufferView) orelse return -1;
        const values_data = blk: {
            const buffer = array_get([]const u8, glb.buffers, values_bv.buffer) orelse return -1;
            const offset = values_bv.byteOffset + sparse.values.byteOffset;
            break :blk buffer.*[offset..];
        };
        for (0..sparse.count) |i| {
            const index = switch (sparse.indices.componentType) {
                5121 => indices_data[i],
                5123 => @as([*]const u16, @ptrCast(indices_data.ptr))[i],
                5125 => @as([*]const u32, @ptrCast(indices_data.ptr))[i],
                else => return -1,
            };
            @memcpy(data[stride * index .. stride * (index + 1)], values_data[packed_stride * i .. packed_stride * (i + 1)]);
        }
        return @floatFromInt(@intFromPtr(data.ptr));
    } else {
        const bv = array_get(GLTF.BufferView, gltf.bufferViews, accessor.bufferView) orelse return -1;
        const data = array_get([]const u8, glb.buffers, bv.buffer) orelse return -1;
        return @floatFromInt(@intFromPtr(data.ptr) + bv.byteOffset + accessor.byteOffset);
    }
}

export fn gltf_accessor_size(gltf_id: f64, accessor_id: f64) f64 {
    const glb = get_glb(gltf_id) orelse return -1;
    const gltf = &glb.json.value;
    const accessor = array_get(GLTF.Accessor, gltf.accessors, accessor_id) orelse return -1;
    const bv = array_get(GLTF.BufferView, gltf.bufferViews, accessor.bufferView) orelse return @floatFromInt(accessor.count * accessor_stride(accessor));
    const stride = bv.byteStride orelse accessor_stride(accessor);
    return @floatFromInt(accessor.count * stride);
}

export fn gltf_material_base_texture(gltf_id: f64, material_id: f64) f64 {
    const material = get_material(gltf_id, material_id) orelse return -1;
    const baseColorTexture = material.pbrMetallicRoughness.baseColorTexture orelse return -1;
    return @floatFromInt(baseColorTexture.index);
}

export fn gltf_material_roughness_texture(gltf_id: f64, material_id: f64) f64 {
    const material = get_material(gltf_id, material_id) orelse return -1;
    const roughTexture = material.pbrMetallicRoughness.metallicRoughnessTexture orelse return -1;
    return @floatFromInt(roughTexture.index);
}

export fn gltf_material_roughness_texcoord(gltf_id: f64, material_id: f64) f64 {
    const material = get_material(gltf_id, material_id) orelse return -1;
    const roughTexture = material.pbrMetallicRoughness.metallicRoughnessTexture orelse return -1;
    return @floatFromInt(roughTexture.texCoord);
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
    @memcpy(dest, data);
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

test "matrices" {
    const node = GLTF.Node{
        .translation = .{ 1, 2, 3 },
        .scale = .{ 4, 5, 6 },
    };
    try testing.expectEqualSlices(f32, &.{
        4, 0, 0, 0,
        0, 5, 0, 0,
        0, 0, 6, 0,
        1, 2, 3, 1,
    }, &create_transform(&node));
    try testing.expectEqualSlices(f32, &.{
        1, 0,  0,  0,
        0, -1, 0,  0,
        0, 0,  -1, 0,
        0, 0,  0,  1,
    }, &create_rotation(.{ 1, 0, 0, 0 }));
    try testing.expectEqualSlices(f32, &.{
        -1, 0, 0,  0,
        0,  1, 0,  0,
        0,  0, -1, 0,
        0,  0, 0,  1,
    }, &create_rotation(.{ 0, 1, 0, 0 }));
    try testing.expectEqualSlices(f32, &.{
        -1, 0,  0, 0,
        0,  -1, 0, 0,
        0,  0,  1, 0,
        0,  0,  0, 1,
    }, &create_rotation(.{ 0, 0, 1, 0 }));
    try testing.expectEqualSlices(f32, &.{
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1,
    }, &create_rotation(.{ 0, 0, 0, 1 }));
    const node_rotated = GLTF.Node{
        .scale = .{ 1, 2, 3 },
        .rotation = .{ 1, 0, 0, 0 },
        .translation = .{ 4, 5, 6 },
    };
    try testing.expectEqualSlices(f32, &.{
        1, 0,  0,  0,
        0, -2, 0,  0,
        0, 0,  -3, 0,
        4, 5,  6,  1,
    }, &create_transform(&node_rotated));
    try testing.expectEqualSlices(f32, &.{
        60,  69,  48,  43,
        144, 165, 120, 119,
        228, 261, 192, 195,
        312, 357, 264, 271,
    }, &multiply_matrices(.{
        1,  2,  3,  4,
        5,  6,  7,  8,
        9,  10, 11, 12,
        13, 14, 15, 16,
    }, .{
        1, 2, 3, 7,
        8, 7, 5, 4,
        5, 7, 5, 4,
        7, 8, 5, 4,
    }));
}
