/// Physical-pixel snapping — the arithmetic behind the design system's
/// alignment discipline.
///
/// Every ds length is authored in *logical* pixels and multiplied by the
/// window scale before it reaches the rasteriser. At 1.0 and 2.0 that lands on
/// whole physical pixels by accident; at 1.75 (the owner's display) it does
/// not, and a 1 px hairline becomes a 1.75 px smear that antialiases to grey on
/// one edge and to nothing on the other. Chrome — window borders, frame
/// hairlines, the glass edge highlight — is exactly the thing that shows it.
///
/// So chrome asks for a length that is guaranteed to come out whole:
///
/// ```zig
/// const scale = ds.pixelScale();
/// var frame = ds.windowFrame(@src()).draw(); // uses ds.hairline(scale) internally
/// const gutter = ds.snapPx(theme.space_sm, scale); // 8 logical px, whole physical
/// ```
const std = @import("std");
const dvui = @import("dvui");

/// The scale that turns logical pixels into physical pixels for whatever is
/// being drawn right now (window scale × any enclosing `dvui.ScaleWidget`).
/// Only valid inside a frame.
pub fn pixelScale() f32 {
    return dvui.parentGet().screenRectScale(dvui.Rect{}).s;
}

/// Round a logical length so it lands on a whole number of physical pixels.
/// Zero stays zero — a gap the designer asked to remove must not become 1 px.
///
/// `ds.snapPx(6, 1.75)` → 6.2857…, i.e. exactly 11 physical pixels.
pub fn snapPx(logical: f32, scale: f32) f32 {
    if (scale <= 0) return logical;
    const physical = @round(logical * scale);
    return physical / scale;
}

/// The logical length of a **1 physical pixel minimum** hairline at `scale`:
/// the thinnest line the display can draw without antialiasing it into a
/// gradient. Used for every border in the chrome language.
///
/// `ds.hairline(1.0)` → 1 (1 px) · `ds.hairline(1.75)` → 1.142… (2 px) ·
/// `ds.hairline(2.0)` → 1 (2 px)
pub fn hairline(scale: f32) f32 {
    if (scale <= 0) return 1;
    return @max(1, @round(scale)) / scale;
}

/// True when `logical` × `scale` is a whole number of physical pixels (within
/// float tolerance). The assertion the alignment tests make.
pub fn isSnapped(logical: f32, scale: f32) bool {
    const physical = logical * scale;
    return @abs(physical - @round(physical)) < 0.001;
}

test "snapPx lands on whole physical pixels at every scale" {
    for ([_]f32{ 1.0, 1.25, 1.5, 1.75, 2.0 }) |scale| {
        for ([_]f32{ 1, 2, 4, 6, 8, 12, 16, 20, 24, 28, 40 }) |logical| {
            try std.testing.expect(isSnapped(snapPx(logical, scale), scale));
        }
    }
}

test "snapPx leaves zero alone" {
    try std.testing.expectEqual(@as(f32, 0), snapPx(0, 1.75));
    try std.testing.expectEqual(@as(f32, 0), snapPx(0, 2.0));
}

test "hairline is one whole physical pixel or more, never zero" {
    try std.testing.expectEqual(@as(f32, 1), hairline(1.0) * 1.0);
    try std.testing.expectEqual(@as(f32, 2), hairline(1.75) * 1.75);
    try std.testing.expectEqual(@as(f32, 2), hairline(2.0) * 2.0);
    // A sub-1 scale still cannot ask for less than one physical pixel.
    try std.testing.expectEqual(@as(f32, 1), hairline(0.5) * 0.5);
}

test "a degenerate scale never divides by zero" {
    try std.testing.expectEqual(@as(f32, 8), snapPx(8, 0));
    try std.testing.expectEqual(@as(f32, 1), hairline(0));
}
