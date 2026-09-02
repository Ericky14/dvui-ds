/// Tests for the composer builder, its key handling and its styling resolvers.
const std = @import("std");
const dvui = @import("dvui");
const widget = @import("composer.zig");
const tokens = @import("../../tokens.zig");

test "composer builder defaults: placeholder, not busy, id_extra 0" {
    var buffer: [32]u8 = @splat(0);
    const box = widget.composer(@src(), &buffer);
    try std.testing.expectEqualStrings("Ask for anything...", box.placeholder_text);
    try std.testing.expect(!box.is_busy);
    try std.testing.expectEqual(@as(usize, 0), box.id_extra);
    try std.testing.expectEqual(@as(usize, 32), box.buffer.len);
}

test "composer setters copy on set" {
    var buffer: [32]u8 = @splat(0);
    const base = widget.composer(@src(), &buffer);
    const styled = base.placeholder("Say…").busy(true).idExtra(2);
    try std.testing.expectEqualStrings("Ask for anything...", base.placeholder_text);
    try std.testing.expect(!base.is_busy);
    try std.testing.expectEqualStrings("Say…", styled.placeholder_text);
    try std.testing.expect(styled.is_busy);
    try std.testing.expectEqual(@as(usize, 2), styled.id_extra);
}

test "keyIntent: Enter submits, Shift+Enter is a newline" {
    try std.testing.expectEqual(widget.KeyIntent.submit, widget.keyIntent(.enter, .none, false));
    try std.testing.expectEqual(widget.KeyIntent.submit, widget.keyIntent(.kp_enter, .none, true));
    try std.testing.expectEqual(widget.KeyIntent.newline, widget.keyIntent(.enter, .lshift, false));
    try std.testing.expectEqual(widget.KeyIntent.newline, widget.keyIntent(.enter, .rshift, true));
}

test "keyIntent: Esc interrupts only while busy, other keys are ignored" {
    try std.testing.expectEqual(widget.KeyIntent.interrupt, widget.keyIntent(.escape, .none, true));
    try std.testing.expectEqual(widget.KeyIntent.none, widget.keyIntent(.escape, .none, false));
    try std.testing.expectEqual(widget.KeyIntent.none, widget.keyIntent(.a, .none, true));
    try std.testing.expectEqual(widget.KeyIntent.none, widget.keyIntent(.tab, .lshift, true));
}

test "isBlank: whitespace and zero-terminated empty buffers are blank" {
    try std.testing.expect(widget.isBlank(""));
    try std.testing.expect(widget.isBlank("  \n\t "));
    var zeroed: [8]u8 = @splat(0);
    try std.testing.expect(widget.isBlank(&zeroed));
    zeroed[0] = ' ';
    try std.testing.expect(widget.isBlank(&zeroed));
    zeroed[1] = 'x';
    try std.testing.expect(!widget.isBlank(&zeroed));
    try std.testing.expect(!widget.isBlank("hello"));
}

test "frameOpts: surface_1 fill, round(radius_md), border_strong idle and accent when focused" {
    const theme = tokens.current;
    const idle = widget.frameOpts(false);
    try std.testing.expectEqual(theme.surface_1, idle.color_fill.?.toColor());
    try std.testing.expectEqual(theme.border_strong, idle.color_border.?.toColor());
    try std.testing.expectEqual(dvui.Corner.Style.round, idle.corners.?.tl.kind);
    try std.testing.expectApproxEqAbs(theme.radius_md, idle.corners.?.tl.rx, 0.001);
    try std.testing.expectApproxEqAbs(theme.border_width, idle.border.?.x, 0.001);
    try std.testing.expectEqual(dvui.Options.Expand.horizontal, idle.expand.?);

    const focused = widget.frameOpts(true);
    const ring = focused.color_border.?.toColor();
    try std.testing.expectEqual(theme.accent.r, ring.r);
    try std.testing.expectEqual(theme.accent.g, ring.g);
    try std.testing.expectEqual(theme.accent.b, ring.b);
    try std.testing.expect(ring.a < theme.accent.a);
}

test "entryOpts: grows from one to eight rows of the given font" {
    const font = dvui.Font{};
    const row: f32 = 15;
    const opts = widget.entryOpts(font, row);
    try std.testing.expectApproxEqAbs(row * widget.min_rows, opts.min_size_content.?.h, 0.001);
    try std.testing.expectApproxEqAbs(row * widget.max_rows, opts.max_size_content.?.h, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0), opts.min_size_content.?.w, 0.001);
    try std.testing.expectApproxEqAbs(dvui.max_float_safe, opts.max_size_content.?.w, 0.001);
    try std.testing.expect(!opts.background.?);
    try std.testing.expectEqual(tokens.current.text_primary, opts.color_text.?.toColor());
}

test "wrapOpts: pins min and max width to the natural width, height unbounded" {
    const opts = widget.wrapOpts(120);
    try std.testing.expectApproxEqAbs(@as(f32, 120), opts.min_size_content.?.w, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 120), opts.max_size_content.?.w, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0), opts.min_size_content.?.h, 0.001);
    try std.testing.expectApproxEqAbs(dvui.max_float_safe, opts.max_size_content.?.h, 0.001);
    try std.testing.expectEqual(dvui.Options.Expand.horizontal, opts.expand.?);
}

test "hintOpts: muted text in the given font, and the hint names all three keys" {
    const font = dvui.Font{};
    const opts = widget.hintOpts(font);
    try std.testing.expectEqual(tokens.current.text_muted, opts.color_text.?.toColor());
    try std.testing.expect(std.mem.find(u8, widget.hint_text, "enter") != null);
    try std.testing.expect(std.mem.find(u8, widget.hint_text, "shift+enter") != null);
    try std.testing.expect(std.mem.find(u8, widget.hint_text, "esc") != null);
}
