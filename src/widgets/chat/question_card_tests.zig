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
    try std.testing.expect(card.other_buffers == null);
    try std.testing.expectEqualStrings("", card.note_text);
    try std.testing.expectEqual(@as(usize, 0), card.id_extra);
}

test "questionCard: setters copy instead of mutating" {
    var selections: [2]widget.Selection = .{ .{}, .{} };
    var first: [16]u8 = @splat(0);
    var second: [16]u8 = @splat(0);
    const buffers = [_][]u8{ &first, &second };
    const base = widget.questionCard(@src(), &questions, &selections);
    const with_other = base.other(&buffers).note("The agent stopped waiting").idExtra(9);
    try std.testing.expect(base.other_buffers == null);
    try std.testing.expectEqualStrings("", base.note_text);
    try std.testing.expectEqual(@as(usize, 0), base.id_extra);
    try std.testing.expectEqual(@as(usize, 2), with_other.other_buffers.?.len);
    try std.testing.expect(with_other.other_buffers.?[1].ptr == &second);
    try std.testing.expectEqualStrings("The agent stopped waiting", with_other.note_text);
    try std.testing.expectEqual(@as(usize, 9), with_other.id_extra);
}

test "Selection.any reports whether an option is chosen, Other aside" {
    var selection: widget.Selection = .{};
    try std.testing.expect(!selection.any());
    selection.other = true;
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

test "ownWords: a question's own words count only while its Other is chosen, trimmed" {
    var buffer: [32]u8 = @splat(0);
    @memcpy(buffer[0..13], "  watercolor ");
    var selection: widget.Selection = .{};
    try std.testing.expectEqualStrings("", widget.ownWords(selection, &buffer));
    selection.other = true;
    try std.testing.expectEqualStrings("watercolor", widget.ownWords(selection, &buffer));
    try std.testing.expectEqualStrings("", widget.ownWords(selection, &.{}));
}

test "questionCard: a question answered in its own words is answered, and only that question" {
    var selections: [2]widget.Selection = .{ .{}, .{} };
    var first: [32]u8 = @splat(0);
    var second: [32]u8 = @splat(0);
    const buffers = [_][]u8{ &first, &second };
    const card = widget.questionCard(@src(), &questions, &selections).other(&buffers);
    // The second question's Other, with words: the first is still open.
    selections[1].other = true;
    @memcpy(second[0..9], "appendix\x00");
    try std.testing.expect(!card.isReady());
    // The first question's Other chosen but empty is no answer yet.
    selections[0].other = true;
    try std.testing.expect(!card.isReady());
    @memcpy(first[0..4], "pdf\x00");
    try std.testing.expect(card.isReady());
    // Words typed under an Other that is no longer chosen are not an answer.
    selections[0].other = false;
    try std.testing.expect(!card.isReady());
}

test "questionCard: a multi-select's empty Other beside a picked option still lets it submit" {
    var selections: [2]widget.Selection = .{ .{}, .{} };
    var first: [8]u8 = @splat(0);
    var second: [8]u8 = @splat(0);
    const buffers = [_][]u8{ &first, &second };
    const card = widget.questionCard(@src(), &questions, &selections).other(&buffers);
    selections[0].chosen[0] = true;
    selections[1].chosen[0] = true;
    selections[1].other = true;
    try std.testing.expect(card.isReady());
}

test "questionCard: missing selection state or no questions is never ready" {
    var one: [1]widget.Selection = .{.{}};
    one[0].chosen[0] = true;
    try std.testing.expect(!widget.questionCard(@src(), &questions, &one).isReady());
    try std.testing.expect(!widget.questionCard(@src(), &.{}, &one).isReady());
}
