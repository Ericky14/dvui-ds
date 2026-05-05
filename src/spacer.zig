/// Spacer — expands to fill available horizontal space.
///
/// Usage:
///   ds.spacer(@src());
const std = @import("std");
const dvui = @import("dvui");

pub fn spacer(src: std.builtin.SourceLocation) void {
    var s = dvui.box(src, .{}, .{ .expand = .horizontal });
    s.deinit();
}
