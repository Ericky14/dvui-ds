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
    var caption: []const u8 = "after the change";
    var max_width: f32 = 420;

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
        _ = ds.chat.screenshotCard(@src(), caption, source).maxWidth(max_width).draw();
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
        // 1000 px is past the 420-logical cap at both scales: the cap wins,
        // and it holds the card as drawn, its border included — a caller that
        // passes the row's width gets a card that fits the row.
        const cap = 420 * scale;
        try std.testing.expectApproxEqAbs(cap, picture.rect_border.w, 0.5);
        try std.testing.expectApproxEqAbs(picture.rect_content.w / 2, picture.rect_content.h, 1);
    }
}

test "a caption longer than the card's cap wraps there, never widening the card or ending in an ellipsis" {
    const long_caption = ".zigame/screenshots/2026-10-18T16-04-11Z-after-the-fox-was-dressed.png";
    for (scales) |scale| {
        PictureState.caption = long_caption;
        PictureState.max_width = 240;
        defer {
            PictureState.caption = "after the change";
            PictureState.max_width = 420;
        }
        var t = try open(scale, .{ .w = 640, .h = 400 }, PictureState.frame);
        defer t.deinit();
        const captured = try capture(PictureState.frame);
        defer dvui.debug.clearCaptures(std.testing.allocator);
        const picture = named(captured, "screenshot_card.zig", "image") orelse return error.NoImage;
        var words: ?*const dvui.Debug.CapturedWidget = null;
        for (captured.widgets.items) |*widget| {
            if (!std.mem.endsWith(u8, widget.src_file, "screenshot_card.zig")) continue;
            const label = widget.label orelse continue;
            if (std.mem.eql(u8, label, long_caption)) words = widget;
        }
        const caption = words orelse return error.NoCaption;
        // The words end inside the card's cap (240 logical from the picture's
        // left edge), on more than one line.
        const cap_right = picture.rect_border.x + 240 * scale;
        const caption_right = caption.rect_border.x + caption.rect_border.w;
        if (caption_right > cap_right + 0.5) {
            std.debug.print("scale {d}: the caption ends at {d:.1}, the card's cap at {d:.1} — the card was widened\n", .{ scale, caption_right, cap_right });
            return error.CaptionWidensCard;
        }
        try std.testing.expect(caption.rect_content.h > 1.5 * caption.font.lineHeight() * scale);
        try expectLintClean(scale, "screenshot_card.zig");
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

// ─── A tool card's path opens ────────────────────────────────────────────────

const LinkState = struct {
    var opened: bool = false;
    var expanded: bool = false;

    fn reset() void {
        opened = false;
        expanded = false;
    }

    fn frame() !dvui.App.Result {
        var background = dvui.box(@src(), .{}, .{
            .expand = .both,
            .background = true,
            .color_fill = .{ .color = ds.tokens.current.surface_0 },
            .padding = dvui.Rect.all(8),
        });
        defer background.deinit();
        ds.chat.toolCard(@src(), "Write", "D:/games/fox/DESIGN.md", .ok)
            .details("# Fox\nA small game.")
            .expanded(&expanded)
            .link("DESIGN.md", &opened)
            .draw();
        return .ok;
    }
};

/// The captured widget that shows exactly `text`, drawn from `file`.
fn shown(captured: *const dvui.Debug.CapturedFrame, file: []const u8, text: []const u8) ?*const dvui.Debug.CapturedWidget {
    for (captured.widgets.items) |*widget| {
        if (!std.mem.endsWith(u8, widget.src_file, file)) continue;
        const label = widget.label orelse continue;
        if (std.mem.eql(u8, label, text)) return widget;
    }
    return null;
}

/// Press and release the left button at `point` (physical), then let two frames
/// see it.
fn clickAt(point: dvui.Point.Physical, frame: dvui.App.frameFunction) !void {
    const window = dvui.currentWindow();
    _ = try window.addEventMouseMotion(.{ .pt = point });
    try dvui.testing.click(.left);
    _ = try dvui.testing.step(frame);
    _ = try dvui.testing.step(frame);
}

/// The centre of the widget that shows `text` in a fresh capture.
fn centreOf(file: []const u8, text: []const u8, frame: dvui.App.frameFunction) !dvui.Point.Physical {
    const captured = try capture(frame);
    defer dvui.debug.clearCaptures(std.testing.allocator);
    const widget = shown(captured, file, text) orelse {
        std.debug.print("nothing from {s} shows \"{s}\"\n", .{ file, text });
        return error.TextNotShown;
    };
    return widget.rect_border.center();
}

test "clicking a tool card's path opens it and leaves the card as it was" {
    for (scales) |scale| {
        LinkState.reset();
        var t = try open(scale, .{ .w = 480, .h = 200 }, LinkState.frame);
        defer t.deinit();
        try clickAt(try centreOf("tool_card.zig", "DESIGN.md", LinkState.frame), LinkState.frame);
        if (!LinkState.opened) {
            std.debug.print("scale {d}: clicking the path did not open it (expanded: {})\n", .{ scale, LinkState.expanded });
            return error.NotOpened;
        }
        try std.testing.expect(!LinkState.expanded);
    }
}

test "clicking the rest of a linked tool card still expands it" {
    for (scales) |scale| {
        LinkState.reset();
        var t = try open(scale, .{ .w = 480, .h = 200 }, LinkState.frame);
        defer t.deinit();
        try clickAt(try centreOf("tool_card.zig", "Write", LinkState.frame), LinkState.frame);
        try std.testing.expect(LinkState.expanded);
        try std.testing.expect(!LinkState.opened);
    }
}

test "a tool card's path is a tab stop: Tab reaches it and Enter opens it" {
    for (scales) |scale| {
        LinkState.reset();
        var t = try open(scale, .{ .w = 480, .h = 200 }, LinkState.frame);
        defer t.deinit();
        try dvui.testing.pressKey(.tab, .none);
        _ = try dvui.testing.step(LinkState.frame);
        try dvui.testing.pressKey(.enter, .none);
        _ = try dvui.testing.step(LinkState.frame);
        _ = try dvui.testing.step(LinkState.frame);
        try std.testing.expect(LinkState.opened);
        try std.testing.expect(!LinkState.expanded);
    }
}

test "a linked tool card lints clean" {
    for (scales) |scale| {
        LinkState.reset();
        var t = try open(scale, .{ .w = 480, .h = 200 }, LinkState.frame);
        defer t.deinit();
        _ = try capture(LinkState.frame);
        defer dvui.debug.clearCaptures(std.testing.allocator);
        try expectLintClean(scale, "tool_card.zig");
    }
}

// ─── Markdown: tables, links, paths, images ──────────────────────────────────

const design_doc =
    \\# Fox and the Beetle
    \\
    \\| Piece | Source |
    \\|---|---|
    \\| Fox | the art pipeline |
    \\| Island | a kit |
    \\
    \\- Look first
    \\- Then the layout
    \\
    \\See [the plan](PLAN.md) and DESIGN.md, then `scripts/fox.lua`.
    \\
    \\![the fox](art/fox.png)
    \\
    \\![missing](art/none.png)
;

const fox_picture: [120 * 80 * 4]u8 = @splat(160);

const MarkdownState = struct {
    var clicked: []const u8 = "";

    fn acceptsPath(context: *const anyopaque, word: []const u8) bool {
        _ = context;
        return std.mem.eql(u8, word, "DESIGN.md") or std.mem.eql(u8, word, "scripts/fox.lua");
    }

    fn resolveImage(context: *const anyopaque, target: []const u8) ?dvui.ImageSource {
        _ = context;
        if (!std.mem.eql(u8, target, "art/fox.png")) return null;
        return .{ .pixels = .{ .rgba = &fox_picture, .width = 120, .height = 80 } };
    }

    fn frame() !dvui.App.Result {
        var background = dvui.box(@src(), .{}, .{
            .expand = .both,
            .background = true,
            .color_fill = .{ .color = ds.tokens.current.surface_0 },
            .padding = dvui.Rect.all(8),
        });
        defer background.deinit();
        ds.chat.markdown(@src(), design_doc)
            .paths(.{ .context = &fox_picture, .accepts = acceptsPath })
            .images(.{ .context = &fox_picture, .resolve = resolveImage })
            .clicked(&clicked)
            .draw();
        return .ok;
    }
};

test "Markdown renders a heading, a table and a list" {
    for (scales) |scale| {
        var t = try open(scale, .{ .w = 480, .h = 520 }, MarkdownState.frame);
        defer t.deinit();
        const captured = try capture(MarkdownState.frame);
        defer dvui.debug.clearCaptures(std.testing.allocator);
        try std.testing.expect(shown(captured, "markdown.zig", "Fox and the Beetle") != null);
        try std.testing.expect(shown(captured, "markdown.zig", "Look first") != null);
        // The table's cells are cells: each its own widget, a row's side by side.
        const cells = [_][]const u8{ "Piece", "Source", "Fox", "the art pipeline", "Island", "a kit" };
        var found: [cells.len]*const dvui.Debug.CapturedWidget = undefined;
        for (cells, 0..) |cell, index| {
            found[index] = shown(captured, "markdown.zig", cell) orelse {
                std.debug.print("scale {d}: no table cell shows \"{s}\"\n", .{ scale, cell });
                return error.NoTableCell;
            };
        }
        var row: usize = 0;
        while (row < cells.len) : (row += 2) {
            const left = found[row];
            const right = found[row + 1];
            try std.testing.expectApproxEqAbs(left.rect_border.y, right.rect_border.y, 0.5);
            try std.testing.expect(right.rect_border.x >= left.rect_border.x + left.rect_border.w - 0.5);
        }
        try std.testing.expect(found[2].rect_border.y > found[0].rect_border.y);
        try std.testing.expect(found[4].rect_border.y > found[2].rect_border.y);
    }
}

test "Markdown draws an image block at its own size, and says which one it could not find" {
    for (scales) |scale| {
        var t = try open(scale, .{ .w = 480, .h = 520 }, MarkdownState.frame);
        defer t.deinit();
        const captured = try capture(MarkdownState.frame);
        defer dvui.debug.clearCaptures(std.testing.allocator);
        const picture = named(captured, "markdown.zig", "image") orelse return error.NoImage;
        try std.testing.expectApproxEqAbs(@as(f32, 120), picture.rect_content.w, 0.5);
        try std.testing.expectApproxEqAbs(@as(f32, 80), picture.rect_content.h, 0.5);
        try std.testing.expect(shown(captured, "markdown.zig", "art/none.png") != null);
    }
}

/// The centre of `run` on the first line of the paragraph that shows
/// `paragraph_text`, `before` being the words ahead of it: a run's own rectangle
/// is not captured, so it is measured with the paragraph's font.
fn runCentre(paragraph_text: []const u8, before: []const u8, run: []const u8) !dvui.Point.Physical {
    const captured = try capture(MarkdownState.frame);
    defer dvui.debug.clearCaptures(std.testing.allocator);
    const paragraph = shown(captured, "markdown.zig", paragraph_text) orelse return error.TextNotShown;
    const scale = dvui.windowRectScale().s;
    const font = paragraph.font;
    const offset = font.textSize(before).w * scale;
    const width = font.textSize(run).w * scale;
    return .{
        .x = paragraph.rect_content.x + offset + width / 2,
        .y = paragraph.rect_content.y + font.lineHeight() * scale / 2,
    };
}

const link_paragraph = "See the plan and DESIGN.md, then scripts/fox.lua.";

test "Markdown says which link was clicked: a link's target, or a path the caller accepts" {
    for (scales) |scale| {
        MarkdownState.clicked = "";
        var t = try open(scale, .{ .w = 480, .h = 520 }, MarkdownState.frame);
        defer t.deinit();
        try clickAt(try runCentre(link_paragraph, "See ", "the plan"), MarkdownState.frame);
        try std.testing.expectEqualStrings("PLAN.md", MarkdownState.clicked);
        MarkdownState.clicked = "";
        try clickAt(try runCentre(link_paragraph, "See the plan and ", "DESIGN.md"), MarkdownState.frame);
        if (!std.mem.eql(u8, MarkdownState.clicked, "DESIGN.md")) {
            std.debug.print("scale {d}: clicking DESIGN.md in the text reported \"{s}\"\n", .{ scale, MarkdownState.clicked });
            return error.PathNotLinked;
        }
        MarkdownState.clicked = "";
        try clickAt(try runCentre(link_paragraph, "See the plan and DESIGN.md, then ", "scripts/fox.lua"), MarkdownState.frame);
        try std.testing.expectEqualStrings("scripts/fox.lua", MarkdownState.clicked);
        MarkdownState.clicked = "";
        try clickAt(try runCentre(link_paragraph, "", "See"), MarkdownState.frame);
        try std.testing.expectEqualStrings("", MarkdownState.clicked);
    }
}

test "Markdown with a table, links and images lints clean" {
    for (scales) |scale| {
        var t = try open(scale, .{ .w = 480, .h = 520 }, MarkdownState.frame);
        defer t.deinit();
        _ = try capture(MarkdownState.frame);
        defer dvui.debug.clearCaptures(std.testing.allocator);
        try expectLintClean(scale, "markdown.zig");
    }
}

const MessageState = struct {
    var clicked: []const u8 = "";

    fn frame() !dvui.App.Result {
        var background = dvui.box(@src(), .{}, .{
            .expand = .both,
            .background = true,
            .color_fill = .{ .color = ds.tokens.current.surface_0 },
            .padding = dvui.Rect.all(8),
        });
        defer background.deinit();
        ds.chat.message(@src(), .assistant, "Wrote DESIGN.md for the plan.")
            .paths(.{ .context = &fox_picture, .accepts = MarkdownState.acceptsPath })
            .clicked(&clicked)
            .draw();
        return .ok;
    }
};

test "an assistant reply hands its paths and clicks to its Markdown" {
    for (scales) |scale| {
        MessageState.clicked = "";
        var t = try open(scale, .{ .w = 480, .h = 200 }, MessageState.frame);
        defer t.deinit();
        const captured = try capture(MessageState.frame);
        const paragraph = shown(captured, "markdown.zig", "Wrote DESIGN.md for the plan.") orelse return error.TextNotShown;
        const window_scale = dvui.windowRectScale().s;
        const point: dvui.Point.Physical = .{
            .x = paragraph.rect_content.x + (paragraph.font.textSize("Wrote ").w + paragraph.font.textSize("DESIGN.md").w / 2) * window_scale,
            .y = paragraph.rect_content.y + paragraph.font.lineHeight() * window_scale / 2,
        };
        dvui.debug.clearCaptures(std.testing.allocator);
        try clickAt(point, MessageState.frame);
        try std.testing.expectEqualStrings("DESIGN.md", MessageState.clicked);
    }
}
