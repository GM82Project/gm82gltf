const std = @import("std");
const builtin = @import("builtin");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{ .default_target = .{ .cpu_arch = .x86, .os_tag = .windows, .abi = .msvc } });

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addSharedLibrary(.{
        .name = "gm82gltf",
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const artifact_step = b.addInstallArtifact(lib, .{});

    // get gm82gex
    const gm82gex_download = b.addSystemCommand(&.{ "curl", "https://raw.githubusercontent.com/GM82Project/gm82gex/main/gm82gex.py" });
    const gm82gex_output = gm82gex_download.captureStdOut();
    const gm82gex_file = b.addInstallFileWithDir(gm82gex_output, .prefix, "gm82gex.py");

    const gm82gex_run = b.addSystemCommand(&.{if (builtin.os.tag == .windows) "py" else "python3"});
    gm82gex_run.addArg(b.getInstallPath(gm82gex_file.dir, gm82gex_file.dest_rel_path));
    gm82gex_run.addFileArg(.{ .src_path = .{ .owner = b, .sub_path = "gm82gltf.gej" } });
    gm82gex_run.step.dependOn(&gm82gex_file.step);
    gm82gex_run.step.dependOn(&artifact_step.step);
    b.getInstallStep().dependOn(&gm82gex_run.step);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}
