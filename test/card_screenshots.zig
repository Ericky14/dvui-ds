//! Screenshot fixtures for the chat cards (ds.chat.toolCard / approvalCard /
//! questionCard / screenshotCard / planCard / errorCard / checkpoint).
//! Run: `zig build screenshots`. One `test` per widget; every fixture gives the
//! widget a real size (a width-only widget collapses to zero height).
const std = @import("std");
const dvui = @import("dvui");
const ds = @import("dvui_ds");
const shots = @import("screenshots.zig");

var tool_collapsed: bool = false;
var tool_expanded: bool = true;
var note_buffer: [64]u8 = @splat(0);
var other_buffer: [64]u8 = @splat(0);
var selections: [2]ds.chat.Selection = .{ .{}, .{} };

const questions = [_]ds.chat.Question{
    .{ .header = "Format", .question = "How should I format the output?", .options = &.{
        .{ .label = "Summary", .description = "Brief overview" },
        .{ .label = "Detailed", .description = "Full explanation" },
    } },
    .{ .header = "Sections", .question = "Which sections should I include?", .multi_select = true, .options = &.{
        .{ .label = "Introduction", .description = "Opening context" },
        .{ .label = "Conclusion", .description = "Final summary" },
    } },
};

const plan_sample =
    \\1. Spawn a sphere with a red `MeshRenderer`.
    \\2. Attach `scripts/ball.lua` with a floor bounce.
    \\3. Screenshot and verify the contact point.
;

const compiler_sample =
    \\src/main.zig:12:5: error: expected ';' after statement
    \\    const ball = spawn("ball")
;

/// Shared frame chrome: themed background + padded column.
fn column(src: std.builtin.SourceLocation) *dvui.BoxWidget {
    return ds.column(src).padding(ds.tokens.current.space_md).gap(ds.tokens.current.space_sm).expand(.horizontal).draw();
}

// Every tool status, then a collapsed and an expanded card with details.
test "chat tool cards" {
    const Local = struct {
        fn frame() !dvui.App.Result {
            var bg = shots.background(@src());
            defer bg.deinit();
            var col = column(@src());
            defer col.deinit();
            ds.chat.toolCard(@src(), "screenshot", "waiting for the frame", .running).draw();
            ds.chat.toolCard(@src(), "set_component", "Ball / MeshRenderer.color", .ok).draw();
            ds.chat.toolCard(@src(), "zig build", "2 errors", .failed).draw();
            ds.chat.toolCard(@src(), "Bash", "rm -rf build/ and a very long summary that has to be ellipsized to stay on one line", .denied).draw();
            ds.chat.toolCard(@src(), "Read", "src/main.zig", .ok).details("const std = @import(\"std\");").expanded(&tool_collapsed).draw();
            ds.chat.toolCard(@src(), "set_component", "Ball / MeshRenderer.color", .ok).details("{ \"entity\": 3, \"color\": [1, 0, 0, 1] }\n{ \"ok\": true }").expanded(&tool_expanded).draw();
            return .ok;
        }
    };
    // The running dot pulses forever; reduced motion holds it steady so the
    // headless frame can settle.
    dvui.reduce_motion = true;
    defer dvui.reduce_motion = false;
    try shots.capture("chat_tool_cards.png", 420, 380, Local.frame);
}

// A command detail (mono) without the note, then a prose detail with the note.
test "chat approval card" {
    const Local = struct {
        fn frame() !dvui.App.Result {
            var bg = shots.background(@src());
            defer bg.deinit();
            var col = column(@src());
            defer col.deinit();
            _ = ds.chat.approvalCard(@src(), "Run `zig build check` in the project?", "zig build check").draw();
            _ = ds.chat.approvalCard(@src(), "Delete the build directory?", "The agent wants to clear stale artifacts.").note(&note_buffer).draw();
            return .ok;
        }
    };
    try shots.capture("chat_approval_card.png", 420, 330, Local.frame);
}

// Two questions (single + multi), one option chosen, the "Other" input, Submit disabled.
test "chat question card" {
    const Local = struct {
        fn frame() !dvui.App.Result {
            var bg = shots.background(@src());
            defer bg.deinit();
            var col = column(@src());
            defer col.deinit();
            _ = ds.chat.questionCard(@src(), &questions, &selections).other(&other_buffer).draw();
            return .ok;
        }
    };
    selections[0].chosen[1] = true;
    try shots.capture("chat_question_card.png", 420, 420, Local.frame);
}

// A 240×135 raster scaled to fit maxWidth(200), with the caption row.
test "chat screenshot card" {
    const Local = struct {
        const w = 240;
        const h = 135;
        var buf: [w * h * 4]u8 = undefined;
        var filled = false;
        fn img() ds.Source {
            if (!filled) {
                const horizon = h * 2 / 3;
                var y: usize = 0;
                while (y < h) : (y += 1) {
                    var x: usize = 0;
                    while (x < w) : (x += 1) {
                        const index = (y * w + x) * 4;
                        if (y < horizon) {
                            const t: u32 = @intCast(y * 255 / horizon);
                            buf[index + 0] = @intCast(20 + t * 30 / 255);
                            buf[index + 1] = @intCast(28 + t * 50 / 255);
                            buf[index + 2] = @intCast(60 + t * 80 / 255);
                        } else {
                            const grid = (x % 24 == 0) or (y % 12 == 0);
                            const base: u8 = if (grid) 70 else 52;
                            buf[index + 0] = base;
                            buf[index + 1] = base + 4;
                            buf[index + 2] = base + 10;
                        }
                        buf[index + 3] = 255;
                    }
                }
                filled = true;
            }
            return ds.Source.pixels(&buf, w, h);
        }
        fn frame() !dvui.App.Result {
            var bg = shots.background(@src());
            defer bg.deinit();
            var col = column(@src());
            defer col.deinit();
            _ = ds.chat.screenshotCard(@src(), "preview after the change", img()).maxWidth(200).draw();
            return .ok;
        }
    };
    try shots.capture("chat_screenshot_card.png", 320, 190, Local.frame);
}

// Eyebrow, heading title, markdown body, the three verdict buttons.
test "chat plan card" {
    const Local = struct {
        fn frame() !dvui.App.Result {
            var bg = shots.background(@src());
            defer bg.deinit();
            var col = column(@src());
            defer col.deinit();
            _ = ds.chat.planCard(@src(), "Add a bouncing ball", plan_sample).draw();
            return .ok;
        }
    };
    try shots.capture("chat_plan_card.png", 420, 230, Local.frame);
}

// A prose runtime error with a location, then compiler output (mono, no location).
test "chat error card" {
    const Local = struct {
        fn frame() !dvui.App.Result {
            var bg = shots.background(@src());
            defer bg.deinit();
            var col = column(@src());
            defer col.deinit();
            _ = ds.chat.errorCard(@src(), "attempt to index a nil value (global 'ball')", "scripts/ball.lua:12").draw();
            _ = ds.chat.errorCard(@src(), compiler_sample, null).draw();
            return .ok;
        }
    };
    try shots.capture("chat_error_card.png", 420, 230, Local.frame);
}

// Hairline — label — Undo — hairline, one caption line tall.
test "chat checkpoint" {
    const Local = struct {
        fn frame() !dvui.App.Result {
            var bg = shots.background(@src());
            defer bg.deinit();
            var col = column(@src());
            defer col.deinit();
            _ = ds.chat.checkpoint(@src(), "turn 7 / 2 files").draw();
            return .ok;
        }
    };
    try shots.capture("chat_checkpoint.png", 420, 50, Local.frame);
}
