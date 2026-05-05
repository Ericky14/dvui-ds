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
    const t = tokens.current;
    return .{
        .color_fill = t.bg_elevated,
        .background = true,
        .padding = .{ .x = t.space_xs, .y = t.space_3xs, .w = t.space_xs, .h = t.space_3xs },
        .border = .{ .x = 0, .y = 0, .w = 0, .h = 1 },
        .color_border = t.border_normal,
        .expand = .horizontal,
    };
}
