/// Icon — themed icon display (non-interactive).
///
/// Usage:
///   ds.icon(@src(), "outliner", icons.outliner).draw();
///   ds.icon(@src(), "camera", icons.camera).style(.accent).size(.md).draw();
const std = @import("std");
const dvui = @import("dvui");
const tokens = @import("tokens.zig");

pub const IconStyle = enum { primary, secondary, muted, accent, danger };

pub fn icon(src: std.builtin.SourceLocation, name: [:0]const u8, tvg_bytes: []const u8) Icon {
    return .{ .src = src, .name = name, .tvg_bytes = tvg_bytes };
}

pub const Icon = struct {
    src: std.builtin.SourceLocation,
    name: [:0]const u8,
    tvg_bytes: []const u8,
    is: IconStyle = .muted,
    s: tokens.Size = .sm,

    pub fn style(self: Icon, is: IconStyle) Icon {
        var i = self;
        i.is = is;
        return i;
    }

    pub fn size(self: Icon, s: tokens.Size) Icon {
        var i = self;
        i.s = s;
        return i;
    }

    pub fn draw(self: Icon) void {
        const t = tokens.current;
        const color = switch (self.is) {
            .primary => t.text_primary,
            .secondary => t.text_secondary,
            .muted => t.text_muted,
            .accent => t.accent,
            .danger => t.danger,
        };
        const sz = tokens.iconSize(self.s);
        dvui.icon(self.src, self.name, self.tvg_bytes, .{
            .fill_color = color,
            .stroke_color = color,
        }, .{
            .min_size_content = .{ .w = sz, .h = sz },
        });
    }
};
