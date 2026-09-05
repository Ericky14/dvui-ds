//! Screenshot fixtures for the window-chrome widgets — `ds.glass` /
//! `ds.glassScene`, `ds.windowFrame`, `ds.previewFrame`, `ds.chip`, `ds.pill` —
//! plus the composed "editor chrome" page that puts all of them together at two
//! display scales.
//!
//! Run: `zig build screenshots`. Every fixture gives its widget a real size — a
//! widget handed only a width collapses to zero height and shows nothing.
//!
//! The glass fixtures double as proof that the backdrop blur really renders
//! through dvui's CPU testing backend (which does implement
//! `textureCreateTarget` / `renderTarget` / `textureFromTarget`), and not only
//! on the wgpu renderer the app uses.
const std = @import("std");
const dvui = @import("dvui");
const ds = @import("dvui_ds");
const shots = @import("screenshots.zig");
const chrome = @import("editor_chrome");

// ─── A stand-in for the 3-D preview ──────────────────────────────────────────

/// Re-exported from the shared mock so every fixture blurs the same picture.
const picture = chrome.picture;

// ─── Single-widget fixtures ──────────────────────────────────────────────────

test "glass" {
    const Local = struct {
        fn frame() !dvui.App.Result {
            var page = dvui.box(@src(), .{}, .{
                .expand = .both,
                .background = true,
                .color_fill = .{ .color = ds.tokens.current.surface_0 },
                .padding = dvui.Rect.all(16),
            });
            defer page.deinit();

            const stage: dvui.Rect = .{ .x = 16, .y = 16, .w = 448, .h = 208 };
            // Over the *bright* half of the picture on purpose: a glass panel
            // over a dark patch is indistinguishable from an opaque one, which
            // makes for a flattering fixture and a useless one.
            const blurred: dvui.Rect = .{ .x = 36, .y = 84, .w = 190, .h = 120 };
            const solid: dvui.Rect = .{ .x = 254, .y = 84, .w = 190, .h = 120 };

            const scene = ds.glassScene(@src()).rect(stage).begin();
            picture(@src(), dvui.CornerRect.round(ds.tokens.current.preview_radius));
            {
                var surface = ds.glass(@src()).rect(blurred).scene(scene).gap(2).draw();
                defer surface.deinit();
                ds.label(@src(), "glass").style(.primary).font(.heading).draw();
                ds.label(@src(), "backdrop blur 24px").style(.muted).draw();
            }
            {
                var surface = ds.glass(@src()).rect(solid).solid(true).gap(2).draw();
                defer surface.deinit();
                ds.label(@src(), "solid").style(.primary).font(.heading).draw();
                ds.label(@src(), "no-blur fallback").style(.muted).draw();
            }
            scene.end();
            return .ok;
        }
    };
    try shots.capture("glass.png", 480, 240, Local.frame);
}

test "window frame" {
    const Local = struct {
        fn pane(src: std.builtin.SourceLocation, title: []const u8, has_focus: bool) void {
            var shell = ds.windowFrame(src).focused(has_focus).draw();
            defer shell.deinit();
            var pad = ds.column(@src()).padding(ds.tokens.current.space_lg).gap(ds.tokens.current.space_2xs).draw();
            defer pad.deinit();
            ds.label(@src(), title).style(.primary).font(.heading).draw();
            ds.label(@src(), "black ring + white hairline").style(.muted).draw();
        }
        fn frame() !dvui.App.Result {
            var page = dvui.box(@src(), .{}, .{
                .expand = .both,
                .background = true,
                .color_fill = .{ .color = .fromHex("#2C313C") },
                .padding = dvui.Rect.all(12),
            });
            defer page.deinit();
            var row = ds.row(@src()).gap(12).expand(.both).draw();
            defer row.deinit();
            pane(@src(), "Focused", true);
            pane(@src(), "Unfocused", false);
            return .ok;
        }
    };
    try shots.capture("window_frame.png", 520, 140, Local.frame);
}

test "preview frame" {
    const Local = struct {
        fn frame() !dvui.App.Result {
            var page = dvui.box(@src(), .{}, .{
                .expand = .both,
                .background = true,
                .color_fill = .{ .color = ds.tokens.current.surface_0 },
            });
            defer page.deinit();

            var preview = ds.previewFrame(@src()).draw();
            picture(@src(), preview.corners());
            preview.deinit();
            return .ok;
        }
    };
    try shots.capture("preview_frame.png", 420, 240, Local.frame);
}

