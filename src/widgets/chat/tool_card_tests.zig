const std = @import("std");
const widget = @import("tool_card.zig");

test "toolCard: the module exposes its builder type" {
    // Builders are value types; setters copy. Extend with behaviour tests as the
    // real implementation lands.
    try std.testing.expect(@hasDecl(widget, "ToolCard"));
}
