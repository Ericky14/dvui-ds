/// Button — unified builder wrapping dvui button APIs.
///
/// Usage:
///   if (ds.button(@src(), "Save").variant(.filled).size(.lg).draw()) { ... }
///   if (ds.button(@src(), "").icon("close", ds.icons.close).draw()) { ... }
///   if (ds.button(@src(), "Save").icon("save", ds.icons.save).iconFirst().draw()) { ... }
///   if (ds.button(@src(), "").source(Source.imageBytes(png_data)).draw()) { ... }
///   _ = ds.button(@src(), "Save").variant(.filled).disabled(true).draw();
///   _ = ds.button(@src(), "Saving").variant(.filled).loading(true).draw();
const std = @import("std");
const dvui = @import("dvui");
const ds = @import("../ds.zig");
const tokens = @import("../tokens.zig");
const anim = @import("../anim/anim.zig");
const focus = @import("ds_focus");
const icon_mod = @import("icon.zig");
const loader_mod = @import("loader.zig");
pub const Source = @import("../source.zig");

const Color = dvui.Color;

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
    is_disabled: bool = false,
    is_loading: bool = false,
    override_text_color: ?Color = null,
    override_fill_color: ?Color = null,
    override_fill_hover: ?Color = null,
    override_fill_press: ?Color = null,
    override_gravity_x: ?f32 = null,
    override_expand: ?dvui.Options.Expand = null,
    override_padding: ?dvui.Rect = null,

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

    /// Set a named icon from the ds icon set. SVG→TVG conversion is
    /// handled automatically at draw time.
    pub fn icon(self: Button, comptime name: [:0]const u8, svg_bytes: []const u8) Button {
        return self.source(Source.namedIcon(name, svg_bytes));
    }

    pub fn iconFirst(self: Button) Button {
        var btn = self;
        btn.icon_first_flag = true;
        return btn;
    }

    /// Mark button as disabled (reduces opacity, no interaction).
    pub fn disabled(self: Button, val: bool) Button {
        var btn = self;
        btn.is_disabled = val;
        return btn;
    }

    /// Mark button as loading (shows spinner, no interaction).
    pub fn loading(self: Button, val: bool) Button {
        var btn = self;
        btn.is_loading = val;
        return btn;
    }

    /// Override the text/icon color (bypasses variant default).
    pub fn textColor(self: Button, val: Color) Button {
        var btn = self;
        btn.override_text_color = val;
        return btn;
    }

    /// Override the fill color (bypasses variant default).
    pub fn fillColor(self: Button, val: Color) Button {
        var btn = self;
        btn.override_fill_color = val;
        return btn;
    }

    /// Override hover fill color.
    pub fn fillHover(self: Button, val: Color) Button {
        var btn = self;
        btn.override_fill_hover = val;
        return btn;
    }

    /// Override press fill color.
    pub fn fillPress(self: Button, val: Color) Button {
        var btn = self;
        btn.override_fill_press = val;
        return btn;
    }

    /// Override horizontal gravity (0 = left, 0.5 = center, 1 = right).
    pub fn gravityX(self: Button, val: f32) Button {
        var btn = self;
        btn.override_gravity_x = val;
        return btn;
    }

    /// Override expand behavior.
    pub fn expand(self: Button, val: dvui.Options.Expand) Button {
        var btn = self;
        btn.override_expand = val;
        return btn;
    }

    /// Override padding.
    pub fn padding(self: Button, val: dvui.Rect) Button {
        var btn = self;
        btn.override_padding = val;
        return btn;
    }

    pub fn draw(self: Button) bool {
        // Resolve named icons to TVG at draw time
        const resolved_source: ?Source = if (self.btn_source) |src_asset| switch (src_asset.kind) {
            .named_icon => |ni| if (src_asset.resolveToTvg()) |tvg_data|
                Source.tvg(tvg_data.name, tvg_data.bytes)
            else blk: {
                _ = ni;
                break :blk null;
            },
            else => src_asset,
        } else null;

        var options = opts(self.btn_variant, self.btn_size);

        // Apply overrides
        if (self.override_text_color) |c| options.color_text = c;
        if (self.override_fill_color) |c| options.color_fill = c;
        if (self.override_fill_hover) |c| options.color_fill_hover = c;
        if (self.override_fill_press) |c| options.color_fill_press = c;
        if (self.override_gravity_x) |g| options.gravity_x = g;
        if (self.override_expand) |e| options.expand = e;
        if (self.override_padding) |p| options.padding = p;

        // Loading state: show spinner + label, no interaction
        if (self.is_loading) {
            return drawLoadingButton(self.src, self.label_str, self.btn_variant, self.btn_size, options);
        }

        // Disabled state: reduce opacity, no interaction
        if (self.is_disabled) {
            return drawDisabledButton(self.src, self.label_str, resolved_source, self.icon_first_flag, self.btn_variant, self.btn_size, options);
        }

        if (resolved_source) |asset| {
            switch (asset.kind) {
                .tvg => |tvg| {
                    if (self.label_str.len == 0) {
                        // Icon-only button (TVG)
                        const colors = iconColors(self.btn_variant);
                        const icon_sz = icon_mod.iconSize(self.btn_size);
                        return drawAnimatedIconButton(self.src, tvg.name, tvg.bytes, icon_sz, colors.fill, colors.stroke, options);
                    } else {
                        // Icon + text button (TVG)
                        return drawAnimatedLabelAndIcon(self.src, self.label_str, tvg.bytes, self.icon_first_flag, self.btn_size, options);
                    }
                },
                .image => |image_source| {
                    // Raster image button — composite: ButtonWidget + dvui.image()
                    return self.drawImageButton(image_source, options);
                },
                .named_icon => {
                    // Already resolved above; if we reach here, resolution failed
                    return drawAnimatedButton(self.src, self.label_str, options);
                },
            }
        } else {
            // Text-only button with animated background
            return drawAnimatedButton(self.src, self.label_str, options);
        }
    }

    fn drawImageButton(self: Button, image_source: dvui.ImageSource, options: dvui.Options) bool {
        const icon_sz = icon_mod.iconSize(self.btn_size);
        var bw: dvui.ButtonWidget = undefined;
        bw.init(self.src, .{ .draw_focus = focus.visible() }, options);
        defer bw.deinit();
        defer bw.drawFocus();
        bw.processEvents();
        bw.drawBackground();

        if (self.label_str.len > 0 and self.icon_first_flag) {
            _ = dvui.image(@src(), .{ .source = image_source }, .{
                .min_size_content = .{ .w = icon_sz, .h = icon_sz },
            });
            dvui.labelNoFmt(@src(), self.label_str, .{}, .{});
        } else if (self.label_str.len > 0) {
            dvui.labelNoFmt(@src(), self.label_str, .{}, .{});
            _ = dvui.image(@src(), .{ .source = image_source }, .{
                .min_size_content = .{ .w = icon_sz, .h = icon_sz },
            });
        } else {
            _ = dvui.image(@src(), .{ .source = image_source }, .{
                .min_size_content = .{ .w = icon_sz, .h = icon_sz },
            });
        }

        return bw.clicked();
    }
};

