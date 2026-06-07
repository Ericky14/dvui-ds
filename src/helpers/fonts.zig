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
