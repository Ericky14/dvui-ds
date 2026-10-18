//! The question card, driven like a person drives it: every question has its
//! own "Other…" after its options, choosing it opens a one-line field for THAT
//! question and hands it the keyboard, and the words typed there are that
//! question's answer and no other's.
//!
//! Run: `zig build test`. Driven by the keyboard (Tab, Space, typed text) through
//! dvui's testing backend at 1.0 and 1.75 — the owner's display — so the tab
//! order and the focus hand-off are measured, not assumed. The engine's own pane
//! test clicks the same card with a mouse (zigame `ask_person_card_tests.zig`).
const std = @import("std");
const dvui = @import("dvui");
const ds = @import("dvui_ds");
const lint = @import("ds_lint.zig");

const scales = [_]f32{ 1.0, 1.75 };

const questions = [_]ds.chat.Question{
    .{ .header = "Scope", .question = "How long should the game be?", .options = &.{
        .{ .label = "One level", .description = "A single two-minute run" },
        .{ .label = "Three levels" },
    } },
    .{ .header = "Art style", .question = "Which look?", .options = &.{
        .{ .label = "Low-poly" },
        .{ .label = "Toon" },
    } },
    .{ .header = "Extras", .question = "What else?", .multi_select = true, .options = &.{
        .{ .label = "Music" },
        .{ .label = "A level select" },
    } },
};

/// The card's caller-owned state, as a host keeps it.
const State = struct {
    var selections: [questions.len]ds.chat.Selection = @splat(.{});
    var words: [questions.len][64]u8 = @splat(@splat(0));
    var buffers: [questions.len][]u8 = undefined;
    var submitted: usize = 0;
    var note: []const u8 = "";

    fn reset() void {
        selections = @splat(.{});
        words = @splat(@splat(0));
        for (&buffers, &words) |*buffer, *storage| buffer.* = storage;
        submitted = 0;
        note = "";
    }

    fn frame() !dvui.App.Result {
        var background = dvui.box(@src(), .{}, .{
            .expand = .both,
            .background = true,
            .color_fill = .{ .color = ds.tokens.current.surface_0 },
            .padding = dvui.Rect.all(8),
        });
        defer background.deinit();
        if (ds.chat.questionCard(@src(), &questions, &selections).other(&buffers).note(note).draw()) submitted += 1;
        return .ok;
    }

    fn typed(index: usize) []const u8 {
        return std.mem.sliceTo(&words[index], 0);
    }
};

/// A testing window at `scale`, the card settled.
fn open(scale: f32) !dvui.testing {
    var t = try dvui.testing.init(.{
        .window_size = .{ .w = 480 * scale / 2, .h = 720 * scale / 2 },
        .window_init_opts = .{ .theme = ds.tokens.dvuiTheme() },
    });
    t.window.content_scale = scale / 2;
    State.reset();
    _ = try dvui.testing.step(State.frame);
    try dvui.testing.settle(State.frame);
    return t;
}

fn key(code: dvui.enums.Key, mod: dvui.enums.Mod) !void {
    try dvui.testing.pressKey(code, mod);
    _ = try dvui.testing.step(State.frame);
    _ = try dvui.testing.step(State.frame);
}

fn tabs(count: usize) !void {
    for (0..count) |_| try key(.tab, .none);
}

fn write(text: []const u8) !void {
    try dvui.testing.writeText(text);
    _ = try dvui.testing.step(State.frame);
    _ = try dvui.testing.step(State.frame);
}

// Tab stops, in order: question 1's two options and its Other (1-3), question
// 2's (4-6), question 3's (7-9).

