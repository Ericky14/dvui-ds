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
    border_input: Color, // Input field borders (rgba 255,255,255,0.12)
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
    radius_xl: f32 = 16,

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
    /// Monospace family: code blocks, inline code, the label `.mono` FontToken,
    /// tool-card names and the composer hint row (`ds.fontMono` / `dvuiTheme().font_mono`).
    font_family_mono: [:0]const u8 = "Geist Mono",

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

    // ── State layers (Material 3) ──────────────────────────────────────────────
    // Translucent overlay drawn over a control's shape on interaction. Alphas are
    // the M3 ratios (hover 8%, focus 10%, press 12%) expressed as 0–255.
    state_hover: u8 = 20, // ~8%
    state_focus: u8 = 26, // ~10%
    state_press: u8 = 31, // ~12%

    // Tonal fill alpha for chips/badges (a colored wash behind colored text).
    opacity_tonal_fill: u8 = 40, // ~16%

    // ── Elevation / shadow ─────────────────────────────────────────────────────
    // Drop-shadow color + peak alpha for elevated surfaces (cards, dialogs,
    // tooltips). Per-widget blur radius / offset stays in the widget (geometry).
    shadow_color: Color = .black,
    shadow_alpha: f32 = 0.4,

    // ── Glass (backdrop-filter surfaces) ──────────────────────────────
    // A glass surface is three layers: the blurred capture of whatever is
    // behind it, a tint over that (or the blur reads as mush and text loses
    // contrast), and a 1 px highlight along the top inside edge. The highlight
    // is the layer that actually sells it — it is the specular line a real
    // pane of glass catches, and without it a translucent panel just looks
    // like a weak fill.
    /// Tint painted over the blurred capture. `null` → the theme's `surface_1`,
    /// so a custom theme gets coherent glass without naming a new colour.
    glass_tint: ?Color = null,
    /// Alpha of that tint when the blur is live (≈84 %). Measured against a
    /// bright render, not a mockup: at ≈55 % the blur is prettier and the small
    /// text on top of it is genuinely hard to read, which is not a trade a
    /// tool's inspector gets to make. The blur still reads clearly through it —
    /// and the rule that goes with this number is that text *on* glass uses
    /// `.secondary` or `.primary`, never `.muted`/`.weak`, which are tuned for
    /// an opaque dark surface and vanish over a bright one.
    glass_alpha: u8 = 214,
    /// Alpha of the tint when there is no blur — a backend without render
    /// targets, or a caller that asked for `.solid()` / reduced transparency.
    /// Near-opaque, because an un-blurred 55 % panel over a 3-D scene is
    /// unreadable.
    glass_alpha_opaque: u8 = 250,
    /// CSS `backdrop-filter: blur(<radius>)`, in logical px.
    glass_blur: f32 = 24,
    /// White alpha of the 1 px inner highlight along the top edge (≈12 %).
    glass_edge_alpha: u8 = 30,
    /// White alpha of the hairline around a glass surface (≈8 %).
    glass_border_alpha: u8 = 20,

    // ── Window chrome (the double border) ───────────────────────────
    // Two hairlines, not one: a near-black outer ring separates the app from
    // whatever is on the desktop behind it, and a light inner ring lifts the
    // app off that ring. One line alone reads as either a smudge (dark) or a
    // cheap outline (light); the pair reads as a machined edge.
    /// Outer ring. `null` → black.
    border_outer: ?Color = null,
    /// White alpha of the inner ring when the window has focus (≈10 %).
    border_inner_alpha: u8 = 26,
    /// …and when it does not. The window visibly recedes when you click away.
    border_inner_alpha_unfocused: u8 = 12,
    /// Corner radius of the window itself.
    radius_window: f32 = 12,

    // ── Preview frame (the picture) ───────────────────────────────
    /// Corner radius of the framed picture.
    preview_radius: f32 = 10,
    /// Gutter between the pane and the picture. On the 4 px grid.
    preview_inset: f32 = 8,
    /// Black alpha at the corners of the inner vignette (≈35 %). The vignette
    /// is what stops a bright render from bleeding into the chrome — and what
    /// keeps the corners, where floating panels live, from being the brightest
    /// part of the picture.
    preview_vignette_alpha: u8 = 90,
    /// Fraction of the way to the corner at which the vignette starts. Below
    /// this the picture is untouched.
    preview_vignette_start: f32 = 0.55,
    /// White alpha of the hairline drawn *over* the picture's edge (≈15 %).
    preview_hairline_alpha: u8 = 38,

    // ── Elevation ───────────────────────────────────────────
    // A three-step shadow scale, shared so every raised surface agrees.
    // `shadow_color`/`shadow_alpha` above give the colour; these give the
    // geometry (y offset and blur fade, both in logical px).
    /// Resting chips, pills, toolbars.
    elevation_1_offset: f32 = 1,
    elevation_1_fade: f32 = 8,
    /// Cards, popovers.
    elevation_2_offset: f32 = 3,
    elevation_2_fade: f32 = 16,
    /// Dialogs, drawers, anything floating over a live view.
    elevation_3_offset: f32 = 6,
    elevation_3_fade: f32 = 28,

    // ── Chrome metrics ─────────────────────────────────────
    // Shared heights so the title bar, the floating toolbar, the status strip
    // and the history strip line up instead of each picking its own number.
    /// Title bar height.
    chrome_titlebar_height: f32 = 36,
    /// Floating toolbar height: a `chrome_chip_size` chip plus 6 px either side.
    chrome_toolbar_height: f32 = 40,
    /// Status strip height.
    chrome_status_height: f32 = 28,
    /// Square icon chip. Matches the `sm` button height, and is comfortably
    /// over the 24 px minimum hit target.
    chrome_chip_size: f32 = 28,
    /// Status / selection pill height.
    chrome_pill_height: f32 = 24,

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
    // Geist (sans) + Geist Mono — using .pixel size_mode for CSS/iced-compatible sizing.
    // Values match the Desktop text styles:
    // body = body-sm (13px/18px), heading = heading-sm (16px/24px), title = heading-md (20px/28px)
    theme.embedded_fonts = &geist_fonts;
    theme.font_body = ds.font(current.font_size_md);
    theme.font_heading = ds.fontBold(current.font_size_lg);
    theme.font_title = ds.fontBold(current.font_size_xl);
    theme.font_mono = ds.fontMono(current.font_size_md);
    return theme;
}

const font_family_default: [:0]const u8 = "Geist";
const font_family_mono_default: [:0]const u8 = "Geist Mono";

/// Every face embedded in the binary (SIL OFL, see src/fonts/). Sans: Regular/Medium/Bold.
/// Mono: Regular/Medium — the chat cards ask for `.medium` mono, so both weights ship;
/// a missing weight makes dvui fall back to the nearest one and log it every frame.
const geist_fonts: [5]dvui.Font.Source = .{
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
    .{
        .family = dvui.Font.array(font_family_mono_default),
        .bytes = @embedFile("fonts/GeistMono-Regular.ttf"),
    },
    .{
        .family = dvui.Font.array(font_family_mono_default),
        .weight = .medium,
        .bytes = @embedFile("fonts/GeistMono-Medium.ttf"),
    },
};

/// The embedded font sources `dvuiTheme()` registers (read-only view for tests/tools).
pub fn embeddedFonts() []const dvui.Font.Source {
    return &geist_fonts;
}

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
        .border_input = .fromHex("#2E3038"), // ~rgba(255,255,255,0.12) on #0C0E14
        .border_strong = .fromHex("#3A3D46"), // ~rgba(255,255,255,0.18) on #0C0E14
    };
};
