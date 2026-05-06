/// Menu Bar — wraps dvui.menu() with themed defaults.
///
/// Usage:
///   var bar = ds.menuBar(@src()).draw();
///   defer bar.deinit();
const std = @import("std");
const dvui = @import("dvui");
const ds = @import("../ds.zig");
const tokens = @import("../tokens.zig");

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
        .color_fill = theme.surface_2,
        .background = true,
        .padding = ds.paddingXY(theme.space_xs, theme.space_3xs),
        .border = ds.paddingEach(0, 0, theme.border_width, 0),
        .color_border = theme.border_subtle,
    };
}
