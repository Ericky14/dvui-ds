const std = @import("std");
const dvui = @import("dvui");
const tooltip_mod = @import("tooltip.zig");

const zero_rect: dvui.Rect.Physical = .{ .x = 0, .y = 0, .w = 0, .h = 0 };

test "tooltip defaults: empty text, vertical, 300ms delay" {
    const tip = tooltip_mod.tooltip(@src(), zero_rect);
    try std.testing.expectEqualStrings("", tip.text_str);
    try std.testing.expectEqual(tooltip_mod.Position.vertical, tip.position_val);
    try std.testing.expectEqual(@as(i32, 300_000), tip.delay_val);
}

test "tooltip setters copy-on-set" {
    const base = tooltip_mod.tooltip(@src(), zero_rect);
    const styled = base.text("Hint").position(.horizontal).delay(1_000);

    // original untouched
    try std.testing.expectEqualStrings("", base.text_str);
    try std.testing.expectEqual(tooltip_mod.Position.vertical, base.position_val);
    try std.testing.expectEqual(@as(i32, 300_000), base.delay_val);

    // copy carries the mutations
    try std.testing.expectEqualStrings("Hint", styled.text_str);
    try std.testing.expectEqual(tooltip_mod.Position.horizontal, styled.position_val);
    try std.testing.expectEqual(@as(i32, 1_000), styled.delay_val);
}
