//! The chat composer's geometry, asserted in numbers.
//!
//! Run: `zig build test`.
//!
//! The owner's complaint against the live editor was "too tall and not
//! uniform", and the dump said why: a 50.50 logical frame for one line of text,
//! holding three controls of three different heights (28.00, 32.50, 26.11) each
//! bottom-aligned by a spacer, so their tops were ragged. These tests pin the
//! shape that fixes it — one control height for the row, a frame that is
//! exactly that plus its padding, and controls that share a top and a bottom
//! edge — at 1.0, 1.75 and 2.0.
const std = @import("std");
const dvui = @import("dvui");
const ds = @import("dvui_ds");
const lint = @import("ds_lint.zig");

const scales = [_]f32{ 1.0, 1.75, 2.0 };

var buffer: [512]u8 = @splat(0);

fn setText(text: []const u8) void {
    buffer = @splat(0);
    @memcpy(buffer[0..text.len], text);
}

fn frame() !dvui.App.Result {
    var page = dvui.box(@src(), .{}, .{
        .expand = .both,
        .background = true,
        .color_fill = .{ .color = ds.tokens.current.surface_0 },
        .padding = dvui.Rect.all(8),
    });
    defer page.deinit();
    _ = ds.chat.composer(@src(), &buffer).draw();
    return .ok;
}

/// Settle a frame at `scale` and hand back the captured widget tree.
fn snapshotAt(scale: f32, logical: dvui.Size) ![]lint.Node {
    var t = try dvui.testing.init(.{
        .window_size = .{ .w = logical.w * scale / 2, .h = logical.h * scale / 2 },
        .window_init_opts = .{ .theme = ds.tokens.dvuiTheme() },
    });
    defer t.deinit();
    t.window.content_scale = scale / 2;
    _ = try dvui.testing.step(frame);
    try dvui.testing.settle(frame);

    dvui.debug.captureFrame();
    _ = try dvui.testing.step(frame);
    _ = try dvui.testing.step(frame);
    defer dvui.debug.clearCaptures(std.testing.allocator);

    return lint.snapshot(std.testing.allocator, scale);
}

/// The composer's own widgets, found by structure rather than by line number so
/// the tests survive an edit to the file they are about.
const Parts = struct {
    frame: lint.Node,
    row: lint.Node,
    /// The row's children, in order: attach, entry wrap, send/stop.
    kids: [3]lint.Node,
    frame_slot: usize,
};

fn partsOf(nodes: []const lint.Node) !Parts {
    // The frame is the only widget the composer fills a background with.
    var frame_index: ?usize = null;
    for (nodes, 0..) |node, index| {
        if (!std.mem.eql(u8, node.src_file, "composer.zig")) continue;
        if (!node.background) continue;
        frame_index = index;
        break;
    }
    const frame_slot = frame_index orelse return error.FrameNotFound;

    // The row is the frame's only child.
    var row_index: ?usize = null;
    for (nodes, 0..) |node, index| {
        const slot = node.parent orelse continue;
        if (slot == frame_slot) {
            row_index = index;
            break;
        }
    }
    const row_slot = row_index orelse return error.RowNotFound;

    var kids: [3]lint.Node = undefined;
    var found: usize = 0;
    for (nodes) |node| {
        const slot = node.parent orelse continue;
        if (slot != row_slot) continue;
        if (found == 3) return error.TooManyRowChildren;
        kids[found] = node;
        found += 1;
    }
    if (found != 3) return error.WrongRowChildCount;

    return .{ .frame = nodes[frame_slot], .row = nodes[row_slot], .kids = kids, .frame_slot = frame_slot };
}

fn isWhole(value: f32) bool {
    return @abs(value - @round(value)) < 0.02;
}

// ─── the shape ───────────────────────────────────────────────────────────────

test "a single-line composer is one control height plus its padding" {
    setText("");
    for (scales) |scale| {
        const nodes = try snapshotAt(scale, .{ .w = 420, .h = 160 });
        defer std.testing.allocator.free(nodes);
        const parts = try partsOf(nodes);

        const metrics = ds.chat.composerMetrics(scale);
        try std.testing.expectApproxEqAbs(metrics.single_line_height, parts.frame.border.h, 0.05);
        // …and that height is a whole number of physical pixels.
        try std.testing.expect(isWhole(parts.frame.physical.h));
        try std.testing.expect(isWhole(parts.frame.physical.x));
        try std.testing.expect(isWhole(parts.frame.physical.y));
    }
}

