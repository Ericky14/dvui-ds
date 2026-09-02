/// The agent's clarifying questions (2-4 options each). Returns true on the frame
/// Submit is clicked. CONTRACT:
///   - Per question: header chip (`badge` accent) + question text (primary), then the
///     options as radio rows (single) or checkbox rows (multi), label primary,
///     description muted on a second line, toggling `selections[i].chosen[j]`.
///   - When `other` is given: an "Other" text input after the options of the last
///     question.
///   - Submit (filled, sm) is disabled until every question has a selection or the
///     other buffer is non-empty.
///   - Container like the approval card but with the neutral `surface_1` fill and
///     `border` border.
///
/// STATUS: scaffold. The body below is a placeholder that compiles and renders a
/// plain box so consumers can integrate against the API; the real widget replaces
/// `draw()` (and adds private `opts()` resolvers) without changing this surface.
const std = @import("std");
const dvui = @import("dvui");
const ds = @import("../../ds.zig");
const tokens = @import("../../tokens.zig");

/// One selectable answer.
pub const Option = struct {
    label: []const u8,
    description: []const u8 = "",
};

/// One question as the agent's AskUserQuestion tool sends it.
pub const Question = struct {
    /// Short chip label (max 12 chars).
    header: []const u8,
    question: []const u8,
    /// 2-4 options.
    options: []const Option,
    multi_select: bool = false,
};

/// Caller-owned selection state for one question (immediate mode).
pub const Selection = struct {
    /// One flag per option (index-aligned with `Question.options`).
    chosen: [8]bool = @splat(false),

    pub fn any(self: Selection) bool {
        for (self.chosen) |flag| if (flag) return true;
        return false;
    }
};
pub fn questionCard(src: std.builtin.SourceLocation, questions: []const Question, selections: []Selection) QuestionCard {
    return .{ .src = src, .questions = questions, .selections = selections };
}

pub const QuestionCard = struct {
    src: std.builtin.SourceLocation,
    questions: []const Question,
    selections: []Selection,
    other_buffer: ?[]u8 = null,
    id_extra: usize = 0,

    /// Caller-owned buffer for a free-text "Other" answer.
    pub fn other(self: QuestionCard, val: []u8) QuestionCard {
        var copy = self;
        copy.other_buffer = val;
        return copy;
    }

    /// Disambiguate identity when used in a loop / list.
    pub fn idExtra(self: QuestionCard, val: usize) QuestionCard {
        var copy = self;
        copy.id_extra = val;
        return copy;
    }

    /// Draw the widget.
    pub fn draw(self: QuestionCard) bool {
        var box = dvui.box(self.src, .{ .dir = .vertical }, .{
            .id_extra = self.id_extra,
            .expand = .horizontal,
            .background = true,
            .color_fill = .{ .color = tokens.current.surface_1 },
            .padding = dvui.Rect.all(tokens.current.space_sm),
        });
        defer box.deinit();
        for (self.questions, 0..) |question, index| {
            dvui.labelNoFmt(@src(), question.question, .{}, .{ .id_extra = index });
        }
        _ = self.selections;
        _ = self.other_buffer;
        return false;
    }
};

test {
    _ = @import("question_card_tests.zig");
}
