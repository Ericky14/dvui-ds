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
    const t = tokens.current;
    return .{
        .expand = .horizontal,
        .color_fill = t.bg_elevated,
        .background = true,
        .padding = .{ .x = t.space_xs, .y = t.space_3xs, .w = t.space_xs, .h = t.space_3xs },
        .border = .{ .x = 0, .y = 0, .w = 0, .h = 1 },
        .color_border = t.border_subtle,
    };
}
