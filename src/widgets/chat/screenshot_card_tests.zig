/// Tests for the screenshot card builder and its fit-to-width sizing.
const std = @import("std");
const widget = @import("screenshot_card.zig");
const Source = @import("../../source.zig");

const rgba = [_]u8{ 0, 0, 0, 255 };

test "screenshotCard: builder defaults" {
    const card = widget.screenshotCard(@src(), "after the change", Source.pixels(&rgba, 1, 1));
    try std.testing.expectEqualStrings("after the change", card.caption);
    try std.testing.expect(card.image.isImage());
    try std.testing.expectEqual(@as(f32, 420), card.max_width);
    try std.testing.expectEqual(@as(usize, 0), card.id_extra);
}

test "screenshotCard: setters copy instead of mutating" {
    const base = widget.screenshotCard(@src(), "after", Source.pixels(&rgba, 1, 1));
    const narrow = base.maxWidth(200).idExtra(2);
    try std.testing.expectEqual(@as(f32, 420), base.max_width);
    try std.testing.expectEqual(@as(usize, 0), base.id_extra);
    try std.testing.expectEqual(@as(f32, 200), narrow.max_width);
    try std.testing.expectEqual(@as(usize, 2), narrow.id_extra);
}

test "fitSize: wide images shrink to the cap keeping their aspect" {
    const fitted = widget.fitSize(.{ .w = 1280, .h = 720 }, 320);
    try std.testing.expectEqual(@as(f32, 320), fitted.w);
    try std.testing.expectEqual(@as(f32, 180), fitted.h);
}

test "fitSize: small images keep their natural size" {
    const fitted = widget.fitSize(.{ .w = 100, .h = 60 }, 320);
    try std.testing.expectEqual(@as(f32, 100), fitted.w);
    try std.testing.expectEqual(@as(f32, 60), fitted.h);
}

test "fitSize: degenerate inputs pass through" {
    const zero = widget.fitSize(.{ .w = 0, .h = 0 }, 320);
    try std.testing.expectEqual(@as(f32, 0), zero.w);
    const no_cap = widget.fitSize(.{ .w = 800, .h = 600 }, 0);
    try std.testing.expectEqual(@as(f32, 800), no_cap.w);
}
