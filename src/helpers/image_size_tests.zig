//! The picture-size rule's arithmetic, with no window: one image pixel to one
//! physical pixel, and never upscaled when it is fitted into less room.
const std = @import("std");
const image_size = @import("image_size.zig");

test "atScale: a picture's logical size is its pixel size over the scale" {
    const at_175 = image_size.atScale(.{ .w = 350, .h = 175 }, 1.75);
    try std.testing.expectApproxEqAbs(@as(f32, 200), at_175.w, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 100), at_175.h, 0.001);
    const at_one = image_size.atScale(.{ .w = 350, .h = 175 }, 1);
    try std.testing.expectEqual(@as(f32, 350), at_one.w);
    const no_window = image_size.atScale(.{ .w = 350, .h = 175 }, 0);
    try std.testing.expectEqual(@as(f32, 350), no_window.w);
}

test "fitWidth: narrower only, keeping the aspect ratio" {
    const fitted = image_size.fitWidth(.{ .w = 1280, .h = 720 }, 320);
    try std.testing.expectEqual(@as(f32, 320), fitted.w);
    try std.testing.expectEqual(@as(f32, 180), fitted.h);
    const small = image_size.fitWidth(.{ .w = 100, .h = 60 }, 320);
    try std.testing.expectEqual(@as(f32, 100), small.w);
    try std.testing.expectEqual(@as(f32, 60), small.h);
}

test "fitInside: the tighter side wins and nothing grows" {
    const square = image_size.fitInside(.{ .w = 800, .h = 800 }, .{ .w = 400, .h = 200 });
    try std.testing.expectEqual(@as(f32, 200), square.w);
    try std.testing.expectEqual(@as(f32, 200), square.h);
    const small = image_size.fitInside(.{ .w = 50, .h = 40 }, .{ .w = 400, .h = 200 });
    try std.testing.expectEqual(@as(f32, 50), small.w);
    try std.testing.expectEqual(@as(f32, 40), small.h);
    const unbounded_height = image_size.fitInside(.{ .w = 800, .h = 400 }, .{ .w = 400, .h = 0 });
    try std.testing.expectEqual(@as(f32, 400), unbounded_height.w);
    try std.testing.expectEqual(@as(f32, 200), unbounded_height.h);
}
