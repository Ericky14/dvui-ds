//! The accent palette, checked as numbers.
//!
//! The owner's note was "I don't like that dark blue colour being used, let's
//! try to use a more modern lighter blue". Both halves of that are measurable,
//! so both are asserted here rather than eyeballed:
//!
//!   * *lighter* — the accent's relative luminance must beat the blue it
//!     replaced (`previous_accent`), and every accent surface derived from it
//!     must beat the surface the old constants produced.
//!   * *not dark blue* — the tonal surface behind a selected row has to read as
//!     a lit surface, not as a shadow: `contrastRatio(accentSoft, surface_0)`
//!     must clear `min_soft_lift`.
//!
//! On top of that the WCAG table: 4.5:1 for body text, 3:1 for the 11 px
//! captions and for icon glyphs. Every pair a widget actually draws is listed,
//! so re-tuning a mix constant cannot quietly push a real pairing under.
//!
//! Run: `../zigame/tools/zig build test`.
const std = @import("std");
const dvui = @import("dvui");
const tokens = @import("tokens.zig");
const color = @import("helpers/color.zig");

const testing = std.testing;
const Color = dvui.Color;

/// WCAG AA for body text.
const body_min: f32 = 4.5;
/// WCAG AA for large/bold text, 11 px captions and icon glyphs.
const caption_min: f32 = 3.0;
/// How far the tonal accent surface must sit above the app background before it
/// reads as a surface rather than as a shadow. 2.12 is what the old
/// `soft_mix = 0.64` over `#6EB5FF` gave, and it read as "dark blue".
const min_soft_lift: f32 = 2.5;
/// The accent this palette replaced. The new one has to be lighter than it.
const previous_accent: Color = .fromHex("#6EB5FF");

fn ratio(foreground: Color, background: Color) f32 {
    return color.contrastRatio(foreground, background);
}

test "the accent is lighter than the blue it replaced" {
    const theme = tokens.default_theme;
    const now = color.relativeLuminance(theme.accent);
    const before = color.relativeLuminance(previous_accent);
    // Not "different" — lighter, which is what was asked for.
    try testing.expect(now > before);
    // And meaningfully so: a change under ~5 % is invisible next to the old one.
    try testing.expect(now / before > 1.05);
}

test "the tonal accent surface reads as a surface, not a shadow" {
    const theme = tokens.default_theme;
    const soft = theme.accentSoft();
    try testing.expect(ratio(soft, theme.surface_0) >= min_soft_lift);
    // The hover step has to be visible but not a jump to a different colour.
    const hover = theme.accentSoftHover();
    const lift = color.relativeLuminance(hover) / color.relativeLuminance(soft);
    try testing.expect(lift > 1.10);
    try testing.expect(lift < 1.60);
    // Hover is lighter than rest, pressed is darker than the accent itself.
    try testing.expect(color.relativeLuminance(hover) > color.relativeLuminance(soft));
    try testing.expect(color.relativeLuminance(theme.accentPressed()) < color.relativeLuminance(theme.accent));
    try testing.expect(color.relativeLuminance(theme.accentHover()) > color.relativeLuminance(theme.accent));
}

test "body text on every accent surface clears WCAG AA" {
    const theme = tokens.default_theme;
    const soft = theme.accentSoft();
    const soft_hover = theme.accentSoftHover();
    const on_soft = theme.accentOnSoft();

    // `ds.badge(.accent)` and a selected tree row draw `accentOnSoft` on
    // `accentSoft`, at rest and under the pointer. (The *controls* —
    // `button(.filled)`, an on chip, `pill(.accent)` — moved to the solid
    // accent; those pairs are the test below.)
    try testing.expect(ratio(on_soft, soft) >= body_min);
    try testing.expect(ratio(on_soft, soft_hover) >= body_min);

    // A selected tree row can also carry plain primary text.
    try testing.expect(ratio(theme.text_primary, soft) >= body_min);

    // The approval card's tinted body (see `chat/approval_card.zig`).
    const approval_fill = color.mix(soft, theme.surface_1, 0.55);
    try testing.expect(ratio(theme.text_primary, approval_fill) >= body_min);
    try testing.expect(ratio(theme.text_secondary, approval_fill) >= body_min);
}

test "accent text and glyphs on the app surfaces clear WCAG AA" {
    const theme = tokens.default_theme;
    // `ds.label(.accent)`, `ds.icon(.accent)`, the active tab label, the
    // markdown link colour, the router's active item.
    for ([_]Color{ theme.surface_0, theme.surface_1, theme.surface_2 }) |background| {
        try testing.expect(ratio(theme.accent, background) >= body_min);
        try testing.expect(ratio(theme.accentOnSoft(), background) >= body_min);
    }
}

test "dark ink on the solid accent clears WCAG AA in every state" {
    const theme = tokens.default_theme;
    // `button(.filled)`, `chip(.active)`, `chip(.current)` and `pill(.accent)`
    // are the accent itself with `surface_0` on top — the M3 / iOS filled
    // convention. Rest, hover and pressed all have to hold, and pressed is the
    // tight one because it mixes *towards* the background.
    try testing.expect(ratio(theme.surface_0, theme.accent) >= body_min);
    try testing.expect(ratio(theme.surface_0, theme.accentHover()) >= body_min);
    try testing.expect(ratio(theme.surface_0, theme.accentPressed()) >= body_min);
    // The `.current` chip's ring is the same ink, so it reads on the same fill.
    try testing.expect(ratio(theme.surface_0, theme.accent) >= caption_min);
}

test "a solid accent control is unmistakable against the surfaces around it" {
    const theme = tokens.default_theme;
    // A filled button has no border, so its own edge is the only thing marking
    // it: the fill has to separate from the panel it sits on.
    for ([_]Color{ theme.surface_0, theme.surface_1, theme.surface_2 }) |background| {
        try testing.expect(ratio(theme.accent, background) >= body_min);
    }
    // …and from the tonal surface, so an accent pill on a selected row is still
    // a distinct object.
    try testing.expect(ratio(theme.accent, theme.accentSoft()) >= caption_min);
}

test "accent decoration clears the 3:1 non-text threshold" {
    const theme = tokens.default_theme;
    // The focus ring, the tab indicator, the plan card's accent bar, the
    // slider's filled track: non-text, so 3:1.
    try testing.expect(ratio(theme.accent, theme.surface_0) >= caption_min);
    try testing.expect(ratio(theme.accent, theme.surface_2) >= caption_min);
    // The checkbox/radio tick is `surface_0` drawn on the accent.
    try testing.expect(ratio(theme.surface_0, theme.accent) >= caption_min);
}

test "the accent surfaces stay derived from one hex" {
    // A custom theme names one blue and gets the whole family, so a downstream
    // app cannot end up with an accent and surfaces that disagree.
    var theme = tokens.default_theme;
    theme.accent = .fromHex("#4DA6FF");
    try testing.expectEqual(color.mix(theme.accent, theme.surface_0, tokens.soft_mix), theme.accentSoft());
    try testing.expectEqual(color.mix(theme.accent, .white, tokens.on_soft_mix), theme.accentOnSoft());

    // …and an explicit override still wins.
    theme.accent_soft = .fromHex("#123456");
    try testing.expectEqual(Color.fromHex("#123456"), theme.accentSoft());
}
