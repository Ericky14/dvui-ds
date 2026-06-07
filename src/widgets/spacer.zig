/// Spacers — flexible (push-apart) and fixed whitespace.
///
/// Usage:
///   ds.spacer(@src());                              // flexible: pushes siblings apart
///   ds.gap(@src(), ds.tokens.current.space_md);     // fixed vertical gap
///   ds.gapH(@src(), ds.tokens.current.space_lg);    // fixed horizontal gap
const std = @import("std");
const dvui = @import("dvui");

/// Flexible spacer — expands to fill the leftover space along the parent's axis,
/// pushing the following siblings to the far end (right in a row, bottom in a
/// column).
pub fn spacer(src: std.builtin.SourceLocation) void {
    _ = dvui.spacer(src, .{ .expand = .both });
}

/// Add vertical whitespace of `height` pixels.
pub fn gap(src: std.builtin.SourceLocation, height: f32) void {
    _ = dvui.spacer(src, .{ .min_size_content = .{ .w = 0, .h = height } });
}

/// Add horizontal whitespace of `width` pixels.
pub fn gapH(src: std.builtin.SourceLocation, width: f32) void {
    _ = dvui.spacer(src, .{ .min_size_content = .{ .w = width, .h = 0 } });
}
