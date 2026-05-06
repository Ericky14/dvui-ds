const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // ─── External dependencies ───────────────────────────────────────────────
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
    const sdl3_dep = b.dependency("sdl3", .{
        .target = target,
        .optimize = optimize,
    });
    const zwgpu = b.dependency("zwgpu", .{});

    const dvui_mod = dvui_dep.module("dvui");
    const dvui_render_mod = dvui_dep.module("render_backend");

    // Wire wgpu into dvui render backend
    dvui_render_mod.addImport("wgpu", zwgpu.module("root"));

    // ─── Custom SDL3 platform backend for dvui ───────────────────────────────
    const focus_mod = b.addModule("ds_focus", .{
        .root_source_file = b.path("src/focus.zig"),
        .target = target,
        .optimize = optimize,
    });

    const sdl3_backend_mod = b.addModule("dvui_sdl3_backend", .{
        .root_source_file = b.path("src/platform/backend.zig"),
        .target = target,
        .optimize = optimize,
    });
    sdl3_backend_mod.addImport("sdl3", sdl3_dep.module("sdl3"));
    sdl3_backend_mod.addImport("dvui", dvui_mod);
    sdl3_backend_mod.addImport("ds_focus", focus_mod);

    // Wire custom backend into dvui
    dvui_mod.addImport("backend", sdl3_backend_mod);

    // ─── DS module (library + runner) ────────────────────────────────────────
    const ds_mod = b.addModule("dvui_ds", .{
        .root_source_file = b.path("src/ds.zig"),
        .target = target,
        .optimize = optimize,
    });
    ds_mod.addImport("dvui", dvui_mod);
    ds_mod.addImport("sdl3", sdl3_dep.module("sdl3"));
    ds_mod.addImport("wgpu", zwgpu.module("root"));
    ds_mod.addImport("ds_focus", focus_mod);

    // ─── Example / Storybook ─────────────────────────────────────────────────
    const example_mod = b.createModule(.{
        .root_source_file = b.path("example/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    example_mod.addImport("dvui_ds", ds_mod);
    example_mod.addImport("dvui", dvui_mod);
    example_mod.addImport("sdl3", sdl3_dep.module("sdl3"));

    const example_exe = b.addExecutable(.{
        .name = "dvui-ds-storybook",
        .root_module = example_mod,
    });
    b.installArtifact(example_exe);

    const run_example = b.addRunArtifact(example_exe);
    run_example.step.dependOn(b.getInstallStep());
    const run_step = b.step("example", "Run the storybook example");
    run_step.dependOn(&run_example.step);

    // ─── Tests ───────────────────────────────────────────────────────────────
    const test_mod = b.createModule(.{
        .root_source_file = b.path("src/ds.zig"),
        .target = target,
        .optimize = optimize,
    });
    test_mod.addImport("dvui", dvui_mod);
    test_mod.addImport("ds_focus", focus_mod);

    const unit_tests = b.addTest(.{
        .root_module = test_mod,
    });

    const run_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);
}
