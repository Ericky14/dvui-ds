/// Column — vertical layout container with themed defaults.
///
/// Usage:
///   var c = ds.column(@src()).gap(theme.space_md).draw();
///   defer c.deinit();
///   // ... child widgets ...
const std = @import("std");
const dvui = @import("dvui");
const tokens = @import("../tokens.zig");

pub fn column(src: std.builtin.SourceLocation) Column {
    return .{ .src = src };
}

pub const Column = struct {
    src: std.builtin.SourceLocation,
    gap_val: f32 = 0,
    do_expand: ?dvui.Options.Expand = null,
    do_padding: ?dvui.Rect = null,

    /// Set gap between children in pixels.
    /// Pass a token value: `column.gap(theme.space_md)`
    pub fn gap(self: Column, px: f32) Column {
        var c = self;
        c.gap_val = px;
        return c;
    }

    /// Expand to fill available space.
    pub fn expand(self: Column, val: dvui.Options.Expand) Column {
        var c = self;
        c.do_expand = val;
        return c;
    }

    /// Set uniform padding in pixels.
    /// Pass a token value: `column.padding(theme.space_sm)`
    pub fn padding(self: Column, px: f32) Column {
        var c = self;
        c.do_padding = dvui.Rect.all(px);
        return c;
    }

    /// Set custom padding rect.
    pub fn paddingRect(self: Column, val: dvui.Rect) Column {
        var c = self;
        c.do_padding = val;
        return c;
    }

    /// Materialize the column container. Call `deinit()` on the result when done.
    pub fn draw(self: Column) *dvui.BoxWidget {
        const theme = tokens.current;
        return dvui.box(self.src, .{ .dir = .vertical, .gap = self.gap_val }, .{
            .expand = self.do_expand,
            .padding = self.do_padding,
            .background = false,
            .color_fill = .{ .color = theme.surface_0 },
        });
    }
};
