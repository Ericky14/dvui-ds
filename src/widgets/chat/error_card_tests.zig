const std = @import("std");
const widget = @import("error_card.zig");

test "errorCard: the module exposes its builder type" {
    // Builders are value types; setters copy. Extend with behaviour tests as the
    // real implementation lands.
    try std.testing.expect(@hasDecl(widget, "ErrorCard"));
}
