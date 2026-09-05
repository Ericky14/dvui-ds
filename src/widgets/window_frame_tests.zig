const std = @import("std");
const dvui = @import("dvui");
const frame_mod = @import("window_frame.zig");
const tokens = @import("../tokens.zig");
const pixels = @import("../helpers/pixels.zig");

test "window frame defaults to focused and vertical" {
    const frame = frame_mod.windowFrame(@src());
    try std.testing.expect(frame.is_focused);
    try std.testing.expectEqual(dvui.enums.Direction.vertical, frame.dir);
    try std.testing.expect(frame.radius_val == null);
}

test "window frame setters copy-on-set" {
    const base = frame_mod.windowFrame(@src());
    const styled = base.focused(false).radius(20).horizontal().gap(4).tag("shell");
    try std.testing.expect(base.is_focused);
    try std.testing.expect(!styled.is_focused);
    try std.testing.expectEqual(@as(f32, 20), styled.radius_val.?);
    try std.testing.expectEqual(dvui.enums.Direction.horizontal, styled.dir);
    try std.testing.expectEqual(@as(f32, 4), styled.gap_val);
    try std.testing.expectEqualStrings("shell", styled.tag_val.?);
}

test "the unfocused inner ring is dimmer but still visible" {
    const theme = tokens.default_theme;
    try std.testing.expect(theme.border_inner_alpha_unfocused < theme.border_inner_alpha);
    try std.testing.expect(theme.border_inner_alpha_unfocused > 0);
}

test "both rings are whole physical pixels at 1.0, 1.75 and 2.0" {
    // The frame is a hairline of border plus a hairline of padding; if either
    // lands off the pixel grid the window edge fringes into grey.
    for ([_]f32{ 1.0, 1.75, 2.0 }) |scale| {
        const line = pixels.hairline(scale);
        try std.testing.expect(pixels.isSnapped(line, scale));
        try std.testing.expect(pixels.isSnapped(line * 2, scale));
        try std.testing.expect(line * scale >= 1);
    }
}
