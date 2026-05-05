/// Button — unified builder wrapping dvui button APIs.
///
/// Usage:
///   if (ds.button(@src(), "Save").variant(.filled).size(.lg).draw()) { ... }
///   if (ds.button(@src(), "").icon("close", bytes).draw()) { ... }
///   if (ds.button(@src(), "Save").icon("save", bytes).iconFirst().draw()) { ... }
const std = @import("std");
const dvui = @import("dvui");
const tokens = @import("tokens.zig");
const icon_mod = @import("icon.zig");

pub fn button(src: std.builtin.SourceLocation, label_str: []const u8) Button {
    return .{ .src = src, .label_str = label_str };
}

pub const Button = struct {
    src: std.builtin.SourceLocation,
    label_str: []const u8,
    btn_variant: tokens.Variant = .ghost,
    btn_size: tokens.Size = .sm,
    icon_name: ?[:0]const u8 = null,
    icon_bytes: ?[]const u8 = null,
    icon_first_flag: bool = false,

    pub fn variant(self: Button, val: tokens.Variant) Button {
        var btn = self;
        btn.btn_variant = val;
        return btn;
    }

    pub fn size(self: Button, val: tokens.Size) Button {
        var btn = self;
        btn.btn_size = val;
        return btn;
    }

    pub fn icon(self: Button, name: [:0]const u8, tvg_bytes: []const u8) Button {
        var btn = self;
        btn.icon_name = name;
        btn.icon_bytes = tvg_bytes;
        return btn;
    }

    pub fn iconFirst(self: Button) Button {
        var btn = self;
        btn.icon_first_flag = true;
        return btn;
    }

    pub fn draw(self: Button) bool {
        const options = opts(self.btn_variant, self.btn_size);

        if (self.icon_bytes) |tvg_bytes| {
            const name = self.icon_name orelse "";
            if (self.label_str.len == 0) {
                // Icon-only button
                const colors = iconColors(self.btn_variant);
                const icon_sz = icon_mod.iconSize(self.btn_size);
                return dvui.buttonIcon(
                    self.src,
                    name,
                    tvg_bytes,
                    .{},
                    .{ .fill_color = colors.fill, .stroke_color = colors.stroke },
                    options.override(.{ .min_size_content = .{ .w = icon_sz, .h = icon_sz } }),
                );
            } else {
                // Icon + text button
                return dvui.buttonLabelAndIcon(self.src, .{
                    .button_opts = .{},
                    .label = self.label_str,
                    .tvg_bytes = tvg_bytes,
                    .icon_first = self.icon_first_flag,
                }, options);
            }
        } else {
            // Text-only button
            return dvui.button(self.src, self.label_str, .{}, options);
        }
    }
};

pub fn opts(btn_variant: tokens.Variant, btn_size: tokens.Size) dvui.Options {
    const theme = tokens.current;
    const padding = switch (btn_size) {
        .sm => dvui.Rect{ .x = theme.space_xs, .y = theme.space_3xs, .w = theme.space_xs, .h = theme.space_3xs },
        .md => dvui.Rect{ .x = theme.space_sm, .y = theme.space_xs, .w = theme.space_sm, .h = theme.space_xs },
        .lg => dvui.Rect{ .x = theme.space_md, .y = theme.space_sm, .w = theme.space_md, .h = theme.space_sm },
    };

    return switch (btn_variant) {
        .filled => .{
            .color_fill = theme.accent,
            .color_fill_hover = theme.accent_hover,
            .color_fill_press = theme.accent_press,
            .color_text = theme.text_primary,
            .color_border = theme.accent,
            .corner_radius = dvui.Rect.all(theme.radius_md),
            .border = dvui.Rect.all(0),
            .padding = padding,
        },
        .outlined => .{
            .color_fill = theme.bg_elevated,
            .color_fill_hover = theme.fill_subtle,
            .color_fill_press = theme.neutral_press,
            .color_text = theme.text_primary,
            .color_border = theme.border_normal,
            .corner_radius = dvui.Rect.all(theme.radius_md),
            .border = dvui.Rect.all(1),
            .padding = padding,
        },
        .ghost => .{
            .color_fill = .fromHex("#00000000"),
            .color_fill_hover = theme.neutral_hover,
            .color_fill_press = theme.neutral_press,
            .color_text = theme.text_secondary,
            .corner_radius = dvui.Rect.all(theme.radius_sm),
            .border = dvui.Rect.all(0),
            .padding = padding,
        },
        .danger => .{
            .color_fill = .fromHex("#00000000"),
            .color_fill_hover = theme.danger_dim,
            .color_fill_press = theme.danger,
            .color_text = theme.danger,
            .corner_radius = dvui.Rect.all(theme.radius_sm),
            .border = dvui.Rect.all(0),
            .padding = padding,
        },
    };
}

fn iconColors(btn_variant: tokens.Variant) struct { fill: tokens.Color, stroke: tokens.Color } {
    const theme = tokens.current;
    return switch (btn_variant) {
        .filled => .{ .fill = theme.text_primary, .stroke = theme.text_primary },
        .outlined => .{ .fill = theme.text_secondary, .stroke = theme.text_secondary },
        .ghost => .{ .fill = theme.text_secondary, .stroke = theme.text_secondary },
        .danger => .{ .fill = theme.danger, .stroke = theme.danger },
    };
}
