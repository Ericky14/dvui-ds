const std = @import("std");
const dvui = @import("dvui");

const Color = dvui.Color;

/// Set a color's alpha to a raw u8 value (0–255).
/// `ds.alpha(theme.accent, theme.opacity_fill_rest)` → accent at 12% opacity
pub fn alpha(c: Color, a: u8) Color {
    return .{ .r = c.r, .g = c.g, .b = c.b, .a = a };
}

/// Apply an opacity multiplier to all subsequent draws until restored.
/// Returns a handle — call `.restore()` when done (typically via `defer`).
///
/// ```
/// const opacity = ds.withOpacity(0.4);
/// defer opacity.restore();
/// ds.label(@src(), "dimmed").draw();
/// ```
pub fn withOpacity(mult: f32) Opacity {
    return .{ .previous = dvui.alpha(mult) };
}

pub const Opacity = struct {
    previous: f32,

    pub fn restore(self: Opacity) void {
        dvui.alphaSet(self.previous);
    }
};

/// Blend `a` towards `b` by `t` (0 = all `a`, 1 = all `b`), ignoring alpha.
///
/// The design system derives its accent surfaces this way rather than by
/// stacking a translucent accent over the app background: the composite of a
/// 16 % accent over a near-black surface lands at about 2 % luminance, which is
/// navy however bright the accent was — the mix keeps the luminance the
/// designer asked for.
pub fn mix(a: Color, b: Color, t: f32) Color {
    const amount = std.math.clamp(t, 0, 1);
    return .{
        .r = channelMix(a.r, b.r, amount),
        .g = channelMix(a.g, b.g, amount),
        .b = channelMix(a.b, b.b, amount),
        .a = a.a,
    };
}

fn channelMix(from: u8, to: u8, t: f32) u8 {
    const value = @as(f32, @floatFromInt(from)) * (1 - t) + @as(f32, @floatFromInt(to)) * t;
    return @intFromFloat(std.math.clamp(@round(value), 0, 255));
}

/// WCAG 2.1 relative luminance.
pub fn relativeLuminance(color: Color) f32 {
    return 0.2126 * linearize(color.r) + 0.7152 * linearize(color.g) + 0.0722 * linearize(color.b);
}

fn linearize(channel: u8) f32 {
    const value = @as(f32, @floatFromInt(channel)) / 255.0;
    if (value <= 0.04045) return value / 12.92;
    return std.math.pow(f32, (value + 0.055) / 1.055, 2.4);
}

/// WCAG 2.1 contrast ratio between two opaque colours, 1.0 … 21.0.
///
/// The design system's thresholds: **4.5** for body-size text, **3.0** for the
/// 11 px captions and for icons and other non-text marks. Tokens that carry a
/// pairing — accent text on an accent surface, a label on a fill — are asserted
/// against these in `tokens_contrast_tests.zig`, so a palette change cannot
/// quietly drop below them.
pub fn contrastRatio(a: Color, b: Color) f32 {
    const la = relativeLuminance(a);
    const lb = relativeLuminance(b);
    const lighter = @max(la, lb);
    const darker = @min(la, lb);
    return (lighter + 0.05) / (darker + 0.05);
}

test "contrast ratio matches the WCAG reference points" {
    const black: Color = .{ .r = 0, .g = 0, .b = 0 };
    const white: Color = .{ .r = 255, .g = 255, .b = 255 };
    try std.testing.expectApproxEqAbs(@as(f32, 21), contrastRatio(black, white), 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 1), contrastRatio(white, white), 0.001);
    // Symmetric, and mid grey against white is the familiar 3.98.
    const grey: Color = .{ .r = 128, .g = 128, .b = 128 };
    try std.testing.expectApproxEqAbs(contrastRatio(grey, white), contrastRatio(white, grey), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 3.95), contrastRatio(grey, white), 0.05);
}

test "mix walks from one colour to the other and clamps outside" {
    const a: Color = .{ .r = 0, .g = 0, .b = 0 };
    const b: Color = .{ .r = 200, .g = 100, .b = 50 };
    try std.testing.expectEqual(@as(u8, 0), mix(a, b, 0).r);
    try std.testing.expectEqual(@as(u8, 200), mix(a, b, 1).r);
    try std.testing.expectEqual(@as(u8, 100), mix(a, b, 0.5).r);
    try std.testing.expectEqual(@as(u8, 50), mix(a, b, 0.5).g);
    // Out of range is clamped, not wrapped.
    try std.testing.expectEqual(@as(u8, 0), mix(a, b, -1).r);
    try std.testing.expectEqual(@as(u8, 200), mix(a, b, 2).r);
    // Alpha comes from the base colour, so mixing a surface keeps it opaque.
    const translucent: Color = .{ .r = 10, .g = 10, .b = 10, .a = 128 };
    try std.testing.expectEqual(@as(u8, 128), mix(translucent, b, 0.5).a);
}
