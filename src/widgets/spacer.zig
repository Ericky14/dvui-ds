/// Gap — adds vertical or horizontal whitespace.
///
/// Usage:
///   ds.gap(@src(), ds.tokens.current.space_md);   // vertical gap
///   ds.gapH(@src(), ds.tokens.current.space_lg);   // horizontal gap
const std = @import("std");
const dvui = @import("dvui");

/// Add vertical whitespace of `height` pixels.
pub fn gap(src: std.builtin.SourceLocation, height: f32) void {
    _ = dvui.spacer(src, .{ .min_size_content = .{ .w = 0, .h = height } });
}

/// Add horizontal whitespace of `width` pixels.
pub fn gapH(src: std.builtin.SourceLocation, width: f32) void {
    _ = dvui.spacer(src, .{ .min_size_content = .{ .w = width, .h = 0 } });
}
