/// Button — unified builder wrapping dvui button APIs.
///
/// Usage:
///   if (ds.button(@src(), "Save").variant(.filled).size(.lg).draw()) { ... }
///   if (ds.button(@src(), "").source(Source.tvg("close", bytes)).draw()) { ... }
///   if (ds.button(@src(), "Save").source(Source.tvg("save", bytes)).iconFirst().draw()) { ... }
///   if (ds.button(@src(), "").source(Source.imageBytes(png_data)).draw()) { ... }
const std = @import("std");
const dvui = @import("dvui");
const tokens = @import("tokens.zig");
const icon_mod = @import("icon.zig");
pub const Source = @import("source.zig");

pub fn button(src: std.builtin.SourceLocation, label_str: []const u8) Button {
    return .{ .src = src, .label_str = label_str };
}

pub const Button = struct {
    src: std.builtin.SourceLocation,
    label_str: []const u8,
    btn_variant: tokens.Variant = .ghost,
    btn_size: tokens.Size = .sm,
    btn_source: ?Source = null,
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

    /// Set the visual source (TVG icon, raster image, etc.)
    pub fn source(self: Button, val: Source) Button {
        var btn = self;
        btn.btn_source = val;
        return btn;
    }

    /// Convenience: set a TVG icon source by name and bytes.
    pub fn icon(self: Button, name: [:0]const u8, tvg_bytes: []const u8) Button {
        return self.source(Source.tvg(name, tvg_bytes));
    }

    pub fn iconFirst(self: Button) Button {
        var btn = self;
        btn.icon_first_flag = true;
        return btn;
    }

    pub fn draw(self: Button) bool {
        const options = opts(self.btn_variant, self.btn_size);

        if (self.btn_source) |asset| {
            switch (asset.kind) {
                .tvg => |tvg| {
                    if (self.label_str.len == 0) {
                        // Icon-only button (TVG)
                        const colors = iconColors(self.btn_variant);
                        const icon_sz = icon_mod.iconSize(self.btn_size);
                        return dvui.buttonIcon(
                            self.src,
                            tvg.name,
                            tvg.bytes,
                            .{},
                            .{ .fill_color = colors.fill, .stroke_color = colors.stroke },
                            options.override(.{ .min_size_content = .{ .w = icon_sz, .h = icon_sz } }),
                        );
                    } else {
                        // Icon + text button (TVG)
                        return dvui.buttonLabelAndIcon(self.src, .{
                            .button_opts = .{},
                            .label = self.label_str,
                            .tvg_bytes = tvg.bytes,
                            .icon_first = self.icon_first_flag,
                        }, options);
                    }
                },
                .image => |image_source| {
                    // Raster image button — composite: ButtonWidget + dvui.image()
                    return self.drawImageButton(image_source, options);
                },
            }
        } else {
            // Text-only button
            return dvui.button(self.src, self.label_str, .{}, options);
        }
    }

    fn drawImageButton(self: Button, image_source: dvui.ImageSource, options: dvui.Options) bool {
        const icon_sz = icon_mod.iconSize(self.btn_size);
        var bw: dvui.ButtonWidget = undefined;
        bw.init(self.src, .{}, options);
        bw.processEvents();
        bw.drawBackground();

        if (self.label_str.len > 0 and self.icon_first_flag) {
            _ = dvui.image(@src(), .{ .source = image_source }, .{
                .min_size_content = .{ .w = icon_sz, .h = icon_sz },
            });
            dvui.labelEx(@src(), "{s}", .{self.label_str}, .{}, .{});
        } else if (self.label_str.len > 0) {
            dvui.labelEx(@src(), "{s}", .{self.label_str}, .{}, .{});
            _ = dvui.image(@src(), .{ .source = image_source }, .{
                .min_size_content = .{ .w = icon_sz, .h = icon_sz },
            });
        } else {
            _ = dvui.image(@src(), .{ .source = image_source }, .{
                .min_size_content = .{ .w = icon_sz, .h = icon_sz },
            });
        }

        const click = bw.clicked();
        bw.drawFocus();
        bw.deinit();
        return click;
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