pub fn opts(btn_variant: tokens.Variant, btn_size: tokens.Size) dvui.Options {
    const theme = tokens.current;

    // DS spec — button sizes:
    // Small:  h-7 = 28px, 11px font
    // Medium: h-8 = 32px, 13px font
    // Large:  h-10 = 40px, 13px font
    // Using .pixel size_mode so font sizes match CSS exactly.
    // padding_v = (target_height - text_line_height) / 2
    const padding = switch (btn_size) {
        .sm => ds.paddingXY(theme.space_md, theme.space_xs),
        .md => ds.paddingXY(theme.space_lg, theme.space_sm),
        .lg => ds.paddingXY(theme.space_xl, theme.space_md),
    };

    // font-medium (500) = Geist Medium mapped as .bold in dvui
    const font: ?dvui.Font = switch (btn_size) {
        .sm => ds.fontBold(theme.font_size_sm),
        .md => ds.fontBold(theme.font_size_md),
        .lg => ds.fontBold(theme.font_size_md),
    };

    const radius = switch (btn_size) {
        .sm => dvui.Rect.all(theme.radius_sm),
        .md => dvui.Rect.all(theme.radius_md),
        .lg => dvui.Rect.all(theme.radius_md),
    };

    return switch (btn_variant) {
        // Primary: accent text, accent 25% hover
        .filled => .{
            .color_fill = ds.alpha(theme.accent, theme.opacity_fill_rest),
            .color_fill_hover = ds.alpha(theme.accent, theme.opacity_fill_hover),
            .color_fill_press = ds.alpha(theme.accent, theme.opacity_fill_press),
            .color_text = theme.accent,
            .color_border = .transparent,
            .corner_radius = radius,
            .border = dvui.Rect.all(0),
            .margin = dvui.Rect.all(0),
            .padding = padding,
            .font = font,
        },
        // Secondary: subtle bg, white hover
        .outlined => .{
            .color_fill = ds.alpha(.white, theme.opacity_subtle_rest),
            .color_fill_hover = ds.alpha(.white, theme.opacity_subtle_hover),
            .color_fill_press = ds.alpha(.white, theme.opacity_subtle_press),
            .color_text = theme.text_secondary,
            .color_border = theme.border_subtle,
            .corner_radius = radius,
            .border = dvui.Rect.all(theme.border_width),
            .margin = dvui.Rect.all(0),
            .padding = padding,
            .font = font,
        },
        // Ghost: transparent, white hover
        .ghost => .{
            .color_fill = .transparent,
            .color_fill_hover = ds.alpha(.white, theme.opacity_ghost_hover),
            .color_fill_press = ds.alpha(.white, theme.opacity_ghost_press),
            .color_text = theme.text_secondary,
            .corner_radius = radius,
            .border = dvui.Rect.all(0),
            .margin = dvui.Rect.all(0),
            .padding = padding,
            .font = font,
        },
        // Destructive: destructive text, destructive hover
        .danger => .{
            .color_fill = ds.alpha(theme.destructive, theme.opacity_fill_rest),
            .color_fill_hover = ds.alpha(theme.destructive, theme.opacity_fill_hover),
            .color_fill_press = ds.alpha(theme.destructive, theme.opacity_fill_press),
            .color_text = theme.destructive,
            .corner_radius = radius,
            .border = dvui.Rect.all(0),
            .margin = dvui.Rect.all(0),
            .padding = padding,
            .font = font,
        },
        // Accent ghost (AI): accent text, accent hover
        .accent_ghost => .{
            .color_fill = .transparent,
            .color_fill_hover = ds.alpha(theme.accent, theme.opacity_ghost_hover),
            .color_fill_press = ds.alpha(theme.accent, theme.opacity_subtle_press),
            .color_text = theme.accent,
            .corner_radius = radius,
            .border = dvui.Rect.all(0),
            .margin = dvui.Rect.all(0),
            .padding = padding,
            .font = font,
        },
    };
}

