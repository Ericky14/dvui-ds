const std = @import("std");
const dvui = @import("dvui");
const tokens = @import("../tokens.zig");

/// The embedded faces' line box — hhea ascender + descender over the em, the
/// height dvui gives one line of text: 1005 + 295 of 1000 units for Geist and
/// Geist Mono alike (a test reads it back from the TTF bytes).
pub const line_box_em: f32 = 1.3;

/// **The pitch between two lines of a paragraph at `size_px`**: the type
/// scale's own line height for a size on it (`Theme.line_height_*`), else
/// 1.5 × the size rounded up to the 4 px grid.
pub fn lineHeight(size_px: u16) f32 {
    const theme = tokens.current;
    const steps = [_]struct { u16, f32 }{
        .{ theme.font_size_xs, theme.line_height_xs },
        .{ theme.font_size_sm, theme.line_height_sm },
        .{ theme.font_size_md, theme.line_height_md },
        .{ theme.font_size_lg, theme.line_height_lg },
        .{ theme.font_size_xl, theme.line_height_xl },
        .{ theme.font_size_2xl, theme.line_height_2xl },
    };
    for (steps) |step| if (step[0] == size_px) return step[1];
    return @ceil(@as(f32, @floatFromInt(size_px)) * 1.5 / 4) * 4;
}

/// dvui's `line_height_factor` that spaces lines `lineHeight(size_px)`
/// apart: dvui's pitch is the line box times the factor. Never under 1 — a
/// factor below shrinks every line, the first included, and cuts descenders.
fn lineFactor(size_px: u16) f32 {
    const box = @as(f32, @floatFromInt(@max(size_px, 1))) * line_box_em;
    return @max(1, lineHeight(size_px) / box);
}

/// Find a font using the theme's font family in pixel size mode, its lines
/// `lineHeight(size_px)` apart.
/// `ds.font(theme.font_size_md)` → regular weight
pub fn font(size_px: u16) dvui.Font {
    return dvui.Font.find(.{ .family = tokens.current.font_family, .size = size_px, .size_mode = .pixel, .line_height_factor = lineFactor(size_px) });
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
    return dvui.Font.find(.{ .family = tokens.current.font_family, .size = size_px, .weight = .medium, .size_mode = .pixel, .line_height_factor = lineFactor(size_px) });
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
    return dvui.Font.find(.{ .family = tokens.current.font_family, .size = size_px, .weight = .bold, .size_mode = .pixel, .line_height_factor = lineFactor(size_px) });
}

/// Find a monospace font using the theme's mono family (Geist Mono) in pixel
/// size mode. This is what `dvuiTheme().font_mono` — and therefore
/// `dvui.Font.theme(.mono)` and the label `.mono` FontToken — resolve to.
/// `ds.fontMono(theme.font_size_md)` → code blocks, inline code, tool-card names
pub fn fontMono(size_px: u16) dvui.Font {
    return dvui.Font.find(.{ .family = tokens.current.font_family_mono, .size = size_px, .size_mode = .pixel, .line_height_factor = lineFactor(size_px) });
}