test "each question has its own Other…: choosing it opens a field that takes the keyboard, and the words go to THAT question" {
    for (scales) |scale| {
        var t = try open(scale);
        defer t.deinit();
        // Nothing is open before the person chooses Other.
        for (State.selections) |selection| try std.testing.expect(!selection.other);

        // Question 2's Other, from the keyboard: Space opens its field, and the
        // very next keys type into it — no Tab, no click.
        try tabs(6);
        try key(.space, .none);
        try std.testing.expect(State.selections[1].other);
        try std.testing.expect(!State.selections[0].other);
        try std.testing.expect(!State.selections[2].other);
        try write("warm, like a picture book");

        try std.testing.expectEqualStrings("warm, like a picture book", State.typed(1));
        try std.testing.expectEqualStrings("", State.typed(0));
        try std.testing.expectEqualStrings("", State.typed(2));
        try std.testing.expectEqualStrings("warm, like a picture book", ds.chat.questionOwnWords(State.selections[1], State.buffers[1]));
        // Its own words answer question 2 and nothing else: the card waits for
        // the other two.
        const card = ds.chat.questionCard(@src(), &questions, &State.selections).other(&State.buffers);
        try std.testing.expect(!card.isReady());
        State.selections[0].chosen[0] = true;
        State.selections[2].chosen[1] = true;
        try std.testing.expect(card.isReady());
    }
}

test "a single-select's Other is one of its choices: it clears the option picked, and an option picked after it closes it, keeping the words" {
    for (scales) |scale| {
        var t = try open(scale);
        defer t.deinit();
        // "One level", then question 1's Other.
        try tabs(1);
        try key(.space, .none);
        try std.testing.expect(State.selections[0].chosen[0]);
        try tabs(2);
        try key(.space, .none);
        try std.testing.expect(State.selections[0].other);
        try std.testing.expect(!State.selections[0].any());
        try write("five short rooms");
        try std.testing.expectEqualStrings("five short rooms", ds.chat.questionOwnWords(State.selections[0], State.buffers[0]));

        // Back to "Three levels" (Shift+Tab out of the field to Other, again to
        // the option): the option is the answer now, the words wait unsent.
        try key(.tab, .lshift);
        try key(.tab, .lshift);
        try key(.space, .none);
        try std.testing.expect(State.selections[0].chosen[1]);
        try std.testing.expect(!State.selections[0].other);
        try std.testing.expectEqualStrings("", ds.chat.questionOwnWords(State.selections[0], State.buffers[0]));
        try std.testing.expectEqualStrings("five short rooms", State.typed(0));
    }
}

test "a multi-select's Other rides beside its picks" {
    for (scales) |scale| {
        var t = try open(scale);
        defer t.deinit();
        // Question 3: "Music", then its Other.
        try tabs(7);
        try key(.space, .none);
        try tabs(2);
        try key(.space, .none);
        try std.testing.expect(State.selections[2].chosen[0]);
        try std.testing.expect(State.selections[2].other);
        try write("rain sounds");
        try std.testing.expectEqualStrings("rain sounds", ds.chat.questionOwnWords(State.selections[2], State.buffers[2]));
        // Space again on the field's Other closes it (Shift+Tab back to it).
        try key(.tab, .lshift);
        try key(.space, .none);
        try std.testing.expect(!State.selections[2].other);
        try std.testing.expect(State.selections[2].chosen[0]);
    }
}

test "with two questions' Others open, only the field that holds the keyboard draws the focus ring" {
    for (scales) |scale| {
        var t = try open(scale);
        defer t.deinit();
        // Question 1's Other, typed into; then question 2's, which takes the
        // keyboard.
        try tabs(3);
        try key(.space, .none);
        try write("five short rooms");
        try tabs(3);
        try key(.space, .none);
        try std.testing.expect(State.selections[0].other and State.selections[1].other);

        dvui.debug.captureFrame();
        _ = try dvui.testing.step(State.frame);
        _ = try dvui.testing.step(State.frame);
        defer dvui.debug.clearCaptures(std.testing.allocator);
        const captured = dvui.debug.lastCapture() orelse return error.NoCapture;
        const theme = ds.tokens.current;
        var fields: usize = 0;
        var focused_rings: usize = 0;
        for (captured.widgets.items) |widget| {
            const name = widget.name orelse continue;
            if (!std.mem.eql(u8, name, "TextEntry") or !std.mem.endsWith(u8, widget.src_file, "question_card.zig")) continue;
            fields += 1;
            const ring = std.meta.eql(widget.color_border, theme.accent);
            // The ring is the keyboard's, and only the keyboard's: question 1's
            // field once showed it while question 2's held the caret (the two
            // fields shared one focus memory).
            try std.testing.expectEqual(widget.focused, ring);
            if (ring) focused_rings += 1;
        }
        try std.testing.expectEqual(@as(usize, 2), fields);
        try std.testing.expectEqual(@as(usize, 1), focused_rings);
    }
}

