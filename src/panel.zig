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

fn bodyOpts() dvui.Options {
    const t = tokens.current;
    return .{
        .color_fill = t.bg_surface,
        .color_border = t.border_normal,
        .border = dvui.Rect.all(1),
        .padding = dvui.Rect.all(0),
        .expand = .both,
    };
}
