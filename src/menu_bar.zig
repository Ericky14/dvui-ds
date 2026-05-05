/// Menu Bar — wraps dvui.menu() with themed defaults.
///
/// Usage:
///   var bar = ds.menuBar(@src()).draw();
///   defer bar.deinit();
const std = @import("std");
const dvui = @import("dvui");
const tokens = @import("tokens.zig");

pub fn menuBar(src: std.builtin.SourceLocation) MenuBar {
    return .{ .src = src };
}

pub const MenuBar = struct {
    src: std.builtin.SourceLocation,

    pub fn draw(self: MenuBar) *dvui.MenuWidget {
        return dvui.menu(self.src, .horizontal, tokens.menuBarOpts());
    }
};