test "Submit is reachable from the keyboard once every question is answered" {
    for (scales) |scale| {
        var t = try open(scale);
        defer t.deinit();
        State.selections[0].chosen[0] = true;
        State.selections[1].chosen[1] = true;
        State.selections[2].chosen[0] = true;
        _ = try dvui.testing.step(State.frame);
        // Nine stops on the three questions, then Submit.
        try tabs(10);
        try key(.enter, .none);
        try std.testing.expectEqual(@as(usize, 1), State.submitted);
    }
}

// ── Long words wrap ────────────────────────────────────────────────────────────

const long_question = "Which of these three directions should the first level take, given that the player starts on the beach at dusk?";
const long_label = "A quiet walk along the shoreline that slowly reveals the lighthouse";
const long_description = "The camera stays low and the tide comes in behind the player, so the path narrows as the level goes on and the music swells.";

const long_questions = [_]ds.chat.Question{
    .{ .header = "Scope", .question = long_question, .options = &.{
        .{ .label = long_label, .description = long_description },
        .{ .label = "Short" },
    } },
    .{ .header = "Extras", .question = "What else?", .multi_select = true, .options = &.{
        .{ .label = long_label },
    } },
};

const LongState = struct {
    var selections: [long_questions.len]ds.chat.Selection = @splat(.{});

    fn frame() !dvui.App.Result {
        var background = dvui.box(@src(), .{}, .{
            .expand = .both,
            .background = true,
            .color_fill = .{ .color = ds.tokens.current.surface_0 },
            .padding = dvui.Rect.all(8),
        });
        defer background.deinit();
        _ = ds.chat.questionCard(@src(), &long_questions, &selections).draw();
        return .ok;
    }
};

/// The captured widget that shows exactly `text`, drawn from `file`.
fn shown(captured: *const dvui.Debug.CapturedFrame, file: []const u8, text: []const u8) ?*const dvui.Debug.CapturedWidget {
    for (captured.widgets.items) |*widget| {
        if (!std.mem.endsWith(u8, widget.src_file, file)) continue;
        const label = widget.label orelse continue;
        if (std.mem.eql(u8, label, text)) return widget;
    }
    return null;
}

test "a long question, an option's long label and its long description wrap at the card's width, never cut off with an ellipsis" {
    for (scales) |scale| {
        var t = try dvui.testing.init(.{
            .window_size = .{ .w = 320 * scale / 2, .h = 900 * scale / 2 },
            .window_init_opts = .{ .theme = ds.tokens.dvuiTheme() },
        });
        defer t.deinit();
        t.window.content_scale = scale / 2;
        LongState.selections = @splat(.{});
        _ = try dvui.testing.step(LongState.frame);
        try dvui.testing.settle(LongState.frame);
        dvui.debug.captureFrame();
        _ = try dvui.testing.step(LongState.frame);
        _ = try dvui.testing.step(LongState.frame);
        defer dvui.debug.clearCaptures(std.testing.allocator);
        const captured = dvui.debug.lastCapture() orelse return error.NoCapture;

        const window_right = 320 * scale / 2 * 2;
        const cases = [_]struct { file: []const u8, text: []const u8 }{
            .{ .file = "question_card.zig", .text = long_question },
            .{ .file = "question_card.zig", .text = long_description },
            .{ .file = "radio.zig", .text = long_label },
            .{ .file = "checkbox.zig", .text = long_label },
        };
        for (cases) |case| {
            const widget = shown(captured, case.file, case.text) orelse {
                std.debug.print("no widget from {s} shows \"{s}\"\n", .{ case.file, case.text });
                return error.TextNotShown;
            };
            // Wrapped: more than one line tall, and inside the window.
            const line = widget.font.lineHeight() * scale;
            if (widget.rect_content.h < 1.5 * line) {
                std.debug.print("scale {d}: {s}'s \"{s}…\" is {d:.1} px tall, one line is {d:.1} — cut to one line\n", .{ scale, case.file, case.text[0..12], widget.rect_content.h, line });
                return error.NotWrapped;
            }
            try std.testing.expect(widget.rect_border.x + widget.rect_border.w <= window_right + 0.5);
        }

        // The badge sits at the top of its row, level with the question's first line.
        const question = shown(captured, "question_card.zig", long_question).?;
        var badge_top: ?f32 = null;
        for (captured.widgets.items) |widget| {
            const label = widget.label orelse continue;
            if (std.mem.endsWith(u8, widget.src_file, "badge.zig") and std.mem.eql(u8, label, "Scope")) badge_top = widget.rect_margin.y;
        }
        try std.testing.expect(badge_top != null);
        try std.testing.expect(badge_top.? <= question.rect_margin.y + 8 * scale);
    }
}

