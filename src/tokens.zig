/// Design tokens — the theme contract for dvui-ds widgets.
///
/// Consumers create a `Theme` struct with their color/spacing values and
/// pass it to `ds.init()`. Widgets read `tokens.current` at draw time.
const dvui = @import("dvui");

pub const Color = dvui.Color;

pub const Variant = enum {
    filled,
    outlined,
    ghost,
    danger,
};

pub const Size = enum {
    sm,
    md,
    lg,
};

/// Theme token struct — all values required by ds widgets.
pub const Theme = struct {
    // ── Fill colors ──────────────────────────────────────────────────────────
    bg_base: Color,
    bg_surface: Color,
    bg_elevated: Color,
    bg_card: Color,
    bg_card_hover: Color,
    fill_subtle: Color,

    // ── Text colors ──────────────────────────────────────────────────────────
    text_primary: Color,
    text_secondary: Color,
    text_muted: Color,
    text_weak: Color,

    // ── Accent ───────────────────────────────────────────────────────────────
    accent: Color,
    accent_hover: Color,
    accent_press: Color,
    accent_dim: Color,
    accent_subtle: Color,

    // ── Danger ───────────────────────────────────────────────────────────────
    danger: Color,
    danger_dim: Color,

    // ── Neutral (ghost/secondary states) ─────────────────────────────────────
    neutral_hover: Color,
    neutral_press: Color,

    // ── Borders ──────────────────────────────────────────────────────────────
    border_normal: Color,
    border_subtle: Color,

    // ── Spacing ──────────────────────────────────────────────────────────────
    space_3xs: f32 = 2,
    space_2xs: f32 = 4,
    space_xs: f32 = 6,
    space_sm: f32 = 8,
    space_md: f32 = 12,
    space_lg: f32 = 16,

    // ── Radii ────────────────────────────────────────────────────────────────
    radius_sm: f32 = 4,
    radius_md: f32 = 6,
    radius_lg: f32 = 8,

    // ── Icon sizes ───────────────────────────────────────────────────────────
    icon_sm: f32 = 11,
    icon_md: f32 = 14,
    icon_lg: f32 = 18,
};

/// Active theme — set via `ds.init()`.
pub var current: Theme = default_theme;

/// Fallback dark theme (usable out of the box for testing).
pub const default_theme: Theme = blk: {
    @setEvalBranchQuota(10000);
    break :blk .{
        .bg_base = .fromHex("#0D0D0D"),
        .bg_surface = .fromHex("#161616"),
        .bg_elevated = .fromHex("#222222"),
        .bg_card = .fromHex("#1E1E1E"),
        .bg_card_hover = .fromHex("#2A2A2A"),
        .fill_subtle = .fromHex("#2A2A2A"),
        .text_primary = .fromHex("#FFFFFF"),
        .text_secondary = .fromHex("#C6C6C6"),
        .text_muted = .fromHex("#909090"),
        .text_weak = .fromHex("#5E5E5E"),
        .accent = .fromHex("#026EFE"),
        .accent_hover = .fromHex("#0057CD"),
        .accent_press = .fromHex("#00419D"),
        .accent_dim = .fromHex("#0A1E3A"),
        .accent_subtle = .fromHex("#0E2A4A"),
        .danger = .fromHex("#DE3730"),
        .danger_dim = .fromHex("#2A0808"),
        .neutral_hover = .fromHex("#2A2A2A"),
        .neutral_press = .fromHex("#333333"),
        .border_normal = .fromHex("#383838"),
        .border_subtle = .fromHex("#2C2C2C"),
    };
};

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// RESOLVER FUNCTIONS (used by widget modules)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

pub fn buttonOpts(v: Variant, size: Size) dvui.Options {
    const t = current;
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

pub fn iconColors(v: Variant) struct { fill: Color, stroke: Color } {
    const t = current;
    return switch (v) {
        .filled => .{ .fill = t.text_primary, .stroke = t.text_primary },
        .outlined => .{ .fill = t.text_secondary, .stroke = t.text_secondary },
        .ghost => .{ .fill = t.text_secondary, .stroke = t.text_secondary },
        .danger => .{ .fill = t.danger, .stroke = t.danger },
    };
}

pub fn iconSize(size: Size) f32 {
    const t = current;
    return switch (size) {
        .sm => t.icon_sm,
        .md => t.icon_md,
        .lg => t.icon_lg,
    };
}

pub fn panelHeaderOpts() dvui.Options {
    const t = current;
    return .{
        .color_fill = t.bg_elevated,
        .background = true,
        .padding = .{ .x = t.space_xs, .y = t.space_3xs, .w = t.space_xs, .h = t.space_3xs },
        .border = .{ .x = 0, .y = 0, .w = 0, .h = 1 },
        .color_border = t.border_normal,
        .expand = .horizontal,
    };
}

pub fn panelBodyOpts() dvui.Options {
    const t = current;
    return .{
        .color_fill = t.bg_surface,
        .color_border = t.border_normal,
        .border = dvui.Rect.all(1),
        .padding = dvui.Rect.all(0),
        .expand = .both,
    };
}

pub fn menuBarOpts() dvui.Options {
    const t = current;
    return .{
        .expand = .horizontal,
        .color_fill = t.bg_elevated,
        .background = true,
        .padding = .{ .x = t.space_xs, .y = t.space_3xs, .w = t.space_xs, .h = t.space_3xs },
        .border = .{ .x = 0, .y = 0, .w = 0, .h = 1 },
        .color_border = t.border_subtle,
    };
}

pub fn floatingMenuOpts() dvui.Options {
    const t = current;
    return .{
        .color_fill = t.bg_elevated,
        .color_border = t.border_normal,
        .corner_radius = dvui.Rect.all(t.radius_lg),
    };
}

pub fn menuItemOpts() dvui.Options {
    const t = current;
    return .{
        .color_text = t.text_secondary,
        .corner_radius = dvui.Rect.all(t.radius_sm),
        .padding = .{ .x = t.space_xs, .y = t.space_xs, .w = t.space_xs, .h = t.space_xs },
    };
}

pub fn toolbarOpts() dvui.Options {
    const t = current;
    return .{
        .color_fill = t.bg_elevated,
        .background = true,
        .padding = .{ .x = t.space_xs, .y = t.space_3xs, .w = t.space_xs, .h = t.space_3xs },
        .border = .{ .x = 0, .y = 0, .w = 0, .h = 1 },
        .color_border = t.border_normal,
        .expand = .horizontal,
    };
}
