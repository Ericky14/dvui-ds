/// Panel — wraps dvui.box() with panel presets.
///
/// Usage:
///   var p = ds.panel(@src()).draw();
///   defer p.deinit();
///   var hdr = ds.panelHeader(@src()).draw();
///   defer hdr.deinit();
const std = @import("std");
const dvui = @import("dvui");
const ds = @import("../ds.zig");
const tokens = @import("../tokens.zig");

pub fn panel(src: std.builtin.SourceLocation) Panel {
    return .{ .src = src };
}

pub fn panelHeader(src: std.builtin.SourceLocation) PanelHeader {
    return .{ .src = src };
}

pub const Panel = struct {
    src: std.builtin.SourceLocation,

    pub fn draw(self: Panel) *dvui.BoxWidget {
        return dvui.box(self.src, .{}, bodyOpts());
    }
};

pub const PanelHeader = struct {
    src: std.builtin.SourceLocation,

    pub fn draw(self: PanelHeader) *dvui.BoxWidget {
        return dvui.box(self.src, .{ .dir = .horizontal }, headerOpts());
    }
};

fn headerOpts() dvui.Options {
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

fn bodyOpts() dvui.Options {
    const theme = tokens.current;
    return .{
        .color_fill = .{ .color = theme.surface_1 },
        .color_border = .{ .color = theme.border },
        .border = dvui.Rect.all(theme.border_width),
        .padding = dvui.Rect.all(0),
        .expand = .both,
    };
}
