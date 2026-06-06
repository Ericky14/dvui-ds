//! Component screenshots — headless CPU rendering via dvui's testing backend.
//!
//! Run:  zig build screenshots
//! Output: ds-screenshots/<name>.png (one per component).
//!
//! Each test renders a DS component into a Picture target and writes a PNG.
//! No GPU or window — deterministic, so these double as visual regression
//! fixtures (commit the PNGs and diff them).
const std = @import("std");
const dvui = @import("dvui");
const ds = @import("dvui_ds");

/// Render `frame` once (settled) and write it to ds-screenshots/<name>.
fn capture(name: []const u8, w: f32, h: f32, frame: dvui.App.frameFunction) !void {
    var t = try dvui.testing.init(.{
        .image_dir = "ds-screenshots",
        .window_size = .{ .w = w, .h = h },
        .window_init_opts = .{ .theme = ds.tokens.dvuiTheme() },
    });
    defer t.deinit();
    try dvui.testing.settle(frame);
    try t.saveImage(frame, null, name);
}

/// Full-window themed background so components sit on the app surface.
fn background(src: std.builtin.SourceLocation) *dvui.BoxWidget {
    return dvui.box(src, .{}, .{
        .expand = .both,
        .background = true,
        .color_fill = ds.tokens.current.surface_0,
    });
}

test "buttons" {
    const Local = struct {
        fn frame() !dvui.App.Result {
            var bg = background(@src());
            defer bg.deinit();
            var col = ds.column(@src()).padding(ds.tokens.current.space_lg).draw();
            defer col.deinit();
            var row = ds.row(@src()).gap(ds.tokens.current.space_sm).draw();
            defer row.deinit();
            _ = ds.button(@src(), "Primary").variant(.filled).draw();
            _ = ds.button(@src(), "Outlined").variant(.outlined).draw();
            _ = ds.button(@src(), "Ghost").variant(.ghost).draw();
            return .ok;
        }
    };
    try capture("buttons.png", 320, 90, Local.frame);
}

test "labels" {
    const Local = struct {
        fn frame() !dvui.App.Result {
            var bg = background(@src());
            defer bg.deinit();
            var col = ds.column(@src()).padding(ds.tokens.current.space_lg).gap(ds.tokens.current.space_xs).draw();
            defer col.deinit();
            ds.label(@src(), "Title").style(.title).draw();
            ds.label(@src(), "Secondary").style(.secondary).draw();
            ds.label(@src(), "Muted caption").style(.muted).draw();
            return .ok;
        }
    };
    try capture("labels.png", 260, 170, Local.frame);
}

test "text input" {
    const Local = struct {
        var buffer: [64]u8 = @splat(0);
        fn frame() !dvui.App.Result {
            var bg = background(@src());
            defer bg.deinit();
            var col = ds.column(@src()).padding(ds.tokens.current.space_lg).expand(.horizontal).draw();
            defer col.deinit();
            ds.textInput(@src(), &buffer).label("Email").helper("We'll never share it.").draw();
            return .ok;
        }
    };
    @memcpy(Local.buffer[0.."hello@example.com".len], "hello@example.com");
    try capture("text_input.png", 320, 150, Local.frame);
}
