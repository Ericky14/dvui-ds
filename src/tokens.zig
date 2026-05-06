/// Design tokens — the theme contract for dvui-ds widgets.
///
/// Consumers create a `Theme` struct with their color/spacing values and
/// pass it to `ds.init()`. Widgets read `tokens.current` at draw time.
const dvui = @import("dvui");
const ds = @import("ds.zig");

pub const Color = dvui.Color;

pub const Variant = enum {
    filled,
    outlined,
    ghost,
    danger,
    accent_ghost,
};

pub const Size = enum {
    sm,
    md,
    lg,
};

/// Theme token struct — all values required by ds widgets.
/// Named to match the Design System color tokens.
pub const Theme = struct {
    // ── Surfaces ─────────────────────────────────────────────────────────────
    surface_0: Color, // App background
    surface_1: Color, // Cards, panels
    surface_2: Color, // Elevated surfaces
    surface_3: Color, // Borders, dividers
    surface_4: Color, // Hover states

    // ── Text ─────────────────────────────────────────────────────────────────
    text_primary: Color, // Headings, body
    text_secondary: Color, // Descriptions
    text_muted: Color, // Captions, hints
    text_ghost: Color, // Placeholders

    // ── Accent ───────────────────────────────────────────────────────────────
    accent: Color, // Primary interactive
    accent_muted: Color, // Hover/pressed accent

    // ── Destructive ──────────────────────────────────────────────────────────
    destructive: Color, // Dangerous actions
    destructive_muted: Color, // Hover/pressed destructive

    // ── Borders ──────────────────────────────────────────────────────────────
    border: Color, // Default borders (rgba 255,255,255,0.10)
    border_subtle: Color, // Light dividers (rgba 255,255,255,0.06)
    border_strong: Color, // Emphasis borders (rgba 255,255,255,0.18)

    // ── Spacing ──────────────────────────────────────────────────────────────
    space_3xs: f32 = 2,
    space_2xs: f32 = 4,
    space_xs: f32 = 6,
    space_sm: f32 = 8,
    space_md: f32 = 12,
    space_lg: f32 = 16,
    space_xl: f32 = 20,
    space_2xl: f32 = 24,

    // ── Radii ────────────────────────────────────────────────────────────────
    radius_sm: f32 = 6,
    radius_md: f32 = 8,
    radius_lg: f32 = 12,

    // ── Icon sizes ───────────────────────────────────────────────────────────
    icon_sm: f32 = 11,
    icon_md: f32 = 14,
    icon_lg: f32 = 18,

    // ── Spinner sizes ────────────────────────────────────────────────────────
    spinner_sm: f32 = 12,
    spinner_md: f32 = 16,
    spinner_lg: f32 = 20,

    // ── Border widths ────────────────────────────────────────────────────────
    border_width: f32 = 1,

    // ── Font ──────────────────────────────────────────────────────────────────
    font_family: [:0]const u8 = "Geist",

    // ── Font sizes (pixel) ───────────────────────────────────────────────────
    font_size_sm: u16 = 11,
    font_size_md: u16 = 13,
    font_size_lg: u16 = 16,
    font_size_xl: u16 = 20,

    // ── Opacity ──────────────────────────────────────────────────────────────
    opacity_disabled: f32 = 0.4,
    opacity_fill_rest: u8 = 30,
    opacity_fill_hover: u8 = 64,
    opacity_fill_press: u8 = 76,
    opacity_subtle_rest: u8 = 10,
    opacity_subtle_hover: u8 = 18,
    opacity_subtle_press: u8 = 25,
    opacity_ghost_hover: u8 = 15,
    opacity_ghost_press: u8 = 23,
    opacity_track: u8 = 5, // divisor: track_alpha = color.a / track_opacity

    // ── Sidebar ──────────────────────────────────────────────────────────────
    sidebar_min_width: f32 = 160,
    sidebar_padding_x: f32 = 16,
    sidebar_padding_y: f32 = 20,

    // ── Animation ────────────────────────────────────────────────────────────
    spinner_duration: i32 = 700_000,
};

