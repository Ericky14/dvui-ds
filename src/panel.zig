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
        return dvui.box(self.src, .{}, tokens.panelBodyOpts());
    }
};

pub const PanelHeader = struct {
    src: std.builtin.SourceLocation,

    pub fn draw(self: PanelHeader) *dvui.BoxWidget {
        return dvui.box(self.src, .{ .dir = .horizontal }, tokens.panelHeaderOpts());
    }
};
