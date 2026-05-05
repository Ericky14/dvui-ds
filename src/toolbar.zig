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
        return dvui.box(self.src, .{ .dir = .horizontal }, opts());
    }
};

fn opts() dvui.Options {
    const theme = tokens.current;
    return .{
        .color_fill = theme.bg_elevated,
        .background = true,
        .padding = .{ .x = theme.space_xs, .y = theme.space_3xs, .w = theme.space_xs, .h = theme.space_3xs },
        .border = .{ .x = 0, .y = 0, .w = 0, .h = 1 },
        .color_border = theme.border_normal,
        .expand = .horizontal,
    };
}
