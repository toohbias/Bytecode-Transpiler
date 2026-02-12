const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const upstream = b.dependency("miniz", .{});

    const exe = b.addExecutable(.{
        .name = "Bytecode_Transpiler",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    
    exe.root_module.addIncludePath(upstream.path(""));
    exe.root_module.addCSourceFile(.{ .file = upstream.path("miniz.c") });
    exe.installHeader(upstream.path(""), "miniz.h");

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const unit_test = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
        }),
    });

    const test_step = b.step("test", "Run unit tests");

    const test_cmd = b.addRunArtifact(unit_test);
    test_step.dependOn(&test_cmd.step);

}
