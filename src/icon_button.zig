/// Icon Button — comptime builder wrapping dvui.buttonIcon().
///
/// Usage:
///   if (ds.iconButton(@src(), "close", icons.close).variant(.danger).draw()) { ... }
///   if (ds.iconButton(@src(), "minimize", icons.minimize).draw()) { ... }
const std = @import("std");
const dvui = @import("dvui");
const tokens = @import("tokens.zig");
const button_mod = @import("button.zig");

pub fn iconButton(src: std.builtin.SourceLocation, name: [:0]const u8, tvg_bytes: []const u8) IconButton {
    return .{ .src = src, .name = name, .tvg_bytes = tvg_bytes };
}

pub const IconButton = struct {
    src: std.builtin.SourceLocation,
    name: [:0]const u8,
    tvg_bytes: []const u8,
    v: tokens.Variant = .ghost,
    s: tokens.Size = .sm,

    pub fn variant(self: IconButton, v: tokens.Variant) IconButton {
        var b = self;
        b.v = v;
        return b;
    }

    pub fn size(self: IconButton, s: tokens.Size) IconButton {
        var b = self;
        b.s = s;
        return b;
    }

    pub fn draw(self: IconButton) bool {
        const colors = iconColors(self.v);
        const icon_sz = tokens.iconSize(self.s);
        return dvui.buttonIcon(
            self.src,
            self.name,
            self.tvg_bytes,
            .{},
            .{ .fill_color = colors.fill, .stroke_color = colors.stroke },
            button_mod.opts(self.v, self.s).override(.{
                .min_size_content = .{ .w = icon_sz, .h = icon_sz },
            }),
        );
    }
};

fn iconColors(v: tokens.Variant) struct { fill: tokens.Color, stroke: tokens.Color } {
    const t = tokens.current;
    return switch (v) {
        .filled => .{ .fill = t.text_primary, .stroke = t.text_primary },
        .outlined => .{ .fill = t.text_secondary, .stroke = t.text_secondary },
        .ghost => .{ .fill = t.text_secondary, .stroke = t.text_secondary },
        .danger => .{ .fill = t.danger, .stroke = t.danger },
    };
}
