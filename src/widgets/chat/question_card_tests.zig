/// Tests for the question card builder and its readiness rule.
const std = @import("std");
const widget = @import("question_card.zig");

const options = [_]widget.Option{
    .{ .label = "Summary", .description = "Brief overview" },
    .{ .label = "Detailed" },
};

const questions = [_]widget.Question{
    .{ .header = "Format", .question = "How should I format it?", .options = &options },
    .{ .header = "Sections", .question = "Which sections?", .options = &options, .multi_select = true },
};

test "questionCard: builder defaults" {
    var selections: [2]widget.Selection = .{ .{}, .{} };
    const card = widget.questionCard(@src(), &questions, &selections);
    try std.testing.expectEqual(@as(usize, 2), card.questions.len);
    try std.testing.expectEqual(@as(usize, 2), card.selections.len);
    try std.testing.expect(card.other_buffer == null);
    try std.testing.expectEqual(@as(usize, 0), card.id_extra);
}

test "questionCard: setters copy instead of mutating" {
    var selections: [2]widget.Selection = .{ .{}, .{} };
    var buffer: [16]u8 = @splat(0);
    const base = widget.questionCard(@src(), &questions, &selections);
    const with_other = base.other(&buffer).idExtra(9);
    try std.testing.expect(base.other_buffer == null);
    try std.testing.expectEqual(@as(usize, 0), base.id_extra);
    try std.testing.expect(with_other.other_buffer.?.ptr == &buffer);
    try std.testing.expectEqual(@as(usize, 9), with_other.id_extra);
}

test "Selection.any reports whether an option is chosen" {
    var selection: widget.Selection = .{};
    try std.testing.expect(!selection.any());
    selection.chosen[1] = true;
    try std.testing.expect(selection.any());
}

test "questionCard: submit waits for every question" {
    var selections: [2]widget.Selection = .{ .{}, .{} };
    const card = widget.questionCard(@src(), &questions, &selections);
    try std.testing.expect(!card.isReady());
    selections[0].chosen[0] = true;
    try std.testing.expect(!card.isReady());
    selections[1].chosen[1] = true;
    try std.testing.expect(card.isReady());
}

test "questionCard: a free-text answer unlocks submit on its own" {
    var selections: [2]widget.Selection = .{ .{}, .{} };
    var buffer: [16]u8 = @splat(0);
    const card = widget.questionCard(@src(), &questions, &selections).other(&buffer);
    try std.testing.expect(!card.isReady());
    @memcpy(buffer[0..4], "pdf\x00");
    try std.testing.expect(card.isReady());
}

test "questionCard: missing selection state or no questions is never ready" {
    var one: [1]widget.Selection = .{.{}};
    one[0].chosen[0] = true;
    try std.testing.expect(!widget.questionCard(@src(), &questions, &one).isReady());
    try std.testing.expect(!widget.questionCard(@src(), &.{}, &one).isReady());
}
