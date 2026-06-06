const std = @import("std");
const card_mod = @import("card.zig");

test "card defaults to elevated, vertical" {
    const c = card_mod.card(@src());
    try std.testing.expectEqual(card_mod.CardVariant.elevated, c.card_variant);
    try std.testing.expectEqual(@as(f32, 0), c.gap_val);
    try std.testing.expect(c.pad_override == null);
}

test "card setters copy-on-set" {
    const base = card_mod.card(@src());
    const styled = base.variant(.outlined).horizontal().gap(12).padding(20);
    // Original is untouched (value semantics).
    try std.testing.expectEqual(card_mod.CardVariant.elevated, base.card_variant);
    try std.testing.expectEqual(card_mod.CardVariant.outlined, styled.card_variant);
    try std.testing.expectEqual(@as(f32, 12), styled.gap_val);
    try std.testing.expect(styled.pad_override != null);
}
