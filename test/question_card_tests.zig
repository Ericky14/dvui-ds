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