fn iconColors(btn_variant: tokens.Variant) struct { fill: tokens.Color, stroke: tokens.Color } {
    const theme = tokens.current;
    return switch (btn_variant) {
        .filled => .{ .fill = theme.accent, .stroke = theme.accent },
        .outlined => .{ .fill = theme.text_secondary, .stroke = theme.text_secondary },
        .ghost => .{ .fill = theme.text_secondary, .stroke = theme.text_secondary },
        .danger => .{ .fill = theme.destructive, .stroke = theme.destructive },
        .accent_ghost => .{ .fill = theme.accent, .stroke = theme.accent },
    };
}

/// Get the text/icon color for a variant (used by loading state).
fn variantTextColor(btn_variant: tokens.Variant) Color {
    const theme = tokens.current;
    return switch (btn_variant) {
        .filled => theme.accent,
        .outlined => theme.text_secondary,
        .ghost => theme.text_secondary,
        .danger => theme.destructive,
        .accent_ghost => theme.accent,
    };
}

// ─── Animated Drawing ────────────────────────────────────────────────────────

/// Determine the target fill color for a button based on interaction state.
fn targetFillColor(bw: *dvui.ButtonWidget) dvui.Color {
    if (dvui.captured(bw.data().id)) {
        return bw.data().options.color(.fill_press);
    } else if (bw.hover) {
        return bw.data().options.color(.fill_hover);
    } else {
        return bw.data().options.color(.fill);
    }
}

/// Determine the target text color for a button based on interaction state.
fn targetTextColor(bw: *dvui.ButtonWidget) dvui.Color {
    if (dvui.captured(bw.data().id)) {
        return bw.data().options.color(.text_press);
    } else if (bw.hover) {
        return bw.data().options.color(.text_hover);
    } else {
        return bw.data().options.color(.text);
    }
}

