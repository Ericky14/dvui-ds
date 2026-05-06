/// Tests for animation utility functions (lerpColor, Color.eql).
const std = @import("std");
const utils = @import("utils.zig");

const Color = utils.Color;

// ─── Color.eql tests ─────────────────────────────────────────────────────────

test "Color.eql same colors" {
    const a = Color{ .r = 100, .g = 200, .b = 50, .a = 255 };
    try std.testing.expect(a.eql(a));
}

test "Color.eql different colors" {
    const a = Color{ .r = 100, .g = 200, .b = 50, .a = 255 };
    const b = Color{ .r = 101, .g = 200, .b = 50, .a = 255 };
    try std.testing.expect(!a.eql(b));
}

test "Color.eql differs only in alpha" {
    const a = Color{ .r = 100, .g = 200, .b = 50, .a = 255 };
    const b = Color{ .r = 100, .g = 200, .b = 50, .a = 254 };
    try std.testing.expect(!a.eql(b));
}

test "Color.eql transparent" {
    try std.testing.expect(Color.transparent.eql(Color.transparent));
}

// ─── lerpColor tests ─────────────────────────────────────────────────────────

test "lerpColor t=0 returns from" {
    const a = Color{ .r = 0, .g = 0, .b = 0, .a = 255 };
    const b = Color{ .r = 255, .g = 255, .b = 255, .a = 0 };
    const result = utils.lerpColor(a, b, 0.0);
    try std.testing.expectEqual(a.r, result.r);
    try std.testing.expectEqual(a.g, result.g);
    try std.testing.expectEqual(a.b, result.b);
    try std.testing.expectEqual(a.a, result.a);
}

test "lerpColor t=1 returns to" {
    const a = Color{ .r = 0, .g = 0, .b = 0, .a = 255 };
    const b = Color{ .r = 255, .g = 255, .b = 255, .a = 0 };
    const result = utils.lerpColor(a, b, 1.0);
    try std.testing.expectEqual(b.r, result.r);
    try std.testing.expectEqual(b.g, result.g);
    try std.testing.expectEqual(b.b, result.b);
    try std.testing.expectEqual(b.a, result.a);
}

test "lerpColor t=0.5 midpoint" {
    const a = Color{ .r = 0, .g = 0, .b = 0, .a = 0 };
    const b = Color{ .r = 200, .g = 100, .b = 50, .a = 200 };
    const result = utils.lerpColor(a, b, 0.5);
    try std.testing.expectEqual(@as(u8, 100), result.r);
    try std.testing.expectEqual(@as(u8, 50), result.g);
    try std.testing.expectEqual(@as(u8, 25), result.b);
    try std.testing.expectEqual(@as(u8, 100), result.a);
}

test "lerpColor clamps t below 0" {
    const a = Color{ .r = 100, .g = 100, .b = 100, .a = 100 };
    const b = Color{ .r = 200, .g = 200, .b = 200, .a = 200 };
    const result = utils.lerpColor(a, b, -0.5);
    try std.testing.expectEqual(a.r, result.r);
    try std.testing.expectEqual(a.a, result.a);
}

test "lerpColor clamps t above 1" {
    const a = Color{ .r = 100, .g = 100, .b = 100, .a = 100 };
    const b = Color{ .r = 200, .g = 200, .b = 200, .a = 200 };
    const result = utils.lerpColor(a, b, 1.5);
    try std.testing.expectEqual(b.r, result.r);
    try std.testing.expectEqual(b.a, result.a);
}

test "lerpColor same color returns same" {
    const c = Color{ .r = 42, .g = 128, .b = 200, .a = 180 };
    const result = utils.lerpColor(c, c, 0.7);
    try std.testing.expect(c.eql(result));
}
