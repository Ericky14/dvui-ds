/// Color interpolation and comparison helpers.
const std = @import("std");
const dvui = @import("dvui");

pub const Color = dvui.Color;

/// Linearly interpolate between two colors by factor t (0..1).
pub fn lerpColor(a: Color, b: Color, t: f32) Color {
    const tc = std.math.clamp(t, 0.0, 1.0);
    return .{
        .r = @intFromFloat(std.math.lerp(@as(f32, @floatFromInt(a.r)), @as(f32, @floatFromInt(b.r)), tc)),
        .g = @intFromFloat(std.math.lerp(@as(f32, @floatFromInt(a.g)), @as(f32, @floatFromInt(b.g)), tc)),
        .b = @intFromFloat(std.math.lerp(@as(f32, @floatFromInt(a.b)), @as(f32, @floatFromInt(b.b)), tc)),
        .a = @intFromFloat(std.math.lerp(@as(f32, @floatFromInt(a.a)), @as(f32, @floatFromInt(b.a)), tc)),
    };
}
