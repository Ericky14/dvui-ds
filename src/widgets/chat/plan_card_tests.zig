/// Tests for the plan card builder.
const std = @import("std");
const widget = @import("plan_card.zig");

test "planCard: builder defaults" {
    const card = widget.planCard(@src(), "Add a bouncing ball", "1. Spawn a sphere");
    try std.testing.expectEqualStrings("Add a bouncing ball", card.title);
    try std.testing.expectEqualStrings("1. Spawn a sphere", card.body_markdown);
    try std.testing.expectEqual(@as(usize, 0), card.id_extra);
}

test "planCard: setters copy instead of mutating" {
    const base = widget.planCard(@src(), "Plan", "body");
    const indexed = base.idExtra(5);
    try std.testing.expectEqual(@as(usize, 0), base.id_extra);
    try std.testing.expectEqual(@as(usize, 5), indexed.id_extra);
}

test "planCard: the verdict enum starts at none" {
    try std.testing.expectEqual(widget.PlanChoice.none, @as(widget.PlanChoice, @fromBackingInt(@intCast(0))));
    try std.testing.expect(@hasDecl(widget, "PlanCard"));
}
