const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // ─── External dependencies ───────────────────────────────────────────────
    const dvui_dep = b.dependency("dvui", .{
        .target = target,
        .optimize = optimize,
        .backend = .custom,
        .renderer = .wgpu,
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
    // Forward the target: zwgpu picks the prebuilt wgpu-native archive and the system
    // libraries per target, and would otherwise resolve to the host (a Linux
    // cross-build from Windows then tries to link ws2_32/userenv).
    const zwgpu = b.dependency("zwgpu", .{ .target = target, .optimize = optimize });

    // zwgpu (and dvui, for freetype) fetch some packages lazily. On a cold cache a
    // dependency's build script returns error.LazyDependencyNeeded *before* it has
    // registered its modules; the build runner then fetches and re-runs configure.
    // Asking such a dependency for a module in this run panics ("unable to find
    // module"), so stop here and let the re-run do the real work.
    if (b.graph.needed_lazy_dependencies.count() != 0) return;

    const dvui_mod = dvui_dep.module("dvui");
    // dvui creates its renderer module privately (createModule) and hangs it
    // off the dvui module as the "render_backend" import; the wgpu renderer
    // itself does `@import("wgpu")`, which the consumer must supply.
    const dvui_render_mod = dvui_mod.import_table.get("render_backend") orelse
        @panic("dvui module has no render_backend import; expected -Drenderer=wgpu");

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

    // ─── Re-exports for consumers ────────────────────────────────────────────
    // The engine (zigame) must use the *same* dvui / sdl3 / wgpu module instances
    // the design system was wired with — a second dvui instance would carry no
    // platform backend and no wgpu renderer. Expose them under this package so a
    // consumer's build.zig does `dvui_ds_dep.module("dvui")` etc. and never
    // repeats the wiring above.
    b.modules.put(b.allocator, "dvui", dvui_mod) catch @panic("OOM");
    b.modules.put(b.allocator, "sdl3", sdl3_dep.module("sdl3")) catch @panic("OOM");
    b.modules.put(b.allocator, "wgpu", zwgpu.module("root")) catch @panic("OOM");

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

    // ─── Component screenshots (headless CPU raster via dvui testing backend) ──
    // `zig build screenshots` renders each DS component to a PNG under
    // ds-screenshots/ — no GPU or window. Uses a second dvui built with the
    // testing backend (which rasterizes render targets on the CPU).
    const dvui_testing_dep = b.dependency("dvui", .{
        .target = target,
        .optimize = optimize,
        .backend = .testing,
    });
    const dvui_testing_mod = dvui_testing_dep.module("dvui_testing");
    // Headless dvui for consumers' own screenshot tests (same CPU rasteriser).
    b.modules.put(b.allocator, "dvui_testing", dvui_testing_mod) catch @panic("OOM");

    const ds_testing_mod = b.createModule(.{
        .root_source_file = b.path("src/ds.zig"),
        .target = target,
        .optimize = optimize,
    });
    ds_testing_mod.addImport("dvui", dvui_testing_mod);
    ds_testing_mod.addImport("ds_focus", focus_mod);

    // The editor-chrome mock is one file used twice: the storybook draws it as
    // a page, and the screenshot fixtures render it at two scales. Sharing the
    // source is the point — a design-review screenshot of a *copy* of the page
    // is worth nothing.
    const chrome_demo_mod = b.createModule(.{
        .root_source_file = b.path("example/pages/editor_chrome.zig"),
        .target = target,
        .optimize = optimize,
    });
    chrome_demo_mod.addImport("dvui", dvui_testing_mod);
    chrome_demo_mod.addImport("dvui_ds", ds_testing_mod);

    const shot_mod = b.createModule(.{
        .root_source_file = b.path("test/screenshots.zig"),
        .target = target,
        .optimize = optimize,
    });
    shot_mod.addImport("dvui", dvui_testing_mod);
    shot_mod.addImport("dvui_ds", ds_testing_mod);
    shot_mod.addImport("editor_chrome", chrome_demo_mod);

    const shot_tests = b.addTest(.{ .root_module = shot_mod });
    const run_shots = b.addRunArtifact(shot_tests);
    const shot_step = b.step("screenshots", "Render DS components to PNGs under ds-screenshots/");
    shot_step.dependOn(&run_shots.step);

    // ─── Layout tests (headless, but asserted numerically) ────────────────────
    // Widget geometry — centring, pixel snapping, the 4 px grid — is checked by
    // laying real widgets out through dvui's testing backend and reading their
    // physical rects back, at 1.0, 1.75 and 2.0. A screenshot cannot make that
    // claim, so these run as part of `zig build test`, not `screenshots`.
    const layout_mod = b.createModule(.{
        .root_source_file = b.path("test/layout_tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    layout_mod.addImport("dvui", dvui_testing_mod);
    layout_mod.addImport("dvui_ds", ds_testing_mod);

    const layout_tests = b.addTest(.{ .root_module = layout_mod });
    test_step.dependOn(&b.addRunArtifact(layout_tests).step);

    // The geometry gate: the same rules `zigame ui lint` runs over an editor
    // pane, run here over one ds widget at a time. See test/ds_lint.zig.
    const lint_mod = b.createModule(.{
        .root_source_file = b.path("test/lint_tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    lint_mod.addImport("dvui", dvui_testing_mod);
    lint_mod.addImport("dvui_ds", ds_testing_mod);

    const lint_tests = b.addTest(.{ .root_module = lint_mod });
    test_step.dependOn(&b.addRunArtifact(lint_tests).step);

    const cost_mod = b.createModule(.{
        .root_source_file = b.path("test/blur_cost.zig"),
        .target = target,
        .optimize = optimize,
    });
    cost_mod.addImport("dvui", dvui_testing_mod);
    cost_mod.addImport("dvui_ds", ds_testing_mod);
    cost_mod.addImport("editor_chrome", chrome_demo_mod);
    const cost_tests = b.addTest(.{ .root_module = cost_mod });
    const cost_step = b.step("blur-cost", "Measure one BlurBackdrop capture");
    cost_step.dependOn(&b.addRunArtifact(cost_tests).step);
}
