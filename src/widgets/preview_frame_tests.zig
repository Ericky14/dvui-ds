const std = @import("std");
const dvui = @import("dvui");
const preview_mod = @import("preview_frame.zig");
const tokens = @import("../tokens.zig");
const pixels = @import("../helpers/pixels.zig");

fn handleAt(bounds: dvui.Rect, scale: f32) preview_mod.Handle {
    return .{
        .outer = undefined,
        .picture = undefined,
        .corner = tokens.current.preview_radius,
        .scale = scale,
        .vignette_alpha = tokens.current.preview_vignette_alpha,
        .bounds = bounds,
    };
}

test "preview frame defaults come from the theme" {
    const frame = preview_mod.previewFrame(@src());
    try std.testing.expect(frame.radius_val == null);
    try std.testing.expect(frame.inset_val == null);
    try std.testing.expect(frame.vignette_val == null);
}

test "preview frame setters copy-on-set" {
    const base = preview_mod.previewFrame(@src());
    const styled = base.radius(14).inset(12).vignette(0).tag("viewport");
    try std.testing.expect(base.radius_val == null);
    try std.testing.expectEqual(@as(f32, 14), styled.radius_val.?);
    try std.testing.expectEqual(@as(f32, 12), styled.inset_val.?);
    try std.testing.expectEqual(@as(u8, 0), styled.vignette_val.?);
    try std.testing.expectEqualStrings("viewport", styled.tag_val.?);
}

test "the toolbar slot is centred on the picture and hugs the top" {
    const bounds: dvui.Rect = .{ .x = 100, .y = 50, .w = 800, .h = 600 };
    const handle = handleAt(bounds, 1.0);
    const bar = handle.toolbarRect(360, 40);

    const left_gap = bar.x - bounds.x;
    const right_gap = (bounds.x + bounds.w) - (bar.x + bar.w);
    try std.testing.expectApproxEqAbs(left_gap, right_gap, 0.51);
    try std.testing.expect(bar.y > bounds.y);
    try std.testing.expect(bar.y < bounds.y + bounds.h / 2);
    try std.testing.expectEqual(@as(f32, 40), bar.h);
}

test "the status slot is centred on the picture and hugs the bottom" {
    const bounds: dvui.Rect = .{ .x = 100, .y = 50, .w = 800, .h = 600 };
    const handle = handleAt(bounds, 1.0);
    const strip = handle.statusRect(240, 24);

    const left_gap = strip.x - bounds.x;
    const right_gap = (bounds.x + bounds.w) - (strip.x + strip.w);
    try std.testing.expectApproxEqAbs(left_gap, right_gap, 0.51);
    try std.testing.expect(strip.y + strip.h < bounds.y + bounds.h);
    try std.testing.expect(strip.y > bounds.y + bounds.h / 2);
}

test "both slots land on whole physical pixels at 1.0, 1.75 and 2.0" {
    const bounds: dvui.Rect = .{ .x = 100, .y = 50, .w = 801, .h = 601 };
    for ([_]f32{ 1.0, 1.75, 2.0 }) |scale| {
        const handle = handleAt(bounds, scale);
        const bar = handle.toolbarRect(361, 40);
        const strip = handle.statusRect(241, 24);
        try std.testing.expect(pixels.isSnapped(bar.x, scale));
        try std.testing.expect(pixels.isSnapped(bar.y, scale));
        try std.testing.expect(pixels.isSnapped(strip.x, scale));
        try std.testing.expect(pixels.isSnapped(strip.y, scale));
    }
}

test "the vignette starts inside the picture, not at its centre" {
    const theme = tokens.default_theme;
    try std.testing.expect(theme.preview_vignette_start > 0.3);
    try std.testing.expect(theme.preview_vignette_start < 1.0);
}

test "reserve shrinks the slot area on the named edge only" {
    const bounds: dvui.Rect = .{ .x = 100, .y = 50, .w = 800, .h = 600 };
    const handle = handleAt(bounds, 1.0);

    const right = handle.reserve(.right, 200);
    try std.testing.expectEqual(@as(f32, 100), right.bounds.x);
    try std.testing.expectEqual(@as(f32, 600), right.bounds.w);
    try std.testing.expectEqual(bounds.h, right.bounds.h);

    const left = handle.reserve(.left, 200);
    try std.testing.expectEqual(@as(f32, 300), left.bounds.x);
    try std.testing.expectEqual(@as(f32, 600), left.bounds.w);

    const top = handle.reserve(.top, 100);
    try std.testing.expectEqual(@as(f32, 150), top.bounds.y);
    try std.testing.expectEqual(@as(f32, 500), top.bounds.h);

    const bottom = handle.reserve(.bottom, 100);
    try std.testing.expectEqual(@as(f32, 50), bottom.bounds.y);
    try std.testing.expectEqual(@as(f32, 500), bottom.bounds.h);
}

test "a toolbar centres on what reserve left visible" {
    const bounds: dvui.Rect = .{ .x = 100, .y = 50, .w = 800, .h = 600 };
    const free = handleAt(bounds, 1.0).reserve(.right, 200);
    const bar = free.toolbarRect(300, 40);
    // Centre of the 600px-wide visible strip, not of the whole 800px picture.
    try std.testing.expectApproxEqAbs(@as(f32, 250), bar.x, 0.51);
}

test "reserve never produces a negative area" {
    const bounds: dvui.Rect = .{ .x = 0, .y = 0, .w = 100, .h = 100 };
    const handle = handleAt(bounds, 1.0);
    try std.testing.expectEqual(@as(f32, 0), handle.reserve(.right, 500).bounds.w);
    try std.testing.expectEqual(@as(f32, 0), handle.reserve(.bottom, 500).bounds.h);
    try std.testing.expectEqual(@as(f32, 100), handle.reserve(.left, 500).bounds.x);
    try std.testing.expectEqual(@as(f32, 0), handle.reserve(.left, 500).bounds.w);
}
