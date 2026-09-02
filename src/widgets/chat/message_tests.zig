const std = @import("std");
const widget = @import("message.zig");

test "message: the module exposes its builder type" {
    // Builders are value types; setters copy. Extend with behaviour tests as the
    // real implementation lands.
    try std.testing.expect(@hasDecl(widget, "Message"));
}
