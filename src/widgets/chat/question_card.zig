/// QuestionCard — the agent's clarifying questions (2-4 options each). Returns true
/// on the frame Submit is clicked. CONTRACT:
///   - Per question: header chip (`badge` accent) + question text (primary), then the
///     options as radio rows (single) or checkbox rows (multi), label primary,
///     description muted on a second line, toggling `selections[i].chosen[j]`.
///   - When `other` is given (one caller-owned buffer per question): every question
///     gets an "Other…" choice after its options (`other_label`) — a radio in a
///     single-select's group (choosing it clears the option picked, and an option
///     picked after it closes it) or a checkbox beside a multi-select's picks.
///     Choosing it sets `selections[i].other`, opens a one-line field under it that
///     writes into buffer `i`, and hands that field the keyboard. A question's
///     answer is its picked labels, its own words (`ownWords`), or both. Words
///     typed under an Other that is closed again stay in the buffer but are no
///     answer.
///   - When `note` is given: one wrapped line above Submit about the card itself
///     (e.g. that its answers will go as the next message).
///   - Submit (filled, sm) is disabled until every question has an answer (see
///     `isReady`).
///   - Container like the approval card but with the neutral `surface_1` fill and
///     `border` border.
///
/// Usage:
///   const questions = [_]ds.chat.Question{ .{ .header = "Format", .question = "How should I format it?", .options = &.{
///       .{ .label = "Summary", .description = "Brief overview" },
///       .{ .label = "Detailed" },
///   } } };
///   var selections: [1]ds.chat.Selection = .{.{}};
///   var words: [1][256]u8 = .{@splat(0)};
///   const buffers = [_][]u8{&words[0]};
///   if (ds.chat.questionCard(@src(), &questions, &selections).other(&buffers).draw()) submit(selections, buffers);
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
    /// The question's "Other…" is chosen: its field is open, and what it holds
    /// is part of the answer (`ownWords`).
    other: bool = false,

    /// Whether an option is chosen (Other aside).
    pub fn any(self: Selection) bool {
        for (self.chosen) |flag| if (flag) return true;
        return false;
    }
};

/// The label of every question's own-words choice. Public so a host's test can
/// find the row by its text.
pub const other_label = "Other\u{2026}";

/// Placeholder for a question's own-words field.
const other_placeholder = "Your own answer";

/// **A question's own words**: what its field holds, trimmed — "" while its
/// Other is not chosen, whatever the buffer still holds.
pub fn ownWords(selection: Selection, buffer: []const u8) []const u8 {
    if (!selection.other) return "";
    return std.mem.trim(u8, std.mem.sliceTo(buffer, 0), " \t\r\n");
}

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
    /// One own-words buffer per question (index-aligned); a question without
    /// one (or with an empty one) has no Other.
    other_buffers: ?[]const []u8 = null,
    note_text: []const u8 = "",
    expand_val: dvui.Options.Expand = .horizontal,
    height_val: ?f32 = null,
    id_extra: usize = 0,

    /// Caller-owned buffers, one per question (index-aligned): each question
    /// gets an "Other…" choice that opens a one-line field writing into its
    /// buffer.
    pub fn other(self: QuestionCard, buffers: []const []u8) QuestionCard {
        var copy = self;
        copy.other_buffers = buffers;
        return copy;
    }

    /// One line about the card itself, above Submit ("" draws none) — e.g. that
    /// the agent stopped waiting and the answers will go as the next message.
    pub fn note(self: QuestionCard, text: []const u8) QuestionCard {
        var copy = self;
        copy.note_text = text;
        return copy;
    }

    /// How the card fills its parent. The default is `.horizontal`: a chat card
    /// is as wide as the transcript and as tall as its content.
    ///
    /// A pane that scrolls its own transcript wants `.both` so the card takes
    /// the height it is given rather than the height it asked for — otherwise
    /// the card reports one height, the pane hands it another, and the two
    /// disagree by however much the content wanted.
    pub fn expand(self: QuestionCard, val: dvui.Options.Expand) QuestionCard {
        var copy = self;
        copy.expand_val = val;
        return copy;
    }

    /// Pin the card's height (logical px), snapped to whole physical pixels.
    /// The door for a pane that has already decided how tall each row is.
    pub fn height(self: QuestionCard, logical_px: f32) QuestionCard {
        var copy = self;
        copy.height_val = logical_px;
        return copy;
    }

    /// Disambiguate identity when used in a loop / list.
    pub fn idExtra(self: QuestionCard, val: usize) QuestionCard {
        var copy = self;
        copy.id_extra = val;
        return copy;
    }

    /// Whether Submit is enabled: every question has an option picked, or its
    /// Other chosen with words in its field.
    pub fn isReady(self: QuestionCard) bool {
        if (self.questions.len == 0) return false;
        for (self.questions, 0..) |_, index| {
            if (index >= self.selections.len) return false;
            const selection = self.selections[index];
            if (selection.any()) continue;
            if (ownWords(selection, self.buffer(index)).len == 0) return false;
        }
        return true;
    }

    /// Question `index`'s own-words buffer (empty when it has none).
    fn buffer(self: QuestionCard, index: usize) []u8 {
        const buffers = self.other_buffers orelse return &.{};
        if (index >= buffers.len) return &.{};
        return buffers[index];
    }

    /// Draw the widget.
    pub fn draw(self: QuestionCard) bool {
        const theme = tokens.current;

        var card = dvui.box(self.src, .{ .dir = .vertical, .gap = theme.space_sm }, containerOpts(theme, self.id_extra).override(sizing(self.expand_val, self.height_val)));
        defer card.deinit();

        for (self.questions, 0..) |question, question_index| {
            var block = dvui.box(@src(), .{ .dir = .vertical, .gap = theme.space_2xs }, .{ .id_extra = question_index, .expand = .horizontal });
            defer block.deinit();

            {
                var head = dvui.box(@src(), .{ .dir = .horizontal, .gap = theme.space_sm }, .{ .expand = .horizontal });
                defer head.deinit();
                ds.badge(@src(), question.header).variant(.accent).draw();
                dvui.labelNoFmt(@src(), question.question, .{}, questionOpts(theme));
            }

            if (question_index < self.selections.len) {
                const selection = &self.selections[question_index];
                drawOptions(question, selection, theme);
                const words = self.buffer(question_index);
                if (words.len > 0) drawOther(question, selection, words, theme, self.id_extra *% 65521 +% question_index);
            }
        }

        if (self.note_text.len > 0) drawNote(self.note_text, theme);

        var footer = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal });
        defer footer.deinit();
        ds.spacer(@src());
        return ds.button(@src(), "Submit").variant(.filled).size(.sm).disabled(!self.isReady()).draw();
    }
};

