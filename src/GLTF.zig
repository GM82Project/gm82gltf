const std = @import("std");
const Value = std.json.Value;

accessors: ?[]Accessor = null,
animations: ?[]Animation = null,
asset: Asset,
buffers: ?[]Buffer = null,
bufferViews: ?[]BufferView = null,
cameras: ?[]Camera = null,
images: ?[]Image = null,
materials: ?[]Material = null,
meshes: ?[]Mesh = null,
nodes: ?[]Node = null,
samplers: ?[]Sampler = null,
scene: ?usize = null,
scenes: ?[]Scene = null,
skins: ?[]Skin = null,
textures: ?[]Texture = null,

pub const Accessor = struct {
    bufferView: ?usize = null,
    byteOffset: usize = 0,
    componentType: usize,
    normalized: bool = false,
    count: usize,
    type: []const u8,
    name: ?[]const u8 = null,
};

pub const Animation = struct {
    pub const Channel = struct {
        pub const Target = struct {
            node: ?usize = null,
            path: []const u8,
        };
        sampler: usize,
        target: Target,
    };
    pub const Sampler = struct {
        input: usize,
        interpolation: []const u8 = "LINEAR",
        output: usize,
    };
    channels: []Channel,
    samplers: []Animation.Sampler,
    name: ?[]const u8 = null,
};

pub const Asset = struct {
    copyright: ?[]const u8 = null,
    generator: ?[]const u8 = null,
    version: []const u8,
    minVersion: ?[]const u8 = null,
};

pub const Buffer = struct {
    uri: ?[]const u8 = null,
    byteLength: usize,
    name: ?[]const u8 = null,
};

pub const BufferView = struct {
    buffer: usize,
    byteOffset: usize = 0,
    byteLength: usize,
    byteStride: ?usize = null,
    name: ?[]const u8 = null,
    target: ?usize = null,
};

pub const Camera = struct {
    pub const Orthographic = struct {
        xmag: f32,
        ymag: f32,
        zfar: f32,
        znear: f32,
    };
    pub const Perspective = struct {
        aspectRatio: f32,
        yfov: f32,
        zfar: f32,
        znear: f32,
    };
    orthographic: ?Orthographic = null,
    perspective: ?Perspective = null,
    type: []const u8,
};

pub const Image = struct {
    uri: ?[]const u8 = null,
    mimeType: ?[]const u8 = null,
    bufferView: ?usize = null,
    name: ?[]const u8 = null,
};

pub const Material = struct {
    const PBRMetallicRoughness = struct {
        baseColorFactor: [4]f32 = .{ 1, 1, 1, 1 },
        baseColorTexture: ?TextureInfo = null,
        metallicFactor: f32 = 1,
        roughnessFactor: f32 = 1,
        metallicRoughnessTexture: ?TextureInfo = null,
    };
    const NormalTextureInfo = struct {
        index: usize,
        texCoord: usize = 0,
        scale: f32 = 1,
    };
    const OcclusionTextureInfo = struct {
        index: usize,
        texCoord: usize = 0,
        strength: f32 = 1,
    };
    name: ?[]const u8 = null,
    pbrMetallicRoughness: PBRMetallicRoughness = .{},
    normalTexture: ?NormalTextureInfo = null,
    occlusionTexture: ?OcclusionTextureInfo = null,
    emissiveTexture: ?TextureInfo = null,
    emissiveFactor: [3]f32 = .{ 0, 0, 0 },
    alphaMode: []const u8 = "OPAQUE",
    alphaCutoff: f32 = 0.5,
    doubleSided: bool = false,
};

pub const Mesh = struct {
    pub const Primitive = struct {
        attributes: std.json.ArrayHashMap(usize),
        indices: ?usize = null,
        material: ?usize = null,
        mode: usize = 4,
    };
    primitives: []const Primitive,
    name: ?[]const u8 = null,
};

pub const Node = struct {
    camera: ?usize = null,
    children: ?[]usize = null,
    skin: ?usize = null,
    matrix: [16]f32 = .{ 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1 },
    mesh: ?usize = null,
    rotation: [4]f32 = .{ 0, 0, 0, 1 },
    scale: [3]f32 = .{ 1, 1, 1 },
    translation: [3]f32 = .{ 0, 0, 0 },
    name: ?[]const u8 = null,
};

pub const Sampler = struct {
    magFilter: ?usize = null,
    minFilter: ?usize = null,
    wrapS: usize = 10497,
    wrapT: usize = 10497,
    name: ?[]const u8 = null,
};

pub const Scene = struct {
    nodes: ?[]usize = null,
    name: ?[]const u8 = null,
};

pub const Skin = struct {
    inverseBindMatrices: ?usize = null,
    skeleton: ?usize = null,
    joints: []usize,
    name: ?[]const u8 = null,
};

pub const Texture = struct {
    sampler: ?usize = null,
    source: ?usize = null,
    name: ?[]const u8 = null,
};

pub const TextureInfo = struct {
    index: usize,
    texCoord: usize = 0,
};
