/// Toolbar — horizontal bar for tool buttons.
///
/// Usage:
///   var tb = ds.toolbar(@src()).draw();
///   defer tb.deinit();
const std = @import("std");
const dvui = @import("dvui");
const ds = @import("../ds.zig");
const tokens = @import("../tokens.zig");

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
        .color_fill = .{ .color = theme.surface_2 },
        .background = true,
        .padding = ds.paddingXY(theme.space_xs, theme.space_3xs),
        .border = ds.paddingEach(0, 0, theme.border_width, 0),
        .color_border = .{ .color = theme.border },
        .expand = .horizontal,
    };
}