/// Find a medium-weight monospace font using the theme's mono family in pixel
/// size mode. Geist Mono Medium is embedded, so `.withWeight(.medium)` on the
/// mono font resolves to a real face instead of dvui's nearest-weight fallback.
/// `ds.fontMonoMedium(theme.font_size_sm)` → emphasised code labels (plan steps, tool names)
pub fn fontMonoMedium(size_px: u16) dvui.Font {
    return dvui.Font.find(.{ .family = tokens.current.font_family_mono, .size = size_px, .weight = .medium, .size_mode = .pixel, .line_height_factor = lineFactor(size_px) });
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

test "the type scale is 11 / 12 / 13 / 15 / 18 / 22, each with a line height on the 4 px grid" {
    const theme = tokens.default_theme;
    const sizes = [_]u16{ theme.font_size_xs, theme.font_size_sm, theme.font_size_md, theme.font_size_lg, theme.font_size_xl, theme.font_size_2xl };
    try std.testing.expectEqualSlices(u16, &.{ 11, 12, 13, 15, 18, 22 }, &sizes);
    const lines = [_]f32{ theme.line_height_xs, theme.line_height_sm, theme.line_height_md, theme.line_height_lg, theme.line_height_xl, theme.line_height_2xl };
    for (sizes, lines) |size, line| {
        // whole physical pixels at 1.25, 1.5, 1.75 and 2.0, and room for the
        // letters: never under the font's own line box
        try std.testing.expectEqual(@as(f32, 0), @mod(line, 4));
        try std.testing.expect(line >= @as(f32, @floatFromInt(size)) * line_box_em - 1);
        try std.testing.expectEqual(line, lineHeight(size));
    }
    // A size off the scale gets 1.5 times itself, rounded up to the grid.
    try std.testing.expectEqual(@as(f32, 24), lineHeight(14));
    try std.testing.expectEqual(@as(f32, 40), lineHeight(26));
}

test "a font from the helpers spaces its lines by the scale's line height" {
    // dvui's pitch between two lines of a paragraph is the font's line box
    // (ascender + descender) times `line_height_factor`; the helpers choose
    // the factor that makes it the token.
    for ([_]u16{ 11, 12, 13, 15, 18, 22 }) |size| {
        inline for (.{ font, fontMedium, fontBold, fontMono, fontMonoMedium }) |helper| {
            const made = helper(size);
            const pitch = @as(f32, @floatFromInt(size)) * line_box_em * made.line_height_factor;
            try std.testing.expectApproxEqAbs(@max(lineHeight(size), @as(f32, @floatFromInt(size)) * line_box_em), pitch, 0.001);
        }
    }
}

test "the line box the factor is worked out from is the embedded faces' own" {
    // hhea ascender and descender over unitsPerEm, read from the TTF bytes,
    // for every face `dvuiTheme()` embeds.
    for (tokens.embeddedFonts()) |source| {
        const bytes = source.bytes;
        const head = tableOffset(bytes, "head").?;
        const hhea = tableOffset(bytes, "hhea").?;
        const units: f32 = @floatFromInt(std.mem.readInt(u16, bytes[head + 18 ..][0..2], .big));
        const ascender: f32 = @floatFromInt(std.mem.readInt(i16, bytes[hhea + 4 ..][0..2], .big));
        const descender: f32 = @floatFromInt(std.mem.readInt(i16, bytes[hhea + 6 ..][0..2], .big));
        try std.testing.expectApproxEqAbs(line_box_em, (ascender - descender) / units, 0.0001);
    }
}

/// Where the table tagged `tag` starts in a TrueType file, or null.
fn tableOffset(bytes: []const u8, tag: *const [4]u8) ?usize {
    const count = std.mem.readInt(u16, bytes[4..6], .big);
    for (0..count) |index| {
        const record = bytes[12 + index * 16 ..][0..16];
        if (std.mem.eql(u8, record[0..4], tag)) return std.mem.readInt(u32, record[8..12], .big);
    }
    return null;
}

test "once the theme is installed a label's line and its padding fit the control it sits in" {
    // A label is drawn inside a row of controls (28 px, `chrome_control_height`,
    // the `sm` size). dvui pads a label 6 on every side, which a 10 px line
    // fitted (13 + 12) and the body's 13 px line does not (16.9 + 12 = 28.9):
    // the row grew by a pixel and every control in it left its centre line.
    const saved = dvui.LabelWidget.defaults;
    defer dvui.LabelWidget.defaults = saved;
    @import("../ds.zig").init(tokens.default_theme);
    const theme = tokens.current;
    const padding = dvui.LabelWidget.defaults.paddingGet();
    for ([_]u16{ theme.font_size_xs, theme.font_size_sm, theme.font_size_md, theme.font_size_lg }) |size| {
        const line = @as(f32, @floatFromInt(size)) * line_box_em;
        errdefer std.debug.print("a {d} px label is {d:.1} + {d} + {d} tall, the control {d}\n", .{ size, line, padding.y, padding.h, theme.chrome_control_height });
        try std.testing.expect(line + padding.y + padding.h <= theme.chrome_control_height);
    }
    // across, a label keeps dvui's own 6
    try std.testing.expectEqual(@as(f32, 6), padding.x);
    try std.testing.expectEqual(@as(f32, 6), padding.w);
}
