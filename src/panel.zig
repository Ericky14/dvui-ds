/// Panel — wraps dvui.box() with panel presets.
///
/// Usage:
///   var p = ds.panel(@src()).draw();
///   defer p.deinit();
///   var hdr = ds.panelHeader(@src()).draw();
///   defer hdr.deinit();
const std = @import("std");
const dvui = @import("dvui");
const tokens = @import("tokens.zig");

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
        .color_fill = theme.bg_elevated,
        .background = true,
        .padding = .{ .x = theme.space_xs, .y = theme.space_3xs, .w = theme.space_xs, .h = theme.space_3xs },
        .border = .{ .x = 0, .y = 0, .w = 0, .h = 1 },
        .color_border = theme.border_normal,
        .expand = .horizontal,
    };
}

fn bodyOpts() dvui.Options {
    const theme = tokens.current;
    return .{
        .color_fill = theme.bg_surface,
        .color_border = theme.border_normal,
        .border = dvui.Rect.all(1),
        .padding = dvui.Rect.all(0),
        .expand = .both,
    };
}
