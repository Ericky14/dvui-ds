/// Tests for the codeBlock builder and its styling resolvers.
const std = @import("std");
const dvui = @import("dvui");
const widget = @import("code_block.zig");
const tokens = @import("../../tokens.zig");

test "codeBlock builder keeps its language and code, defaults to id_extra 0" {
    const block = widget.codeBlock(@src(), "lua", "print(1)");
    try std.testing.expectEqualStrings("lua", block.lang);
    try std.testing.expectEqualStrings("print(1)", block.code);
    try std.testing.expectEqual(@as(usize, 0), block.id_extra);
}

test "codeBlock idExtra copies on set" {
    const base = widget.codeBlock(@src(), "", "x");
    const keyed = base.idExtra(9);
    try std.testing.expectEqual(@as(usize, 0), base.id_extra);
    try std.testing.expectEqual(@as(usize, 9), keyed.id_extra);
}

test "frameOpts: surface_0 fill, border_subtle border, round(radius_md) corners, expands horizontally" {
    const theme = tokens.current;
    const opts = widget.codeBlock(@src(), "zig", "").idExtra(3).frameOpts();
    try std.testing.expectEqual(theme.surface_0, opts.color_fill.?.toColor());
    try std.testing.expectEqual(theme.border_subtle, opts.color_border.?.toColor());
    try std.testing.expectEqual(dvui.Corner.Style.round, opts.corners.?.tl.kind);
    try std.testing.expectApproxEqAbs(theme.radius_md, opts.corners.?.tl.rx, 0.001);
    try std.testing.expectApproxEqAbs(theme.radius_md, opts.corners.?.br.rx, 0.001);
    try std.testing.expectApproxEqAbs(theme.border_width, opts.border.?.x, 0.001);
    try std.testing.expectEqual(dvui.Options.Expand.horizontal, opts.expand.?);
    try std.testing.expectEqual(@as(?usize, 3), opts.id_extra);
    try std.testing.expect(opts.background.?);
}

test "langOpts: muted small caption centred on the header" {
    const theme = tokens.current;
    const opts = widget.langOpts();
    try std.testing.expectEqual(theme.text_muted, opts.color_text.?.toColor());
    try std.testing.expectEqual(@as(f32, @floatFromInt(theme.font_size_sm)), opts.font.?.size);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), opts.gravity_y.?, 0.001);
}

test "headerOpts: caption inset on the left, copy button flush right" {
    const theme = tokens.current;
    const opts = widget.headerOpts();
    try std.testing.expectEqual(dvui.Options.Expand.horizontal, opts.expand.?);
    try std.testing.expectApproxEqAbs(theme.space_md, opts.padding.?.x, 0.001);
    try std.testing.expectApproxEqAbs(theme.space_3xs, opts.padding.?.w, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0), opts.padding.?.h, 0.001);
}

test "bodyOpts: side padding matches the header inset" {
    const theme = tokens.current;
    const opts = widget.bodyOpts();
    try std.testing.expectApproxEqAbs(theme.space_md, opts.padding.?.x, 0.001);
    try std.testing.expectApproxEqAbs(theme.space_md, opts.padding.?.w, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0), opts.padding.?.y, 0.001);
    try std.testing.expectApproxEqAbs(theme.space_sm, opts.padding.?.h, 0.001);
}

test "bodyScrollOpts: transparent, expands horizontally" {
    const opts = widget.bodyScrollOpts();
    try std.testing.expect(!opts.background.?);
    try std.testing.expectEqual(dvui.Options.Expand.horizontal, opts.expand.?);
}

test "lineOpts: keyed by line index, primary text, no padding" {
    const theme = tokens.current;
    const font = dvui.Font{};
    const opts = widget.lineOpts(font, 7);
    try std.testing.expectEqual(@as(?usize, 7), opts.id_extra);
    try std.testing.expectEqual(theme.text_primary, opts.color_text.?.toColor());
    try std.testing.expectApproxEqAbs(@as(f32, 0), opts.padding.?.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0), opts.padding.?.h, 0.001);
}
