const std = @import("std");
const scroll_mod = @import("scroll_area.zig");

test "scrollArea defaults to expand .both, no id_extra" {
    const sa = scroll_mod.scrollArea(@src());
    try std.testing.expectEqual(@as(?usize, null), sa.id_extra);
    try std.testing.expect(sa.expand_val == .both);
}

test "scrollArea setters copy-on-set" {
    const base = scroll_mod.scrollArea(@src());
    const styled = base.expand(.vertical).idExtra(3);
    try std.testing.expect(base.expand_val == .both); // original untouched
    try std.testing.expect(styled.expand_val == .vertical);
    try std.testing.expectEqual(@as(?usize, 3), styled.id_extra);
}
