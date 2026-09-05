const std = @import("std");
const pill_mod = @import("pill.zig");
const tokens = @import("../tokens.zig");
const pixels = @import("../helpers/pixels.zig");
const icons = @import("../icons.zig");

test "pill defaults to a neutral text-only readout" {
    const readout = pill_mod.pill(@src(), "60 fps");
    try std.testing.expectEqual(pill_mod.PillTone.neutral, readout.pill_tone);
    try std.testing.expect(readout.icon_source == null);
    try std.testing.expect(!readout.is_mono);
    try std.testing.expect(readout.radius_val == null);
}

test "pill setters copy-on-set" {
    const base = pill_mod.pill(@src(), "Ground · 2");
    const styled = base.tone(.accent).icon("box", icons.box).mono(true).radius(6).tag("selection").tagLabel("selection.label").idExtra(2);
    try std.testing.expectEqual(pill_mod.PillTone.neutral, base.pill_tone);
    try std.testing.expect(base.icon_source == null);
    try std.testing.expectEqual(pill_mod.PillTone.accent, styled.pill_tone);
    try std.testing.expect(styled.icon_source != null);
    try std.testing.expectEqualStrings("box", styled.icon_source.?.kind.named_icon.name);
    try std.testing.expect(styled.is_mono);
    try std.testing.expectEqual(@as(f32, 6), styled.radius_val.?);
    try std.testing.expectEqualStrings("selection", styled.tag_val.?);
    try std.testing.expectEqualStrings("selection.label", styled.tag_label.?);
    try std.testing.expectEqual(@as(usize, 2), styled.id_extra);
}

test "pill geometry is whole physical pixels at 1.0, 1.75 and 2.0" {
    for ([_]f32{ 1.0, 1.75, 2.0 }) |scale| {
        const metrics = pill_mod.pillMetrics(scale);
        try std.testing.expect(pixels.isSnapped(metrics.height, scale));
        try std.testing.expect(pixels.isSnapped(metrics.padding_x, scale));
        try std.testing.expect(pixels.isSnapped(metrics.gap, scale));
        // Both round ends are the same width, so the label sits centred.
        try std.testing.expect(pixels.isSnapped(metrics.padding_x * 2, scale));
    }
}

test "a pill is shorter than a chip, so a mixed row reads as chrome not buttons" {
    const theme = tokens.default_theme;
    try std.testing.expect(theme.chrome_pill_height < theme.chrome_chip_size);
    // …but still tall enough to hold the caption font comfortably.
    try std.testing.expect(theme.chrome_pill_height >= @as(f32, @floatFromInt(theme.font_size_sm)) + 8);
}

test "chrome heights sit on the 4px grid" {
    const theme = tokens.default_theme;
    for ([_]f32{
        theme.chrome_titlebar_height,
        theme.chrome_toolbar_height,
        theme.chrome_status_height,
        theme.chrome_chip_size,
        theme.chrome_pill_height,
    }) |value| {
        try std.testing.expectApproxEqAbs(@as(f32, 0), @mod(value, 4), 0.0001);
    }
}
