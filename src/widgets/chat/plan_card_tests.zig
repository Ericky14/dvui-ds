const std = @import("std");
const widget = @import("plan_card.zig");

test "planCard: the module exposes its builder type" {
    // Builders are value types; setters copy. Extend with behaviour tests as the
    // real implementation lands.
    try std.testing.expect(@hasDecl(widget, "PlanCard"));
}
