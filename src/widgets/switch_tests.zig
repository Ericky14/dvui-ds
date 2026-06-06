const std = @import("std");
const switch_mod = @import("switch.zig");
const tokens = @import("../tokens.zig");

test "switch defaults: md, no label, enabled, id_extra 0" {
    var value = false;
    const sw = switch_mod.toggle(@src(), &value);
    try std.testing.expectEqual(tokens.Size.md, sw.sw_size);
    try std.testing.expect(sw.label_text == null);
    try std.testing.expect(!sw.is_disabled);
    try std.testing.expectEqual(@as(usize, 0), sw.id_extra);
    try std.testing.expect(sw.target == &value);
}

test "switch setters copy-on-set" {
    var value = false;
    const base = switch_mod.toggle(@src(), &value);
    const styled = base.size(.lg).label("Wi-Fi").disabled(true).idExtra(7);

    // Original untouched.
    try std.testing.expectEqual(tokens.Size.md, base.sw_size);
    try std.testing.expect(base.label_text == null);
    try std.testing.expect(!base.is_disabled);
    try std.testing.expectEqual(@as(usize, 0), base.id_extra);

    // Copy mutated.
    try std.testing.expectEqual(tokens.Size.lg, styled.sw_size);
    try std.testing.expectEqualStrings("Wi-Fi", styled.label_text.?);
    try std.testing.expect(styled.is_disabled);
    try std.testing.expectEqual(@as(usize, 7), styled.id_extra);
    try std.testing.expect(styled.target == &value);
}
