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
        return dvui.menu(self.src, .horizontal, opts());
    }
};

fn opts() dvui.Options {
    const theme = tokens.current;
    return .{
        .expand = .horizontal,
        .color_fill = theme.bg_elevated,
        .background = true,
        .padding = .{ .x = theme.space_xs, .y = theme.space_3xs, .w = theme.space_xs, .h = theme.space_3xs },
        .border = .{ .x = 0, .y = 0, .w = 0, .h = 1 },
        .color_border = theme.border_subtle,
    };
}
