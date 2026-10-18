//! What the agent writes and shows, as the chat draws it: a picture at its own
//! size (one image pixel per physical pixel, never upscaled), a tool card's path
//! that opens rather than expands, and Markdown's tables, links and images.
//!
//! Run: `zig build test`. Each case draws through dvui's testing backend at 1.0
//! and 1.75 — the owner's display, where a picture taken as logical pixels was
//! blown up 1.75× — reads the captured frame's physical rects back, and runs the
//! layout lint over the widget's own file.
const std = @import("std");
const dvui = @import("dvui");
const ds = @import("dvui_ds");
const lint = @import("ds_lint.zig");

const scales = [_]f32{ 1.0, 1.75 };

/// A testing window `logical` big at `scale`, `frame` settled.
fn open(scale: f32, logical: dvui.Size, frame: dvui.App.frameFunction) !dvui.testing {
    var t = try dvui.testing.init(.{
        .window_size = .{ .w = logical.w * scale / 2, .h = logical.h * scale / 2 },
        .window_init_opts = .{ .theme = ds.tokens.dvuiTheme() },
    });
    t.window.content_scale = scale / 2;
    _ = try dvui.testing.step(frame);
    try dvui.testing.settle(frame);
    return t;
}

/// Arm the frame capture and run the two steps that fill it.
fn capture(frame: dvui.App.frameFunction) !*const dvui.Debug.CapturedFrame {
    dvui.debug.captureFrame();
    _ = try dvui.testing.step(frame);
    _ = try dvui.testing.step(frame);
    return dvui.debug.lastCapture() orelse error.NoCapture;
}

/// The first captured widget named `name` drawn from `file`.
fn named(captured: *const dvui.Debug.CapturedFrame, file: []const u8, name: []const u8) ?*const dvui.Debug.CapturedWidget {
    for (captured.widgets.items) |*widget| {
        if (!std.mem.endsWith(u8, widget.src_file, file)) continue;
        const widget_name = widget.name orelse continue;
        if (std.mem.eql(u8, widget_name, name)) return widget;
    }
    return null;
}

// ─── A picture at its own size ───────────────────────────────────────────────

/// Light grey, opaque: every byte the same, so `@splat` fills it.
const small_picture: [210 * 140 * 4]u8 = @splat(200);
const wide_picture: [1000 * 500 * 4]u8 = @splat(200);

const PictureState = struct {
    var wide: bool = false;

    fn frame() !dvui.App.Result {
        var background = dvui.box(@src(), .{}, .{
            .expand = .both,
            .background = true,
            .color_fill = .{ .color = ds.tokens.current.surface_0 },
            .padding = dvui.Rect.all(8),
        });
        defer background.deinit();
        const source = if (wide)
            ds.Source.pixels(&wide_picture, 1000, 500)
        else
            ds.Source.pixels(&small_picture, 210, 140);
        _ = ds.chat.screenshotCard(@src(), "after the change", source).draw();
        return .ok;
    }
};

test "a screenshot card draws a picture one image pixel per physical pixel, at 1.0 and at 1.75" {
    for (scales) |scale| {
        PictureState.wide = false;
        var t = try open(scale, .{ .w = 640, .h = 400 }, PictureState.frame);
        defer t.deinit();
        const captured = try capture(PictureState.frame);
        defer dvui.debug.clearCaptures(std.testing.allocator);
        const picture = named(captured, "screenshot_card.zig", "image") orelse return error.NoImage;
        if (@abs(picture.rect_content.w - 210) > 0.5 or @abs(picture.rect_content.h - 140) > 0.5) {
            std.debug.print("scale {d}: a 210x140 picture is drawn {d:.1}x{d:.1} physical px\n", .{ scale, picture.rect_content.w, picture.rect_content.h });
            return error.PictureScaled;
        }
    }
}

test "a picture wider than the card's cap is narrowed to it, keeping its aspect ratio" {
    for (scales) |scale| {
        PictureState.wide = true;
        defer PictureState.wide = false;
        var t = try open(scale, .{ .w = 640, .h = 400 }, PictureState.frame);
        defer t.deinit();
        const captured = try capture(PictureState.frame);
        defer dvui.debug.clearCaptures(std.testing.allocator);
        const picture = named(captured, "screenshot_card.zig", "image") orelse return error.NoImage;
        // 1000 px is past the 420-logical cap at both scales: the cap wins.
        const cap = 420 * scale;
        try std.testing.expectApproxEqAbs(cap, picture.rect_content.w, 1);
        try std.testing.expectApproxEqAbs(cap / 2, picture.rect_content.h, 1);
    }
}

/// The layout lint over the widgets `source_file` drew in the captured frame.
fn expectLintClean(scale: f32, source_file: []const u8) !void {
    const counts = try lint.run(std.testing.allocator, scale, source_file, true);
    if (counts.total() != 0) {
        std.debug.print("scale {d}: {s} has {d} layout findings\n", .{ scale, source_file, counts.total() });
        return error.LintFindings;
    }
}

test "a screenshot card at its own size lints clean" {
    for (scales) |scale| {
        PictureState.wide = false;
        var t = try open(scale, .{ .w = 640, .h = 400 }, PictureState.frame);
        defer t.deinit();
        _ = try capture(PictureState.frame);
        defer dvui.debug.clearCaptures(std.testing.allocator);
        try expectLintClean(scale, "screenshot_card.zig");
    }
}