test "chips" {
    const Local = struct {
        fn frame() !dvui.App.Result {
            var page = dvui.box(@src(), .{}, .{
                .expand = .both,
                .background = true,
                .color_fill = .{ .color = ds.tokens.current.surface_0 },
            });
            defer page.deinit();
            var col = ds.column(@src()).padding(ds.tokens.current.space_lg).gap(ds.tokens.current.space_md).draw();
            defer col.deinit();

            ds.label(@src(), "rest · rest · active · current · faded").style(.muted).draw();
            var strip = ds.row(@src()).gap(ds.tokens.current.space_2xs).draw();
            defer strip.deinit();
            _ = ds.chip(@src(), "undo", ds.icons.undo).idExtra(0).draw();
            _ = ds.chip(@src(), "redo", ds.icons.redo).idExtra(1).draw();
            _ = ds.chip(@src(), "pencil", ds.icons.pencil).state(.active).idExtra(2).draw();
            _ = ds.chip(@src(), "square-pen", ds.icons.square_pen).state(.current).idExtra(3).draw();
            _ = ds.chip(@src(), "history", ds.icons.history).state(.faded).idExtra(4).draw();
            _ = ds.chip(@src(), "camera", ds.icons.camera).state(.faded).idExtra(5).draw();
            return .ok;
        }
    };
    try shots.capture("chips.png", 340, 110, Local.frame);
}

test "pills" {
    const Local = struct {
        fn frame() !dvui.App.Result {
            var page = dvui.box(@src(), .{}, .{
                .expand = .both,
                .background = true,
                .color_fill = .{ .color = ds.tokens.current.surface_0 },
            });
            defer page.deinit();
            var col = ds.column(@src()).padding(ds.tokens.current.space_lg).gap(ds.tokens.current.space_sm).draw();
            defer col.deinit();
            {
                var row = ds.row(@src()).gap(ds.tokens.current.space_sm).draw();
                defer row.deinit();
                ds.pill(@src(), "Ground · 2").tone(.accent).icon("box", ds.icons.box).draw();
                ds.pill(@src(), "60 fps").mono(true).draw();
            }
            {
                var row = ds.row(@src()).gap(ds.tokens.current.space_sm).draw();
                defer row.deinit();
                ds.pill(@src(), "7 entities").draw();
                ds.pill(@src(), "3 errors").tone(.danger).draw();
            }
            return .ok;
        }
    };
    try shots.capture("pills.png", 340, 130, Local.frame);
}

test "pills on black" {
    // The headless fixtures put chrome over a black picture, where every white
    // alpha reads at full contrast. A highlight that is subtle over a lit scene
    // and a bright ring over black is not subtle — it is unmeasured.
    const Local = struct {
        fn frame() !dvui.App.Result {
            var page = dvui.box(@src(), .{}, .{
                .expand = .both,
                .background = true,
                .color_fill = .{ .color = .black },
            });
            defer page.deinit();
            const theme = ds.tokens.current;
            var strip = ds.glass(@src())
                .rect(.{ .x = 20, .y = 20, .w = 300, .h = theme.chrome_toolbar_height })
                .solid(true)
                .horizontal()
                .gap(theme.space_sm)
                .padding(theme.space_xs)
                .radius(theme.radius_md)
                .draw();
            defer strip.deinit();
            ds.pill(@src(), "Ground · 2").tone(.accent).icon("box", ds.icons.box).draw();
            ds.pill(@src(), "60 fps").mono(true).draw();
            ds.pill(@src(), "7 entities").draw();
            return .ok;
        }
    };
    try shots.captureAt("pills_on_black.png", 340, 90, 1.75, Local.frame);
}

// ─── The composed editor chrome ──────────────────────────────────────────────
// Rendered from `example/pages/editor_chrome.zig` — the same source the
// storybook runs, so the review screenshots and the live page cannot drift.

test "editor chrome at scale 1.0" {
    try shots.captureAt("editor_chrome_1x.png", 900, 560, 1.0, chrome.frame);
}

test "editor chrome at scale 1.75" {
    try shots.captureAt("editor_chrome_175x.png", 900, 560, 1.75, chrome.frame);
}