test "a wrapped card still lints clean: the badge and each control fill their row's height, at its first line" {
    for (scales) |scale| {
        var t = try dvui.testing.init(.{
            .window_size = .{ .w = 320 * scale / 2, .h = 900 * scale / 2 },
            .window_init_opts = .{ .theme = ds.tokens.dvuiTheme() },
        });
        defer t.deinit();
        t.window.content_scale = scale / 2;
        LongState.selections = @splat(.{});
        _ = try dvui.testing.step(LongState.frame);
        try dvui.testing.settle(LongState.frame);
        dvui.debug.captureFrame();
        _ = try dvui.testing.step(LongState.frame);
        _ = try dvui.testing.step(LongState.frame);
        defer dvui.debug.clearCaptures(std.testing.allocator);
        // The engine's pane lint runs these rules over the live chat: a badge
        // or a circle at the top of a two-line row is "off the row's centre
        // line" there unless it stands in a lane as tall as the row.
        var findings: usize = 0;
        for ([_][]const u8{ "question_card.zig", "radio.zig", "checkbox.zig" }) |file| {
            const counts = try lint.run(std.testing.allocator, scale, file, true);
            findings += counts.total();
        }
        if (findings != 0) {
            std.debug.print("scale {d}: the wrapped card has {d} layout findings\n", .{ scale, findings });
            return error.LintFindings;
        }
    }
}

/// One option drawn twice, the plain way and the way that may wrap, each in its
/// own row: a one-line option must look the same either way.
const OneLineState = struct {
    var chosen = false;
    var size: ds.tokens.Size = .sm;

    fn frame() !dvui.App.Result {
        var background = dvui.box(@src(), .{ .dir = .vertical }, .{
            .expand = .both,
            .background = true,
            .color_fill = .{ .color = ds.tokens.current.surface_0 },
            .padding = dvui.Rect.all(8),
        });
        defer background.deinit();
        for ([_]bool{ false, true }, 0..) |wrap, index| {
            var row = dvui.box(@src(), .{ .dir = .vertical }, .{ .id_extra = index, .expand = .horizontal });
            defer row.deinit();
            _ = ds.radio(@src(), false, "Toon").size(size).wrap(wrap).draw();
            _ = ds.checkbox(@src(), &chosen).size(size).label("Music").wrap(wrap).draw();
        }
        return .ok;
    }
};

/// Where a control's parts sit inside its own row, relative to the row's top.
const ControlPlace = struct {
    row_height: f32,
    control_top: f32,
    words_top: f32,
};

fn widgetById(captured: *const dvui.Debug.CapturedFrame, id: dvui.Id) ?*const dvui.Debug.CapturedWidget {
    for (captured.widgets.items) |*widget| {
        if (widget.id == id) return widget;
    }
    return null;
}

