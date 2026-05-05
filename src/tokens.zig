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
// SHARED RESOLVERS (used by multiple widget modules)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

pub fn iconSize(size: Size) f32 {
    const t = current;
    return switch (size) {
        .sm => t.icon_sm,
        .md => t.icon_md,
        .lg => t.icon_lg,
    };
}
