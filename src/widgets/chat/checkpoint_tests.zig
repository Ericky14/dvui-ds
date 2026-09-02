const std = @import("std");
const widget = @import("checkpoint.zig");

test "checkpoint: the module exposes its builder type" {
    // Builders are value types; setters copy. Extend with behaviour tests as the
    // real implementation lands.
    try std.testing.expect(@hasDecl(widget, "Checkpoint"));
}