/// The option rows of one question: radios (single) or checkboxes (multi),
/// each followed by its muted description.
fn drawOptions(question: Question, selection: *Selection, theme: tokens.Theme) void {
    for (question.options, 0..) |option, option_index| {
        if (option_index >= selection.chosen.len) break;
        var row = dvui.box(@src(), .{ .dir = .vertical }, .{ .id_extra = option_index, .expand = .horizontal });
        defer row.deinit();

        if (question.multi_select) {
            _ = ds.checkbox(@src(), &selection.chosen[option_index]).size(control_size).label(option.label).draw();
        } else if (ds.radio(@src(), selection.chosen[option_index], option.label).size(control_size).draw()) {
            // One answer: an option closes the question's Other.
            selection.chosen = @splat(false);
            selection.chosen[option_index] = true;
            selection.other = false;
        }

        if (option.description.len > 0) {
            dvui.labelNoFmt(@src(), option.description, .{}, descriptionOpts(theme));
        }
    }
}

/// **A question's "Other…"**: one more choice after its options — in a
/// single-select's group (it clears the option picked) or beside a
/// multi-select's picks — and, while chosen, a one-line field under it that
/// writes into `words`. The field takes the keyboard the frame Other is chosen,
/// so the person types straight on; the Space or click that chose it stays the
/// Other's and is never typed into the field.
///
/// `field_key` tells this question's field from every other card's and
/// question's: a text input keeps its focus ring by its call site and
/// `idExtra`, so two Others' fields drawn from this one line once shared
/// it — the first showed the ring while the second held the caret.
fn drawOther(question: Question, selection: *Selection, words: []u8, theme: tokens.Theme, field_key: usize) void {
    var row = dvui.box(@src(), .{ .dir = .vertical, .gap = theme.space_2xs }, .{ .expand = .horizontal });
    defer row.deinit();

    var chose = false;
    if (question.multi_select) {
        if (ds.checkbox(@src(), &selection.other).size(control_size).label(other_label).draw()) chose = selection.other;
    } else if (ds.radio(@src(), selection.other, other_label).size(control_size).draw()) {
        selection.chosen = @splat(false);
        selection.other = true;
        chose = true;
    }
    if (!selection.other) return;

    var indent = dvui.box(@src(), .{}, .{ .expand = .horizontal, .margin = ds.paddingEach(0, 0, 0, descriptionIndent(theme)) });
    defer indent.deinit();
    const field = ds.textInput(@src(), words).size(.sm).placeholder(other_placeholder).expand(.horizontal).idExtra(field_key).draw();
    if (chose) dvui.focusWidget(field.id, null, null);
}

/// The card's one line about itself, wrapped, above Submit.
fn drawNote(text: []const u8, theme: tokens.Theme) void {
    var layout = dvui.textLayout(@src(), .{ .break_lines = true }, .{
        .expand = .horizontal,
        .background = false,
        .padding = dvui.Rect.all(0),
        .margin = dvui.Rect.all(0),
        .font = ds.font(theme.font_size_sm),
        .color_text = .{ .color = theme.text_secondary },
    });
    defer layout.deinit();
    layout.addText(text, .{});
}

/// How far an option's description, and a question's own-words field, sit in
/// from the card's content edge: under the option's label, past its control.
fn descriptionIndent(theme: tokens.Theme) f32 {
    return control_width_md + theme.space_sm + theme.space_3xs;
}

/// Neutral container: `surface_1` fill with the default `border`.
fn containerOpts(theme: tokens.Theme, id_extra: usize) dvui.Options {
    return .{
        .id_extra = id_extra,
        .expand = .horizontal,
        .background = true,
        .color_fill = .{ .color = theme.surface_1 },
        .color_border = .{ .color = theme.border },
        .border = ds.border(theme.border_width),
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
    return .{
        .color_text = .{ .color = theme.text_muted },
        .font = ds.font(theme.font_size_sm),
        .margin = ds.paddingEach(0, 0, 0, descriptionIndent(theme)),
        .padding = ds.paddingEach(0, theme.space_xs, theme.space_2xs, theme.space_xs),
    };
}

test {
    _ = @import("question_card_tests.zig");
}

/// The caller's `expand` / `height` as options, snapped.
fn sizing(expand_val: dvui.Options.Expand, height_val: ?f32) dvui.Options {
    if (height_val) |px| {
        const snapped = ds.snapPx(px, ds.pixelScale());
        return .{
            .expand = expand_val,
            .min_size_content = .{ .w = 0, .h = snapped },
            .max_size_content = .height(snapped),
        };
    }
    return .{ .expand = expand_val };
}
