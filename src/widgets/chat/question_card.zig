/// QuestionCard — the agent's clarifying questions (2-4 options each). Returns true
/// on the frame Submit is clicked. CONTRACT:
///   - Per question: header chip (`badge` accent) + question text (primary), then the
///     options as radio rows (single) or checkbox rows (multi), label primary,
///     description muted on a second line, toggling `selections[i].chosen[j]`.
///   - When `other` is given: an "Other" text input after the options of the last
///     question.
///   - Submit (filled, sm) is disabled until every question has a selection or the
///     other buffer is non-empty (see `isReady`).
///   - Container like the approval card but with the neutral `surface_1` fill and
///     `border` border.
///
/// Usage:
///   const questions = [_]ds.chat.Question{ .{ .header = "Format", .question = "How should I format it?", .options = &.{
///       .{ .label = "Summary", .description = "Brief overview" },
///       .{ .label = "Detailed" },
///   } } };
///   var selections: [1]ds.chat.Selection = .{.{}};
///   if (ds.chat.questionCard(@src(), &questions, &selections).other(&other_buffer).draw()) submit(selections);
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

/// Placeholder for the free-text answer input.
const other_placeholder = "Other";

/// Control size used for the option rows (the DS body size, so labels match the
/// question text).
const control_size: tokens.Size = .md;
/// Width of the `.md` radio / checkbox control (see `circleSize` / `boxSize` in
/// radio.zig and checkbox.zig). Used to indent an option's description under its
/// label: control + the control's space_sm gap + its space_3xs padding.
const control_width_md: f32 = 18;

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

    /// Whether Submit is enabled: every question has a selection, or the "Other"
    /// buffer holds text.
    pub fn isReady(self: QuestionCard) bool {
        if (self.other_buffer) |buffer| {
            if (std.mem.sliceTo(buffer, 0).len > 0) return true;
        }
        if (self.questions.len == 0) return false;
        for (self.questions, 0..) |_, index| {
            if (index >= self.selections.len) return false;
            if (!self.selections[index].any()) return false;
        }
        return true;
    }

    /// Draw the widget.
    pub fn draw(self: QuestionCard) bool {
        const theme = tokens.current;

        var card = dvui.box(self.src, .{ .dir = .vertical, .gap = theme.space_sm }, containerOpts(theme, self.id_extra));
        defer card.deinit();

        for (self.questions, 0..) |question, question_index| {
            var block = dvui.box(@src(), .{ .dir = .vertical, .gap = theme.space_3xs }, .{ .id_extra = question_index, .expand = .horizontal });
            defer block.deinit();

            {
                var head = dvui.box(@src(), .{ .dir = .horizontal, .gap = theme.space_sm }, .{ .expand = .horizontal });
                defer head.deinit();
                ds.badge(@src(), question.header).variant(.accent).draw();
                dvui.labelNoFmt(@src(), question.question, .{}, questionOpts(theme));
            }

            if (question_index < self.selections.len) {
                self.drawOptions(question, &self.selections[question_index], theme);
            }

            if (question_index + 1 == self.questions.len) {
                if (self.other_buffer) |buffer| {
                    ds.textInput(@src(), buffer).size(.sm).placeholder(other_placeholder).expand(.horizontal).draw();
                }
            }
        }

        var footer = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal });
        defer footer.deinit();
        ds.spacer(@src());
        return ds.button(@src(), "Submit").variant(.filled).size(.sm).disabled(!self.isReady()).draw();
    }

    /// The option rows of one question: radios (single) or checkboxes (multi),
    /// each followed by its muted description.
    fn drawOptions(self: QuestionCard, question: Question, selection: *Selection, theme: tokens.Theme) void {
        _ = self;
        for (question.options, 0..) |option, option_index| {
            if (option_index >= selection.chosen.len) break;
            var row = dvui.box(@src(), .{ .dir = .vertical }, .{ .id_extra = option_index, .expand = .horizontal });
            defer row.deinit();

            if (question.multi_select) {
                _ = ds.checkbox(@src(), &selection.chosen[option_index]).size(control_size).label(option.label).draw();
            } else if (ds.radio(@src(), selection.chosen[option_index], option.label).size(control_size).draw()) {
                selection.chosen = @splat(false);
                selection.chosen[option_index] = true;
            }

            if (option.description.len > 0) {
                dvui.labelNoFmt(@src(), option.description, .{}, descriptionOpts(theme));
            }
        }
    }
};

/// Neutral container: `surface_1` fill with the default `border`.
fn containerOpts(theme: tokens.Theme, id_extra: usize) dvui.Options {
    return .{
        .id_extra = id_extra,
        .expand = .horizontal,
        .background = true,
        .color_fill = .{ .color = theme.surface_1 },
        .color_border = .{ .color = theme.border },
        .border = dvui.Rect.all(theme.border_width),
        .corners = dvui.CornerRect.round(theme.radius_md),
        .padding = ds.padding(theme.space_sm),
    };
}

fn questionOpts(theme: tokens.Theme) dvui.Options {
    return .{
        .color_text = .{ .color = theme.text_primary },
        .font = ds.fontMedium(theme.font_size_md),
        .gravity_y = 0.5,
    };
}

/// Muted caption, indented so it sits under the option label, tucked close to it.
fn descriptionOpts(theme: tokens.Theme) dvui.Options {
    const indent = control_width_md + theme.space_sm + theme.space_3xs;
    return .{
        .color_text = .{ .color = theme.text_muted },
        .font = ds.font(theme.font_size_sm),
        .margin = ds.paddingEach(0, 0, 0, indent),
        .padding = ds.paddingEach(0, theme.space_xs, theme.space_2xs, theme.space_xs),
    };
}

test {
    _ = @import("question_card_tests.zig");
}
