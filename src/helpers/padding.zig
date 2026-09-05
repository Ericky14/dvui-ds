//! Padding and margin, rounded to whole physical pixels.
//!
//! Every ds inset goes through these three helpers, and every one of them
//! snaps: an inset is what positions everything after it, so a 6 px pad that
//! becomes 10.5 physical px at 175 % puts the widget's own edge — and each
//! sibling's, all the way down the row — on a half pixel, which is a grey line
//! where a crisp one was meant. Snapping here fixes the whole design system in
//! one place instead of at every call site. At 1.0 and 2.0 whole logical values
//! are already whole physical ones, so nothing moves.

const dvui = @import("dvui");
const pixels = @import("pixels.zig");

/// Uniform padding on all sides.
/// `ds.padding(8)` → 8px all around
pub fn padding(all: f32) dvui.Rect {
    const snapped = pixels.snapPx(all, pixels.pixelScale());
    return .{ .x = snapped, .y = snapped, .w = snapped, .h = snapped };
}

/// Symmetric padding: horizontal (left+right) and vertical (top+bottom).
/// `ds.paddingXY(16, 8)` → 16px left/right, 8px top/bottom
pub fn paddingXY(horizontal: f32, vertical: f32) dvui.Rect {
    const scale = pixels.pixelScale();
    const across = pixels.snapPx(horizontal, scale);
    const down = pixels.snapPx(vertical, scale);
    return .{ .x = across, .y = down, .w = across, .h = down };
}

/// Per-edge padding in CSS order: top, right, bottom, left.
/// `ds.paddingEach(8, 16, 8, 16)` → top 8, right 16, bottom 8, left 16
pub fn paddingEach(top: f32, right: f32, bottom: f32, left: f32) dvui.Rect {
    const scale = pixels.pixelScale();
    return .{
        .x = pixels.snapPx(left, scale),
        .y = pixels.snapPx(top, scale),
        .w = pixels.snapPx(right, scale),
        .h = pixels.snapPx(bottom, scale),
    };
}

/// A uniform border, snapped to whole physical pixels and never thinner than
/// one. `ds.border(theme.border_width)` — see `pixels.borderPx` for why an
/// unrounded border is worse than an unrounded padding.
pub fn border(logical: f32) dvui.Rect {
    const width = pixels.borderPx(logical, pixels.pixelScale());
    return .{ .x = width, .y = width, .w = width, .h = width };
}