/// The places of every control in `file` showing `text`, top to bottom.
fn controlPlaces(captured: *const dvui.Debug.CapturedFrame, file: []const u8, text: []const u8, places: *[2]ControlPlace) !void {
    var found: usize = 0;
    for (captured.widgets.items) |*words| {
        if (!std.mem.endsWith(u8, words.src_file, file)) continue;
        const label = words.label orelse continue;
        if (!std.mem.eql(u8, label, text)) continue;
        if (found == places.len) return error.TooManyControls;
        const root = widgetById(captured, words.parent_id) orelse return error.NoRow;
        var control: ?*const dvui.Debug.CapturedWidget = null;
        for (captured.widgets.items) |*candidate| {
            const name = candidate.name orelse continue;
            if (!std.mem.eql(u8, name, "Spacer")) continue;
            const parent = widgetById(captured, candidate.parent_id) orelse continue;
            if (parent.id == root.id or parent.parent_id == root.id) control = candidate;
        }
        const reserved = control orelse return error.NoControl;
        places[found] = .{
            .row_height = root.rect_border.h,
            .control_top = reserved.rect_border.y - root.rect_border.y,
            .words_top = words.rect_content.y - root.rect_border.y,
        };
        found += 1;
    }
    if (found != places.len) return error.ControlsMissing;
}

test "a one-line option looks the same whether or not it may wrap: the same row, control and words" {
    defer OneLineState.size = .sm;
    for ([_]ds.tokens.Size{ .sm, .md, .lg }) |size| for (scales) |scale| {
        OneLineState.size = size;
        var t = try dvui.testing.init(.{
            .window_size = .{ .w = 320 * scale / 2, .h = 400 * scale / 2 },
            .window_init_opts = .{ .theme = ds.tokens.dvuiTheme() },
        });
        defer t.deinit();
        t.window.content_scale = scale / 2;
        _ = try dvui.testing.step(OneLineState.frame);
        try dvui.testing.settle(OneLineState.frame);
        dvui.debug.captureFrame();
        _ = try dvui.testing.step(OneLineState.frame);
        _ = try dvui.testing.step(OneLineState.frame);
        defer dvui.debug.clearCaptures(std.testing.allocator);
        const captured = dvui.debug.lastCapture() orelse return error.NoCapture;

        for ([_][2][]const u8{ .{ "radio.zig", "Toon" }, .{ "checkbox.zig", "Music" } }) |case| {
            var places: [2]ControlPlace = undefined;
            try controlPlaces(captured, case[0], case[1], &places);
            const plain = places[0];
            const wrapping = places[1];
            const same = @abs(plain.row_height - wrapping.row_height) < 0.01 and
                @abs(plain.control_top - wrapping.control_top) < 0.01 and
                @abs(plain.words_top - wrapping.words_top) < 0.01;
            if (!same) {
                std.debug.print("scale {d}, {s}: {s} one line: row {d:.2} / {d:.2} px, control at {d:.2} / {d:.2}, words at {d:.2} / {d:.2} (plain / may wrap)\n", .{ scale, @tagName(size), case[0], plain.row_height, wrapping.row_height, plain.control_top, wrapping.control_top, plain.words_top, wrapping.words_top });
                return error.OneLineMoved;
            }
        }
    };
}

const head_questions = [_]ds.chat.Question{
    .{ .header = "Scope", .question = "Which look?", .options = &.{
        .{ .label = "Low-poly", .description = "Hard edges" },
    } },
};

/// A one-line question's card, then the head row and the description it drew
/// before its words could wrap (a label centred on the badge, a plain label).
const HeadState = struct {
    var selections: [head_questions.len]ds.chat.Selection = @splat(.{});

    fn frame() !dvui.App.Result {
        const theme = ds.tokens.current;
        var background = dvui.box(@src(), .{ .dir = .vertical }, .{
            .expand = .both,
            .background = true,
            .color_fill = .{ .color = theme.surface_0 },
            .padding = dvui.Rect.all(8),
        });
        defer background.deinit();
        _ = ds.chat.questionCard(@src(), &head_questions, &selections).draw();
        {
            var head = dvui.box(@src(), .{ .dir = .horizontal, .gap = theme.space_sm }, .{ .expand = .horizontal });
            defer head.deinit();
            ds.badge(@src(), "Scope").variant(.accent).draw();
            dvui.labelNoFmt(@src(), "Which look?", .{}, .{
                .color_text = .{ .color = theme.text_primary },
                .font = ds.fontMedium(theme.font_size_md),
                .gravity_y = 0.5,
            });
        }
        dvui.labelNoFmt(@src(), "Hard edges", .{}, .{
            .color_text = .{ .color = theme.text_muted },
            .font = ds.font(theme.font_size_sm),
            .padding = ds.paddingEach(0, theme.space_xs, theme.space_2xs, theme.space_xs),
        });
        return .ok;
    }
};