test "the composer's three controls share a top and a bottom edge on one line" {
    setText("");
    for (scales) |scale| {
        const nodes = try snapshotAt(scale, .{ .w = 420, .h = 160 });
        defer std.testing.allocator.free(nodes);
        const parts = try partsOf(nodes);

        for (parts.kids) |kid| {
            try std.testing.expectApproxEqAbs(parts.kids[0].border.y, kid.border.y, 0.5);
            try std.testing.expectApproxEqAbs(
                parts.kids[0].border.y + parts.kids[0].border.h,
                kid.border.y + kid.border.h,
                0.5,
            );
            // Every one of them is the row's single control height.
            try std.testing.expectApproxEqAbs(ds.tokens.current.chrome_control_height, kid.border.h, 0.5);
        }
    }
}

test "the composer's controls stay bottom-aligned once the entry grows" {
    setText("one\ntwo\nthree");
    defer setText("");
    for (scales) |scale| {
        const nodes = try snapshotAt(scale, .{ .w = 420, .h = 220 });
        defer std.testing.allocator.free(nodes);
        const parts = try partsOf(nodes);

        const row_bottom = parts.row.border.y + parts.row.border.h;
        for (parts.kids, 0..) |kid, index| {
            const bottom = kid.border.y + kid.border.h;
            try std.testing.expectApproxEqAbs(row_bottom, bottom, 0.6);
            // The entry is the tall one; the buttons keep the control height.
            if (index != 1) try std.testing.expectApproxEqAbs(ds.tokens.current.chrome_control_height, kid.border.h, 0.5);
        }
        // Three rows of text, so the frame is taller than the single-line one.
        const metrics = ds.chat.composerMetrics(scale);
        try std.testing.expect(parts.frame.border.h > metrics.single_line_height + metrics.entry_row);
    }
}

test "the attach button's glyph is centred in it" {
    setText("");
    for (scales) |scale| {
        const nodes = try snapshotAt(scale, .{ .w = 420, .h = 160 });
        defer std.testing.allocator.free(nodes);
        const parts = try partsOf(nodes);
        const attach = parts.kids[0];

        // The glyph is the button's only descendant leaf.
        var glyph: ?lint.Node = null;
        for (nodes) |node| {
            const slot = node.parent orelse continue;
            if (nodes[slot].id != attach.id) continue;
            glyph = node;
        }
        const icon = glyph orelse return error.GlyphNotFound;
        const left = icon.border.x - attach.border.x;
        const right = (attach.border.x + attach.border.w) - (icon.border.x + icon.border.w);
        const top = icon.border.y - attach.border.y;
        const bottom = (attach.border.y + attach.border.h) - (icon.border.y + icon.border.h);
        try std.testing.expectApproxEqAbs(left, right, 0.5);
        try std.testing.expectApproxEqAbs(top, bottom, 0.5);
    }
}

// ─── the numbers, without a window ───────────────────────────────────────────

test "composer metrics are whole physical pixels at 1.0, 1.75 and 2.0" {
    for (scales) |scale| {
        const metrics = ds.chat.composerMetrics(scale);
        try std.testing.expect(ds.isSnapped(metrics.single_line_height, scale));
        try std.testing.expect(ds.isSnapped(metrics.control_height, scale));
        try std.testing.expect(ds.isSnapped(metrics.frame_padding, scale));
        try std.testing.expect(ds.isSnapped(metrics.entry_padding_y, scale));
        try std.testing.expect(ds.isSnapped(metrics.entry_row, scale));
        // The frame is exactly one control plus its own padding and border.
        try std.testing.expectApproxEqAbs(
            metrics.single_line_height,
            metrics.control_height + 2 * (metrics.frame_padding + metrics.border),
            0.0001,
        );
        // …and that comes out at the 44 logical px the design asks for.
        try std.testing.expectApproxEqAbs(@as(f32, 44), metrics.single_line_height, 0.51);
    }
}

test "the composer's text is the same font as a chat message body" {
    // The composer is where a message is written; it must not read at a
    // different size from the messages above it.
    var t = try dvui.testing.init(.{
        .window_size = .{ .w = 200, .h = 100 },
        .window_init_opts = .{ .theme = ds.tokens.dvuiTheme() },
    });
    defer t.deinit();
    const Local = struct {
        fn once() !dvui.App.Result {
            const body = ds.font(ds.tokens.current.font_size_md);
            const entry = ds.chat.composerFont();
            try std.testing.expectApproxEqAbs(body.lineHeight(), entry.lineHeight(), 0.0001);
            try std.testing.expectEqual(body.size, entry.size);
            return .ok;
        }
    };
    _ = try dvui.testing.step(Local.once);
}
