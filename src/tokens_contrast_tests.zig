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

// ── The status family ────────────────────────────────────────────────────────
//
// Danger, warning and success get tonal surfaces of their own, and they are
// deliberately *calmer* than the accent's. The accent marks the one thing you
// are meant to reach for, so `soft_mix` 0.56 makes a selected row read blue. A
// script error is not something to reach for: at panel size the same distance
// from the background reads as a saturated slab, and a column of two of them
// becomes the loudest thing on screen. Hence a separate `danger_soft_mix`, and
// the band below, which is what "a tint, not a slab" means as a number.

/// A status tint has to lift off the background enough to be a surface…
const status_lift_min: f32 = 1.6;
/// …and not so much that a panel-sized one reads as a slab.
const status_lift_max: f32 = 2.2;

fn statusBases(theme: tokens.Theme) [3]Color {
    return .{ theme.destructive, theme.warning, theme.success };
}

test "a status tonal surface is a tint, not a slab" {
    const theme = tokens.default_theme;
    for (statusBases(theme)) |base| {
        const soft = theme.statusSoft(base);
        const lift = ratio(soft, theme.surface_0);
        try testing.expect(lift >= status_lift_min);
        try testing.expect(lift <= status_lift_max);
        // Opaque: a wash whose colour depends on what happens to be behind it
        // goes pink over a bright render. Mixed, not alpha'd.
        try testing.expectEqual(@as(u8, 255), soft.a);
    }
}

test "the status family is calmer than the accent, by construction" {
    // The one number that keeps a red error card from competing with the blue
    // control the user is supposed to press.
    try testing.expect(tokens.danger_soft_mix > tokens.soft_mix);
    const theme = tokens.default_theme;
    try testing.expect(ratio(theme.accentSoft(), theme.surface_0) > ratio(theme.dangerSoft(), theme.surface_0));
}

test "status ink clears WCAG AA on its own tonal surface" {
    const theme = tokens.default_theme;
    for (statusBases(theme)) |base| {
        const soft = theme.statusSoft(base);
        const hover = theme.statusSoftHover(base);
        const ink = theme.onStatusSoft(base);
        try testing.expect(ratio(ink, soft) >= body_min);
        try testing.expect(ratio(ink, hover) >= body_min);
        // Primary text is an option on these surfaces too (an error card's
        // message is `text_primary`, not the danger colour).
        try testing.expect(ratio(theme.text_primary, soft) >= body_min);
        // Hover is a visible step, not a jump to another colour.
        const lift = color.relativeLuminance(hover) / color.relativeLuminance(soft);
        try testing.expect(lift > 1.10);
        try testing.expect(lift < 1.60);
    }
}

test "the status border and glyph read on the tint they sit on" {
    const theme = tokens.default_theme;
    for (statusBases(theme)) |base| {
        // The card's 1 px border and its status glyph are the base colour, and
        // both are non-text, so 3:1.
        try testing.expect(ratio(base, theme.statusSoft(base)) >= caption_min);
        try testing.expect(ratio(base, theme.surface_0) >= body_min);
    }
}

test "the named status accessors are the generic one" {
    const theme = tokens.default_theme;
    try testing.expectEqual(theme.statusSoft(theme.destructive), theme.dangerSoft());
    try testing.expectEqual(theme.statusSoftHover(theme.destructive), theme.dangerSoftHover());
    try testing.expectEqual(theme.onStatusSoft(theme.destructive), theme.onDangerSoft());
    try testing.expectEqual(theme.statusSoft(theme.warning), theme.warningSoft());
    try testing.expectEqual(theme.statusSoft(theme.success), theme.successSoft());
}

/// A panel-sized tint has to stay a tint: area is loudness.
const wash_lift_min: f32 = 1.15;
const wash_lift_max: f32 = 1.45;

test "a panel-sized status tint is calmer than a chip-sized one" {
    const theme = tokens.default_theme;
    for (statusBases(theme)) |base| {
        const wash = theme.statusWash(base);
        const lift = ratio(wash, theme.surface_0);
        try testing.expect(lift >= wash_lift_min);
        try testing.expect(lift <= wash_lift_max);
        try testing.expectEqual(@as(u8, 255), wash.a);
        // Strictly calmer than the chip-sized surface — that is the whole
        // reason it is a second constant.
        try testing.expect(lift < ratio(theme.statusSoft(base), theme.surface_0));
        // An error card's message is `text_primary` and its summary is
        // `text_secondary`; both have to hold on the tint.
        try testing.expect(ratio(theme.text_primary, wash) >= body_min);
        try testing.expect(ratio(theme.text_secondary, wash) >= body_min);
        // The card's 1 px border and its glyph are the base colour: non-text.
        try testing.expect(ratio(base, wash) >= caption_min);
    }
    try testing.expect(tokens.danger_wash_mix > tokens.danger_soft_mix);
}
