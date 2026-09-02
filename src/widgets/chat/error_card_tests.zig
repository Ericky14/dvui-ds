/// Tests for the error card builder and its compiler-output heuristic.
const std = @import("std");
const widget = @import("error_card.zig");

test "errorCard: builder defaults" {
    const card = widget.errorCard(@src(), "attempt to index a nil value", "scripts/ball.lua:12");
    try std.testing.expectEqualStrings("attempt to index a nil value", card.message_text);
    try std.testing.expectEqualStrings("scripts/ball.lua:12", card.location.?);
    try std.testing.expectEqual(@as(usize, 0), card.id_extra);
    try std.testing.expect(widget.errorCard(@src(), "boom", null).location == null);
}

test "errorCard: setters copy instead of mutating" {
    const base = widget.errorCard(@src(), "boom", null);
    const indexed = base.idExtra(7);
    try std.testing.expectEqual(@as(usize, 0), base.id_extra);
    try std.testing.expectEqual(@as(usize, 7), indexed.id_extra);
}

test "errorCard: compiler output renders mono" {
    try std.testing.expect(widget.looksCompilerShaped("src/main.zig:12:5: error: expected ';'"));
    try std.testing.expect(widget.looksCompilerShaped("first line\nsecond line"));
    try std.testing.expect(widget.looksCompilerShaped("ball.lua:12: attempt to index a nil value"));
    try std.testing.expect(widget.looksCompilerShaped("main.zig: warning: unused variable"));
    try std.testing.expect(widget.looksCompilerShaped("referenced here: note: see above"));
}

test "errorCard: prose messages stay proportional" {
    try std.testing.expect(!widget.looksCompilerShaped("attempt to index a nil value (global 'ball')"));
    try std.testing.expect(!widget.looksCompilerShaped("Build failed at 12:30 today"));
    try std.testing.expect(!widget.looksCompilerShaped("error: something"));
    try std.testing.expect(!widget.looksCompilerShaped(""));
}
