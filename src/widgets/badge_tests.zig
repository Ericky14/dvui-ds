const std = @import("std");
const badge_mod = @import("badge.zig");

test "badge defaults: neutral, not a dot, no idExtra" {
    const item = badge_mod.badge(@src(), "New");
    try std.testing.expectEqual(badge_mod.BadgeVariant.neutral, item.badge_variant);
    try std.testing.expect(!item.is_dot);
    try std.testing.expectEqual(@as(usize, 0), item.id_extra);
    try std.testing.expectEqualStrings("New", item.text);
}

test "badge setters copy-on-set" {
    const base = badge_mod.badge(@src(), "Error");
    const styled = base.variant(.danger).dot(true).idExtra(7);

    // original untouched
    try std.testing.expectEqual(badge_mod.BadgeVariant.neutral, base.badge_variant);
    try std.testing.expect(!base.is_dot);
    try std.testing.expectEqual(@as(usize, 0), base.id_extra);

    // copy mutated
    try std.testing.expectEqual(badge_mod.BadgeVariant.danger, styled.badge_variant);
    try std.testing.expect(styled.is_dot);
    try std.testing.expectEqual(@as(usize, 7), styled.id_extra);
    try std.testing.expectEqualStrings("Error", styled.text);
}

test "badge variant setter independent per copy" {
    const base = badge_mod.badge(@src(), "3");
    const accent = base.variant(.accent);
    const danger = base.variant(.danger);
    try std.testing.expectEqual(badge_mod.BadgeVariant.accent, accent.badge_variant);
    try std.testing.expectEqual(badge_mod.BadgeVariant.danger, danger.badge_variant);
}
