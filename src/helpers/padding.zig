const dvui = @import("dvui");

/// Uniform padding on all sides.
/// `ds.padding(8)` → 8px all around
pub fn padding(all: f32) dvui.Rect {
    return .{ .x = all, .y = all, .w = all, .h = all };
}

/// Symmetric padding: horizontal (left+right) and vertical (top+bottom).
/// `ds.paddingXY(16, 8)` → 16px left/right, 8px top/bottom
pub fn paddingXY(horizontal: f32, vertical: f32) dvui.Rect {
    return .{ .x = horizontal, .y = vertical, .w = horizontal, .h = vertical };
}

/// Per-edge padding in CSS order: top, right, bottom, left.
/// `ds.paddingEach(8, 16, 8, 16)` → top 8, right 16, bottom 8, left 16
pub fn paddingEach(top: f32, right: f32, bottom: f32, left: f32) dvui.Rect {
    return .{ .x = left, .y = top, .w = right, .h = bottom };
}
