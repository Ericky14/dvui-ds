/// Row — horizontal layout container with themed defaults.
///
/// Usage:
///   var r = ds.row(@src()).gap(theme.space_md).draw();
///   defer r.deinit();
///   // ... child widgets ...
const std = @import("std");
const dvui = @import("dvui");
const tokens = @import("../tokens.zig");

pub fn row(src: std.builtin.SourceLocation) Row {
    return .{ .src = src };
}

pub const Row = struct {
    src: std.builtin.SourceLocation,
    gap_val: f32 = 0,
    do_expand: ?dvui.Options.Expand = null,
    do_padding: ?dvui.Rect = null,

    /// Set gap between children in pixels.
    /// Pass a token value: `row.gap(theme.space_md)`
    pub fn gap(self: Row, px: f32) Row {
        var r = self;
        r.gap_val = px;
        return r;
    }

    /// Expand to fill available space.
    pub fn expand(self: Row, val: dvui.Options.Expand) Row {
        var r = self;
        r.do_expand = val;
        return r;
    }

    /// Set uniform padding in pixels.
    /// Pass a token value: `row.padding(theme.space_sm)`
    pub fn padding(self: Row, px: f32) Row {
        var r = self;
        r.do_padding = dvui.Rect.all(px);
        return r;
    }

    /// Set custom padding rect.
    pub fn paddingRect(self: Row, val: dvui.Rect) Row {
        var r = self;
        r.do_padding = val;
        return r;
    }

    /// Materialize the row container. Call `deinit()` on the result when done.
    pub fn draw(self: Row) *dvui.BoxWidget {
        const theme = tokens.current;
        return dvui.box(self.src, .{ .dir = .horizontal, .gap = self.gap_val }, .{
            .expand = self.do_expand,
            .padding = self.do_padding,
            .background = false,
            .color_fill = theme.surface_0,
        });
    }
};
