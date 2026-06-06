const std = @import("std");
const radio_mod = @import("radio.zig");
const tokens = @import("../tokens.zig");

test "radio defaults: md, enabled, id_extra 0" {
    const r = radio_mod.radio(@src(), true, "Option A");
    try std.testing.expectEqual(tokens.Size.md, r.radio_size);
    try std.testing.expect(r.is_active);
    try std.testing.expectEqualStrings("Option A", r.label_text.?);
    try std.testing.expect(!r.is_disabled);
    try std.testing.expectEqual(@as(usize, 0), r.id_extra);
}

test "radio accepts a null label and inactive state" {
    const r = radio_mod.radio(@src(), false, null);
    try std.testing.expect(!r.is_active);
    try std.testing.expect(r.label_text == null);
}

test "radio setters copy-on-set" {
    const base = radio_mod.radio(@src(), false, "Option B");
    const styled = base.size(.lg).disabled(true).idExtra(3);

    // original untouched
    try std.testing.expectEqual(tokens.Size.md, base.radio_size);
    try std.testing.expect(!base.is_disabled);
    try std.testing.expectEqual(@as(usize, 0), base.id_extra);

    // copy carries the mutations
    try std.testing.expectEqual(tokens.Size.lg, styled.radio_size);
    try std.testing.expect(styled.is_disabled);
    try std.testing.expectEqual(@as(usize, 3), styled.id_extra);
}
