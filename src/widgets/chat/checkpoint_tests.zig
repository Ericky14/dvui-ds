/// Tests for the checkpoint builder.
const std = @import("std");
const widget = @import("checkpoint.zig");

test "checkpoint: builder defaults" {
    const marker = widget.checkpoint(@src(), "turn 7 / 2 files");
    try std.testing.expectEqualStrings("turn 7 / 2 files", marker.label_text);
    try std.testing.expectEqual(@as(usize, 0), marker.id_extra);
}

test "checkpoint: setters copy instead of mutating" {
    const base = widget.checkpoint(@src(), "turn 7");
    const indexed = base.idExtra(7);
    try std.testing.expectEqual(@as(usize, 0), base.id_extra);
    try std.testing.expectEqual(@as(usize, 7), indexed.id_extra);
    try std.testing.expect(@hasDecl(widget, "Checkpoint"));
}