/// Animated text-only button.
fn drawAnimatedButton(src: std.builtin.SourceLocation, label_str: []const u8, options: dvui.Options) bool {
    var bw: dvui.ButtonWidget = undefined;
    bw.init(src, .{ .draw_focus = focus.visible() }, options);
    defer bw.deinit();
    defer bw.drawFocus();
    bw.processEvents();

    const fill = anim.color(bw.data().id, "fill", targetFillColor(&bw), .{});
    bw.data().borderAndBackground(.{ .fill_color = fill });

    const target_text = targetTextColor(&bw);
    const text_color = anim.color(bw.data().id, "text", target_text, .{});

    const gravity_x = options.gravity_x orelse 0.5;
    dvui.labelNoFmt(@src(), label_str, .{ .align_x = 0.5, .align_y = 0.5 }, options.strip().override(bw.style()).override(.{ .color_text = text_color, .gravity_x = gravity_x, .gravity_y = 0.5 }));

    return bw.clicked();
}

/// Animated icon-only button.
fn drawAnimatedIconButton(src: std.builtin.SourceLocation, name: [:0]const u8, tvg_bytes: []const u8, icon_sz: f32, fill_color: Color, stroke_color: Color, options: dvui.Options) bool {
    var bw: dvui.ButtonWidget = undefined;
    bw.init(src, .{ .draw_focus = focus.visible() }, options.override(.{ .min_size_content = .{ .w = icon_sz, .h = icon_sz } }));
    defer bw.deinit();
    defer bw.drawFocus();
    bw.processEvents();

    const fill = anim.color(bw.data().id, "fill", targetFillColor(&bw), .{});
    bw.data().borderAndBackground(.{ .fill_color = fill });

    const anim_fill = anim.color(bw.data().id, "icon_f", fill_color, .{});
    const anim_stroke = anim.color(bw.data().id, "icon_s", stroke_color, .{});

    dvui.icon(@src(), name, tvg_bytes, .{ .fill_color = anim_fill, .stroke_color = anim_stroke }, .{
        .gravity_x = 0.5,
        .gravity_y = 0.5,
        // Size the glyph to the icon size for this button size — without this the
        // icon renders at the default (~font line height) and doesn't scale.
        .min_size_content = .{ .w = icon_sz, .h = icon_sz },
    });

    return bw.clicked();
}

/// Animated label + icon button.
fn drawAnimatedLabelAndIcon(src: std.builtin.SourceLocation, label_str: []const u8, tvg_bytes: []const u8, icon_first: bool, btn_size: tokens.Size, options: dvui.Options) bool {
    var bw: dvui.ButtonWidget = undefined;
    bw.init(src, .{ .draw_focus = focus.visible() }, options);
    defer bw.deinit();
    defer bw.drawFocus();
    bw.processEvents();

    const fill = anim.color(bw.data().id, "fill", targetFillColor(&bw), .{});
    bw.data().borderAndBackground(.{ .fill_color = fill });

    const target_text = targetTextColor(&bw);
    const text_color = anim.color(bw.data().id, "text", target_text, .{});

    const style = options.strip().override(bw.style()).override(.{ .color_text = text_color });
    {
        var row = dvui.box(@src(), .{ .dir = .horizontal, .gap = tokens.current.space_sm }, .{ .gravity_x = options.gravity_x orelse 0.5, .gravity_y = 0.5 });
        defer row.deinit();
        const icon_sz = icon_mod.iconSize(btn_size);
        if (icon_first) {
            _ = dvui.icon(@src(), "", tvg_bytes, .{}, style.override(.{ .min_size_content = .{ .w = icon_sz, .h = icon_sz }, .gravity_y = 0.5 }));
            dvui.labelNoFmt(@src(), label_str, .{}, style.override(.{ .gravity_y = 0.5 }));
        } else {
            dvui.labelNoFmt(@src(), label_str, .{}, style.override(.{ .gravity_y = 0.5 }));
            _ = dvui.icon(@src(), "", tvg_bytes, .{}, style.override(.{ .min_size_content = .{ .w = icon_sz, .h = icon_sz }, .gravity_y = 0.5 }));
        }
    }

    return bw.clicked();
}

