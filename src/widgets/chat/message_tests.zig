/// Tests for the message builder and its styling resolvers.
const std = @import("std");
const dvui = @import("dvui");
const widget = @import("message.zig");
const tokens = @import("../../tokens.zig");

test "message builder defaults: not streaming, markdown on, id_extra 0" {
    const msg = widget.message(@src(), .assistant, "hi");
    try std.testing.expectEqual(widget.Role.assistant, msg.role);
    try std.testing.expectEqualStrings("hi", msg.text);
    try std.testing.expect(!msg.is_streaming);
    try std.testing.expect(msg.render_markdown);
    try std.testing.expectEqual(@as(usize, 0), msg.id_extra);
}

test "message setters copy on set" {
    const base = widget.message(@src(), .user, "x");
    const styled = base.streaming(true).markdown(false).idExtra(5);
    try std.testing.expect(!base.is_streaming);
    try std.testing.expect(base.render_markdown);
    try std.testing.expectEqual(@as(usize, 0), base.id_extra);
    try std.testing.expect(styled.is_streaming);
    try std.testing.expect(!styled.render_markdown);
    try std.testing.expectEqual(@as(usize, 5), styled.id_extra);
}

test "maxWidth: 88% for user, 92% for assistant, unbounded before the row has a width" {
    try std.testing.expectApproxEqAbs(@as(f32, 352), widget.maxWidth(400, .user), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 368), widget.maxWidth(400, .assistant), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 400), widget.maxWidth(400, .system), 0.001);
    try std.testing.expectApproxEqAbs(dvui.max_float_safe, widget.maxWidth(0, .user), 0.001);
}

test "userCorners: round(radius_sm) with a 2px bottom-right tail" {
    const corners = widget.userCorners();
    try std.testing.expectEqual(dvui.Corner.Style.round, corners.tl.kind);
    try std.testing.expectApproxEqAbs(tokens.current.radius_sm, corners.tl.rx, 0.001);
    try std.testing.expectApproxEqAbs(tokens.current.radius_sm, corners.tr.rx, 0.001);
    try std.testing.expectApproxEqAbs(tokens.current.radius_sm, corners.bl.rx, 0.001);
    try std.testing.expectEqual(dvui.Corner.Style.round, corners.br.kind);
    try std.testing.expectApproxEqAbs(@as(f32, 2), corners.br.rx, 0.001);
}

test "blockOpts user: right-aligned surface_2 bubble whose outer width is capped at max_width" {
    const theme = tokens.current;
    const opts = widget.blockOpts(.user, 300, 0);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), opts.gravity_x.?, 0.001);
    try std.testing.expect(opts.background.?);
    try std.testing.expectEqual(theme.surface_2, opts.color_fill.?.toColor());
    // Content cap = outer cap minus the bubble's horizontal padding.
    try std.testing.expectApproxEqAbs(300 - 2 * theme.space_md, opts.max_size_content.?.w, 0.001);
    try std.testing.expectApproxEqAbs(theme.space_md, opts.padding.?.x, 0.001);
    try std.testing.expectApproxEqAbs(theme.space_sm, opts.padding.?.y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 2), opts.corners.?.br.rx, 0.001);
}

test "blockOpts assistant: left-aligned, no bubble, capped at max_width" {
    const opts = widget.blockOpts(.assistant, 368, 0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), opts.gravity_x.?, 0.001);
    try std.testing.expect(!opts.background.?);
    try std.testing.expectApproxEqAbs(@as(f32, 368), opts.max_size_content.?.w, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0), opts.padding.?.x, 0.001);
}

test "blockOpts carries the streaming min height as content height" {
    const opts = widget.blockOpts(.assistant, 368, 42);
    try std.testing.expectApproxEqAbs(@as(f32, 42), opts.min_size_content.?.h, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0), opts.min_size_content.?.w, 0.001);
    try std.testing.expectApproxEqAbs(dvui.max_float_safe, opts.max_size_content.?.h, 0.001);
}

test "systemOpts: centred, small, muted" {
    const theme = tokens.current;
    const opts = widget.systemOpts();
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), opts.gravity_x.?, 0.001);
    try std.testing.expectEqual(theme.text_muted, opts.color_text.?.toColor());
    try std.testing.expectEqual(@as(f32, @floatFromInt(theme.font_size_sm)), opts.font.?.size);
}

test "outerOpts: a full-width row keyed by id_extra" {
    const opts = widget.message(@src(), .user, "x").idExtra(3).outerOpts();
    try std.testing.expectEqual(dvui.Options.Expand.horizontal, opts.expand.?);
    try std.testing.expectEqual(@as(?usize, 3), opts.id_extra);
}
