const std = @import("std");
const chip_mod = @import("chip.zig");
const tokens = @import("../tokens.zig");
const pixels = @import("../helpers/pixels.zig");
const icons = @import("../icons.zig");
const ds = @import("../ds.zig");

test "chip defaults to rest with no tooltip" {
    const entry = chip_mod.chip(@src(), "undo", icons.undo);
    try std.testing.expect(entry.icon_source.kind == .named_icon);
    try std.testing.expectEqual(chip_mod.ChipState.rest, entry.chip_state);
    try std.testing.expect(entry.tooltip_text == null);
    try std.testing.expectEqual(@as(usize, 0), entry.id_extra);
}

test "chip setters copy-on-set" {
    const base = chip_mod.chip(@src(), "undo", icons.undo);
    const styled = base.state(.current).tooltip("Your edit").tag("history.3").tagIcon("history.3.icon").idExtra(3);
    try std.testing.expectEqual(chip_mod.ChipState.rest, base.chip_state);
    try std.testing.expectEqual(chip_mod.ChipState.current, styled.chip_state);
    try std.testing.expectEqualStrings("Your edit", styled.tooltip_text.?);
    try std.testing.expectEqualStrings("history.3", styled.tag_val.?);
    try std.testing.expectEqualStrings("history.3.icon", styled.tag_icon.?);
    try std.testing.expectEqual(@as(usize, 3), styled.id_extra);
}

test "the chip meets the 24px minimum hit target" {
    try std.testing.expect(tokens.default_theme.chrome_chip_size >= 24);
}

test "chip geometry is whole physical pixels and symmetric at 1.0, 1.75 and 2.0" {
    // Padding is applied on both sides, so an unsnapped padding puts the icon
    // half a pixel off centre and the chip's own edge half a pixel off the grid.
    for ([_]f32{ 1.0, 1.75, 2.0 }) |scale| {
        const metrics = chip_mod.chipMetrics(scale);
        try std.testing.expect(pixels.isSnapped(metrics.outer, scale));
        try std.testing.expect(pixels.isSnapped(metrics.inset, scale));
        try std.testing.expect(pixels.isSnapped(metrics.content, scale));
        // The content sits exactly between two equal paddings.
        try std.testing.expectApproxEqAbs(
            metrics.outer,
            metrics.content + 2 * metrics.inset,
            0.0001,
        );
        try std.testing.expect(metrics.content > 0);
    }
}

test "the chip is the size the theme asked for, in physical pixels" {
    const theme = tokens.default_theme;
    for ([_]f32{ 1.0, 1.75, 2.0 }) |scale| {
        const metrics = chip_mod.chipMetrics(scale);
        const physical = metrics.outer * scale;
        try std.testing.expectApproxEqAbs(@round(theme.chrome_chip_size * scale), physical, 0.0001);
    }
}

test "the on chips are the solid accent with dark glyphs" {
    const theme = tokens.current;
    // A held tool and the current mode are the loudest thing in a toolbar, so
    // they get the accent itself rather than a tonal wash of it — the same
    // treatment `button(.filled)` and `pill(.accent)` use, so a strip of chips
    // and the Send button read as one family.
    for ([_]chip_mod.ChipState{ .active, .current }) |on| {
        const colors = chip_mod.stateColors(on);
        try std.testing.expectEqual(@as(u8, 255), colors.fill.a);
        try std.testing.expectEqual(theme.accent, colors.fill);
        try std.testing.expectEqual(theme.accentHover(), colors.fill_hover);
        try std.testing.expectEqual(theme.accentPressed(), colors.fill_press);
        try std.testing.expectEqual(theme.surface_0, colors.icon);
        // An 11 px glyph needs 3:1; this pairing is well past it.
        try std.testing.expect(ds.contrastRatio(colors.icon, colors.fill) >= 4.5);
        try std.testing.expect(ds.contrastRatio(colors.icon, colors.fill_hover) >= 4.5);
        try std.testing.expect(ds.contrastRatio(colors.icon, colors.fill_press) >= 4.5);
    }
}

test "an off chip stays neutral so the on chips are the only blue in the strip" {
    const theme = tokens.current;
    for ([_]chip_mod.ChipState{ .rest, .faded }) |off| {
        const colors = chip_mod.stateColors(off);
        try std.testing.expectEqual(@as(u8, 0), colors.fill.a);
        try std.testing.expectEqual(theme.text_secondary, colors.icon);
    }
}

test "the current ring reads against the solid fill it is drawn on" {
    const theme = tokens.current;
    // `.current` keeps its ring, and on a solid accent chip an accent ring
    // would be invisible. It is drawn in the same dark ink as the glyph.
    const ring = chip_mod.currentRingColor();
    try std.testing.expectEqual(theme.surface_0, ring);
    try std.testing.expect(ds.contrastRatio(ring, chip_mod.stateColors(.current).fill) >= 3.0);
}