/// Button in loading state: spinner + label, disabled interaction.
/// Applies uniform 40% opacity over entire button (disabled:opacity-40).
fn drawLoadingButton(src: std.builtin.SourceLocation, label_str: []const u8, btn_variant: tokens.Variant, btn_size: tokens.Size, options: dvui.Options) bool {
    const theme = tokens.current;
    const text_color = variantTextColor(btn_variant).opacity(theme.opacity_disabled);

    var bw: dvui.ButtonWidget = undefined;
    bw.init(src, .{ .draw_focus = focus.visible() }, options);
    defer bw.deinit();
    defer bw.drawFocus();

    // Don't process events — loading buttons are non-interactive
    bw.data().borderAndBackground(.{ .fill_color = targetFillColor(&bw).opacity(theme.opacity_disabled) });

    {
        var row = dvui.box(@src(), .{ .dir = .horizontal, .gap = theme.space_sm }, .{ .gravity_x = 0.5, .gravity_y = 0.5 });
        defer row.deinit();

        // Draw spinner inline — color matches variant text color at 40% opacity
        loader_mod.loader(@src()).size(btn_size).color(text_color).draw();

        // Draw label if provided
        if (label_str.len > 0) {
            const style = options.strip().override(bw.style()).override(.{ .color_text = text_color });
            dvui.labelNoFmt(@src(), label_str, .{}, style.override(.{ .gravity_y = 0.5 }));
        }
    }

    return false;
}

/// Button in disabled state: reduced opacity, no interaction.
/// Applies uniform 40% opacity over entire button (disabled:opacity-40).
fn drawDisabledButton(src: std.builtin.SourceLocation, label_str: []const u8, btn_source: ?Source, icon_first: bool, btn_variant: tokens.Variant, btn_size: tokens.Size, options: dvui.Options) bool {
    _ = btn_variant;

    var bw: dvui.ButtonWidget = undefined;
    bw.init(src, .{ .draw_focus = focus.visible() }, options);
    defer bw.deinit();
    defer bw.drawFocus();

    // Don't process events — disabled buttons are non-interactive
    bw.data().borderAndBackground(.{ .fill_color = targetFillColor(&bw).opacity(tokens.current.opacity_disabled) });

    const dim_text = options.color(.text).opacity(tokens.current.opacity_disabled);
    const style = options.strip().override(bw.style()).override(.{ .color_text = dim_text });
    const icon_sz = icon_mod.iconSize(btn_size);

    if (btn_source) |asset| {
        const tvg_bytes: ?[]const u8 = switch (asset.kind) {
            .tvg => |tvg| tvg.bytes,
            .named_icon => null, // already resolved before reaching here
            .image => null,
        };
        if (tvg_bytes) |bytes| {
            if (label_str.len > 0) {
                var row = dvui.box(@src(), .{ .dir = .horizontal, .gap = tokens.current.space_sm }, .{ .gravity_x = 0.5, .gravity_y = 0.5 });
                defer row.deinit();
                if (icon_first) {
                    _ = dvui.icon(@src(), "", bytes, .{}, style.override(.{ .min_size_content = .{ .w = icon_sz, .h = icon_sz } }));
                    dvui.labelNoFmt(@src(), label_str, .{}, style);
                } else {
                    dvui.labelNoFmt(@src(), label_str, .{}, style);
                    _ = dvui.icon(@src(), "", bytes, .{}, style.override(.{ .min_size_content = .{ .w = icon_sz, .h = icon_sz } }));
                }
            } else {
                _ = dvui.icon(@src(), "", bytes, .{}, .{ .gravity_x = 0.5, .gravity_y = 0.5, .min_size_content = .{ .w = icon_sz, .h = icon_sz } });
            }
        } else {
            dvui.labelNoFmt(@src(), label_str, .{ .align_x = 0.5, .align_y = 0.5 }, style.override(.{ .gravity_x = 0.5, .gravity_y = 0.5 }));
        }
    } else {
        dvui.labelNoFmt(@src(), label_str, .{ .align_x = 0.5, .align_y = 0.5 }, style.override(.{ .gravity_x = 0.5, .gravity_y = 0.5 }));
    }

    return false;
}

test {
    _ = @import("button_tests.zig");
}
