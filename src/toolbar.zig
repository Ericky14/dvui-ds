/// Toolbar — horizontal bar for tool buttons.
///
/// Usage:
///   var tb = ds.toolbar(@src()).draw();
///   defer tb.deinit();
const std = @import("std");
const dvui = @import("dvui");
const tokens = @import("tokens.zig");

pub fn toolbar(src: std.builtin.SourceLocation) Toolbar {
    return .{ .src = src };
}

pub const Toolbar = struct {
    src: std.builtin.SourceLocation,

    pub fn draw(self: Toolbar) *dvui.BoxWidget {
        return dvui.box(self.src, .{ .dir = .horizontal }, tokens.toolbarOpts());
    }
};