/// The `index`th captured widget from `file` showing exactly `text`.
fn shownAt(captured: *const dvui.Debug.CapturedFrame, file: []const u8, text: []const u8, index: usize) ?*const dvui.Debug.CapturedWidget {
    var seen: usize = 0;
    for (captured.widgets.items) |*widget| {
        if (!std.mem.endsWith(u8, widget.src_file, file)) continue;
        const label = widget.label orelse continue;
        if (!std.mem.eql(u8, label, text)) continue;
        if (seen == index) return widget;
        seen += 1;
    }
    return null;
}

test "a one-line question and description sit as they did before they could wrap" {
    for (scales) |scale| {
        var t = try dvui.testing.init(.{
            .window_size = .{ .w = 480 * scale / 2, .h = 600 * scale / 2 },
            .window_init_opts = .{ .theme = ds.tokens.dvuiTheme() },
        });
        defer t.deinit();
        t.window.content_scale = scale / 2;
        HeadState.selections = @splat(.{});
        _ = try dvui.testing.step(HeadState.frame);
        try dvui.testing.settle(HeadState.frame);
        dvui.debug.captureFrame();
        _ = try dvui.testing.step(HeadState.frame);
        _ = try dvui.testing.step(HeadState.frame);
        defer dvui.debug.clearCaptures(std.testing.allocator);
        const captured = dvui.debug.lastCapture() orelse return error.NoCapture;

        // The head row: its height, the badge and the question's words.
        const card_words = shownAt(captured, "question_card.zig", "Which look?", 0) orelse return error.NoQuestion;
        const plain_words = shownAt(captured, "question_card_tests.zig", "Which look?", 0) orelse return error.NoQuestion;
        const card_badge = shownAt(captured, "badge.zig", "Scope", 0) orelse return error.NoBadge;
        const plain_badge = shownAt(captured, "badge.zig", "Scope", 1) orelse return error.NoBadge;
        const card_row = widgetById(captured, card_words.parent_id) orelse return error.NoRow;
        const plain_row = widgetById(captured, plain_words.parent_id) orelse return error.NoRow;
        const head_same = @abs(card_row.rect_border.h - plain_row.rect_border.h) < 0.01 and
            @abs((card_badge.rect_border.y - card_row.rect_border.y) - (plain_badge.rect_border.y - plain_row.rect_border.y)) < 0.01 and
            @abs((card_words.rect_content.y - card_row.rect_border.y) - (plain_words.rect_content.y - plain_row.rect_border.y)) < 0.01;
        if (!head_same) {
            std.debug.print("scale {d}: head row {d:.2} / {d:.2} px, badge at {d:.2} / {d:.2}, words at {d:.2} / {d:.2} (card / plain)\n", .{
                scale,
                card_row.rect_border.h,
                plain_row.rect_border.h,
                card_badge.rect_border.y - card_row.rect_border.y,
                plain_badge.rect_border.y - plain_row.rect_border.y,
                card_words.rect_content.y - card_row.rect_border.y,
                plain_words.rect_content.y - plain_row.rect_border.y,
            });
            return error.HeadMoved;
        }

        // The description: as tall, its words as far down.
        const card_note = shownAt(captured, "question_card.zig", "Hard edges", 0) orelse return error.NoDescription;
        const plain_note = shownAt(captured, "question_card_tests.zig", "Hard edges", 0) orelse return error.NoDescription;
        const note_same = @abs(card_note.rect_margin.h - plain_note.rect_margin.h) < 0.01 and
            @abs((card_note.rect_content.y - card_note.rect_margin.y) - (plain_note.rect_content.y - plain_note.rect_margin.y)) < 0.01;
        if (!note_same) {
            std.debug.print("scale {d}: description {d:.2} / {d:.2} px tall, words {d:.2} / {d:.2} down (card / plain)\n", .{
                scale,
                card_note.rect_margin.h,
                plain_note.rect_margin.h,
                card_note.rect_content.y - card_note.rect_margin.y,
                plain_note.rect_content.y - plain_note.rect_margin.y,
            });
            return error.DescriptionMoved;
        }
    }
}
