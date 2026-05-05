const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // ─── dvui dependency ─────────────────────────────────────────────────────
    const dvui_dep = b.dependency("dvui", .{
        .target = target,
        .optimize = optimize,
        .backend = .custom,
        .@"render-backend" = .wgpu,
        .freetype = true,
        .libc = true,
        .@"stb-image" = true,
        .@"tiny-file-dialogs" = false,
        .@"tree-sitter" = false,
    });

    // ─── DS module ───────────────────────────────────────────────────────────
    const ds_mod = b.addModule("dvui_ds", .{
        .root_source_file = b.path("src/ds.zig"),
        .target = target,
        .optimize = optimize,
    });
    ds_mod.addImport("dvui", dvui_dep.module("dvui"));

    // ─── Example / Storybook ─────────────────────────────────────────────────
    const example_mod = b.createModule(.{
        .root_source_file = b.path("example/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    example_mod.addImport("dvui_ds", ds_mod);
    example_mod.addImport("dvui", dvui_dep.module("dvui"));

    const example_exe = b.addExecutable(.{
        .name = "dvui-ds-storybook",
        .root_module = example_mod,
    });
    b.installArtifact(example_exe);

    const run_example = b.addRunArtifact(example_exe);
    run_example.step.dependOn(b.getInstallStep());
    const run_step = b.step("example", "Run the storybook example");
    run_step.dependOn(&run_example.step);
}
