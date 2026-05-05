/// Button — comptime builder wrapping dvui.button().
///
/// Usage:
///   if (ds.button(@src(), "Save").variant(.filled).size(.lg).draw()) { ... }
///   if (ds.button(@src(), "Cancel").draw()) { ... }  // defaults: ghost, sm
const std = @import("std");
const dvui = @import("dvui");
const tokens = @import("tokens.zig");

pub fn button(src: std.builtin.SourceLocation, label_str: []const u8) Button {
    return .{ .src = src, .label_str = label_str };
}

pub const Button = struct {
    src: std.builtin.SourceLocation,
    label_str: []const u8,
    v: tokens.Variant = .ghost,
    s: tokens.Size = .sm,

    pub fn variant(self: Button, v: tokens.Variant) Button {
        var b = self;
        b.v = v;
        return b;
    }

    pub fn size(self: Button, s: tokens.Size) Button {
        var b = self;
        b.s = s;
        return b;
    }

    pub fn draw(self: Button) bool {
        return dvui.button(self.src, self.label_str, .{}, opts(self.v, self.s));
    }
};

pub fn opts(v: tokens.Variant, size: tokens.Size) dvui.Options {
    const t = tokens.current;
    const padding = switch (size) {
        .sm => dvui.Rect{ .x = t.space_xs, .y = t.space_3xs, .w = t.space_xs, .h = t.space_3xs },
        .md => dvui.Rect{ .x = t.space_sm, .y = t.space_xs, .w = t.space_sm, .h = t.space_xs },
        .lg => dvui.Rect{ .x = t.space_md, .y = t.space_sm, .w = t.space_md, .h = t.space_sm },
    };

    return switch (v) {
        .filled => .{
            .color_fill = t.accent,
            .color_fill_hover = t.accent_hover,
            .color_fill_press = t.accent_press,
            .color_text = t.text_primary,
            .color_border = t.accent,
            .corner_radius = dvui.Rect.all(t.radius_md),
            .border = dvui.Rect.all(0),
            .padding = padding,
        },
        .outlined => .{
            .color_fill = t.bg_elevated,
            .color_fill_hover = t.fill_subtle,
            .color_fill_press = t.neutral_press,
            .color_text = t.text_primary,
            .color_border = t.border_normal,
            .corner_radius = dvui.Rect.all(t.radius_md),
            .border = dvui.Rect.all(1),
            .padding = padding,
        },
        .ghost => .{
            .color_fill = .fromHex("#00000000"),
            .color_fill_hover = t.neutral_hover,
            .color_fill_press = t.neutral_press,
            .color_text = t.text_secondary,
            .corner_radius = dvui.Rect.all(t.radius_sm),
            .border = dvui.Rect.all(0),
            .padding = padding,
        },
        .danger => .{
            .color_fill = .fromHex("#00000000"),
            .color_fill_hover = t.danger_dim,
            .color_fill_press = t.danger,
            .color_text = t.danger,
            .corner_radius = dvui.Rect.all(t.radius_sm),
            .border = dvui.Rect.all(0),
            .padding = padding,
        },
    };
}
