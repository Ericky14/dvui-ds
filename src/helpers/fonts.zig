const std = @import("std");
const dvui = @import("dvui");
const tokens = @import("../tokens.zig");

/// Find a font using the theme's font family in pixel size mode.
/// `ds.font(theme.font_size_md)` → regular weight
pub fn font(size_px: u16) dvui.Font {
    return dvui.Font.find(.{ .family = tokens.current.font_family, .size = size_px, .size_mode = .pixel });
}

/// Light weight. NOTE: Geist Light isn't embedded (only Regular/Medium/Bold are),
/// so this maps to the regular weight rather than logging a fallback every frame.
/// Embed `Geist-Light.ttf` in tokens.geist_fonts to enable the true weight.
pub fn fontLight(size_px: u16) dvui.Font {
    return font(size_px);
}

/// Find a medium font using the theme's font family in pixel size mode.
/// `ds.fontMedium(theme.font_size_md)` → medium weight
pub fn fontMedium(size_px: u16) dvui.Font {
    return dvui.Font.find(.{ .family = tokens.current.font_family, .size = size_px, .weight = .medium, .size_mode = .pixel });
}

/// Semibold weight. NOTE: Geist SemiBold isn't embedded (only Regular/Medium/Bold
/// are), so this maps to the bold weight (the nearest available) rather than
/// logging a fallback every frame. Embed `Geist-SemiBold.ttf` in
/// tokens.geist_fonts to enable the true weight.
pub fn fontSemibold(size_px: u16) dvui.Font {
    return fontBold(size_px);
}

/// Find a bold font using the theme's font family in pixel size mode.
/// `ds.fontBold(theme.font_size_md)` → bold weight
pub fn fontBold(size_px: u16) dvui.Font {
    return dvui.Font.find(.{ .family = tokens.current.font_family, .size = size_px, .weight = .bold, .size_mode = .pixel });
}

/// Find a monospace font using the theme's mono family (Geist Mono) in pixel
/// size mode. This is what `dvuiTheme().font_mono` — and therefore
/// `dvui.Font.theme(.mono)` and the label `.mono` FontToken — resolve to.
/// `ds.fontMono(theme.font_size_md)` → code blocks, inline code, tool-card names
pub fn fontMono(size_px: u16) dvui.Font {
    return dvui.Font.find(.{ .family = tokens.current.font_family_mono, .size = size_px, .size_mode = .pixel });
}

/// Find a medium-weight monospace font using the theme's mono family in pixel
/// size mode. Geist Mono Medium is embedded, so `.withWeight(.medium)` on the
/// mono font resolves to a real face instead of dvui's nearest-weight fallback.
/// `ds.fontMonoMedium(theme.font_size_sm)` → emphasised code labels (plan steps, tool names)
pub fn fontMonoMedium(size_px: u16) dvui.Font {
    return dvui.Font.find(.{ .family = tokens.current.font_family_mono, .size = size_px, .weight = .medium, .size_mode = .pixel });
}

test "mono helpers resolve to the theme's mono family, not the sans family" {
    const mono_regular = fontMono(13);
    try std.testing.expectEqualStrings(tokens.current.font_family_mono, mono_regular.familyName());
    try std.testing.expect(!std.mem.eql(u8, tokens.current.font_family, mono_regular.familyName()));
    try std.testing.expectEqual(dvui.Font.Weight.normal, mono_regular.weight);
    try std.testing.expectEqual(dvui.Font.SizeMode.pixel, mono_regular.size_mode);

    const mono_medium = fontMonoMedium(11);
    try std.testing.expectEqualStrings(tokens.current.font_family_mono, mono_medium.familyName());
    try std.testing.expectEqual(dvui.Font.Weight.medium, mono_medium.weight);
    try std.testing.expectEqual(@as(f32, 11), mono_medium.size);
}

test "every embedded face the mono helpers can ask for is actually embedded" {
    // If someone drops a Mono weight from tokens.geist_fonts, dvui would silently fall
    // back to the nearest weight and log every frame — catch it here instead.
    var have_regular = false;
    var have_medium = false;
    for (tokens.embeddedFonts()) |source| {
        if (!std.mem.eql(u8, source.familyName(), tokens.current.font_family_mono)) continue;
        switch (source.weight) {
            .normal => have_regular = true,
            .medium => have_medium = true,
            else => {},
        }
    }
    try std.testing.expect(have_regular);
    try std.testing.expect(have_medium);
}
