const dvui = @import("dvui");
const tokens = @import("../tokens.zig");

/// Find a font using the theme's font family in pixel size mode.
/// `ds.font(theme.font_size_md)` → regular weight
pub fn font(size_px: u16) dvui.Font {
    return dvui.Font.find(.{ .family = tokens.current.font_family, .size = size_px, .size_mode = .pixel });
}

/// Find a light font using the theme's font family in pixel size mode.
/// `ds.fontLight(theme.font_size_md)` → light weight
pub fn fontLight(size_px: u16) dvui.Font {
    return dvui.Font.find(.{ .family = tokens.current.font_family, .size = size_px, .weight = .light, .size_mode = .pixel });
}

/// Find a medium font using the theme's font family in pixel size mode.
/// `ds.fontMedium(theme.font_size_md)` → medium weight
pub fn fontMedium(size_px: u16) dvui.Font {
    return dvui.Font.find(.{ .family = tokens.current.font_family, .size = size_px, .weight = .medium, .size_mode = .pixel });
}

/// Find a semibold font using the theme's font family in pixel size mode.
/// `ds.fontSemibold(theme.font_size_md)` → semibold weight
pub fn fontSemibold(size_px: u16) dvui.Font {
    return dvui.Font.find(.{ .family = tokens.current.font_family, .size = size_px, .weight = .semi_bold, .size_mode = .pixel });
}

/// Find a bold font using the theme's font family in pixel size mode.
/// `ds.fontBold(theme.font_size_md)` → bold weight
pub fn fontBold(size_px: u16) dvui.Font {
    return dvui.Font.find(.{ .family = tokens.current.font_family, .size = size_px, .weight = .bold, .size_mode = .pixel });
}