/// Active theme — set via `ds.init()`.
pub var current: Theme = default_theme;

/// Returns a dvui.Theme that matches our ds tokens so widgets
/// that fall back to the dvui theme use the correct colors.
pub fn dvuiTheme() dvui.Theme {
    const t = current;
    // Start from Adwaita dark to get embedded fonts, then override colors.
    var theme = dvui.Theme.builtin.adwaita_dark;
    theme.name = "dvui-ds";
    theme.focus = t.accent;
    theme.fill = t.surface_0;
    theme.fill_hover = t.surface_3;
    theme.fill_press = t.surface_4;
    theme.text = t.text_primary;
    theme.border = t.border;
    theme.control = .{
        .fill = t.surface_2,
        .fill_hover = t.surface_3,
        .fill_press = t.surface_4,
    };
    theme.window = .{
        .fill = t.surface_0,
    };
    theme.highlight = .{
        .fill = t.accent,
        .fill_hover = t.accent_muted,
        .text = t.text_primary,
    };
    theme.err = .{
        .fill = t.destructive,
        .fill_hover = t.destructive_muted,
        .text = t.text_primary,
    };
    // Geist font family — using .pixel size_mode for CSS/iced-compatible sizing.
    // Values match the Desktop text styles:
    // body = body-sm (13px/18px), heading = heading-sm (16px/24px), title = heading-md (20px/28px)
    theme.embedded_fonts = &geist_fonts;
    theme.font_body = ds.font(current.font_size_md);
    theme.font_heading = ds.fontBold(current.font_size_lg);
    theme.font_title = ds.fontBold(current.font_size_xl);
    theme.font_mono = ds.font(current.font_size_md);
    return theme;
}

const font_family_default: [:0]const u8 = "Geist";

const geist_fonts: [3]dvui.Font.Source = .{
    .{
        .family = dvui.Font.array(font_family_default),
        .bytes = @embedFile("fonts/Geist-Regular.ttf"),
    },
    .{
        .family = dvui.Font.array(font_family_default),
        .weight = .medium,
        .bytes = @embedFile("fonts/Geist-Medium.ttf"),
    },
    .{
        .family = dvui.Font.array(font_family_default),
        .weight = .bold,
        .bytes = @embedFile("fonts/Geist-Bold.ttf"),
    },
};

/// Fallback dark theme — Cosmic Teal.
pub const default_theme: Theme = blk: {
    @setEvalBranchQuota(10000);
    break :blk .{
        // Surfaces
        .surface_0 = .fromHex("#0C0E14"), // App background
        .surface_1 = .fromHex("#12141A"), // Cards, panels
        .surface_2 = .fromHex("#181B22"), // Elevated surfaces
        .surface_3 = .fromHex("#1F222A"), // Borders, dividers
        .surface_4 = .fromHex("#2A2D36"), // Hover states

        // Text
        .text_primary = .fromHex("#E8EAF0"),
        .text_secondary = .fromHex("#A0A5B0"),
        .text_muted = .fromHex("#646A78"),
        .text_ghost = .fromHex("#3D4250"),

        // Accent (Cosmic Teal)
        .accent = .fromHex("#6EB5FF"),
        .accent_muted = .fromHex("#4A96E0"),

        // Destructive
        .destructive = .fromHex("#E87070"),
        .destructive_muted = .fromHex("#B85555"),

        // Borders (approximated as solid for dvui — original uses rgba)
        .border = .fromHex("#2A2C33"), // ~rgba(255,255,255,0.10) on #0C0E14
        .border_subtle = .fromHex("#1E2028"), // ~rgba(255,255,255,0.06) on #0C0E14
        .border_strong = .fromHex("#3A3D46"), // ~rgba(255,255,255,0.18) on #0C0E14
    };
};
