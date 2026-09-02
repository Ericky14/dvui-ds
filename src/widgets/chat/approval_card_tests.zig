const std = @import("std");
const widget = @import("approval_card.zig");

test "approvalCard: the module exposes its builder type" {
    // Builders are value types; setters copy. Extend with behaviour tests as the
    // real implementation lands.
    try std.testing.expect(@hasDecl(widget, "ApprovalCard"));
}
