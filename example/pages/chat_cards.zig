/// Storybook page: the chat cards (tool, approval, question, screenshot, plan,
/// error, checkpoint) from ds.chat.*. Owned by the "chat cards" work; the
/// message/markdown/composer page is `chat.zig`.
const std = @import("std");
const dvui = @import("dvui");
const ds = @import("dvui_ds");

var tool_collapsed: bool = false;
var tool_expanded: bool = true;
var selections: [2]ds.chat.Selection = .{ .{}, .{} };
var note_buffer: [128]u8 = @splat(0);
var other_buffer: [128]u8 = @splat(0);
var last_approval: ds.chat.ApprovalChoice = .none;
var last_plan: ds.chat.PlanChoice = .none;
var submitted_count: usize = 0;
var screenshot_clicks: usize = 0;
var fix_clicks: usize = 0;
var undo_clicks: usize = 0;

const questions = [_]ds.chat.Question{
    .{ .header = "Format", .question = "How should I format the output?", .options = &.{
        .{ .label = "Summary", .description = "Brief overview" },
        .{ .label = "Detailed", .description = "Full explanation" },
    } },
    .{ .header = "Sections", .question = "Which sections should I include?", .multi_select = true, .options = &.{
        .{ .label = "Introduction", .description = "Opening context" },
        .{ .label = "Conclusion", .description = "Final summary" },
        .{ .label = "Appendix" },
    } },
};

const plan_sample =
    \\1. Spawn a sphere entity with a `MeshRenderer` and a red material.
    \\2. Attach `scripts/ball.lua` with gravity and a floor bounce.
    \\3. Screenshot and verify the contact point.
;

const compiler_sample =
    \\src/main.zig:12:5: error: expected ';' after statement
    \\    const ball = spawn("ball")
    \\    ^
;

// ─── A procedural "screenshot": sky gradient, floor, red ball ────────────────
// Built once so the page demos a raster source at a real size (no binary asset).
const shot_w = 320;
const shot_h = 180;
var shot_buf: [shot_w * shot_h * 4]u8 = undefined;
var shot_filled = false;

fn screenshotSource() ds.Source {
    if (!shot_filled) {
        const horizon = shot_h * 2 / 3;
        const ball_x: i32 = shot_w / 2;
        const ball_y: i32 = horizon - 22;
        const ball_r: i32 = 22;
        var y: usize = 0;
        while (y < shot_h) : (y += 1) {
            var x: usize = 0;
            while (x < shot_w) : (x += 1) {
                const index = (y * shot_w + x) * 4;
                const dx: i32 = @as(i32, @intCast(x)) - ball_x;
                const dy: i32 = @as(i32, @intCast(y)) - ball_y;
                if (dx * dx + dy * dy <= ball_r * ball_r) {
                    shot_buf[index + 0] = 232;
                    shot_buf[index + 1] = 90;
                    shot_buf[index + 2] = 90;
                } else if (y < horizon) {
                    // Sky: dark navy fading toward the horizon.
                    const t: u32 = @intCast(y * 255 / horizon);
                    shot_buf[index + 0] = @intCast(20 + t * 30 / 255);
                    shot_buf[index + 1] = @intCast(28 + t * 50 / 255);
                    shot_buf[index + 2] = @intCast(60 + t * 80 / 255);
                } else {
                    // Floor: a flat slate with a subtle grid.
                    const grid = (x % 32 == 0) or (y % 16 == 0);
                    const base: u8 = if (grid) 70 else 52;
                    shot_buf[index + 0] = base;
                    shot_buf[index + 1] = base + 4;
                    shot_buf[index + 2] = base + 10;
                }
                shot_buf[index + 3] = 255;
            }
        }
        shot_filled = true;
    }
    return ds.Source.pixels(&shot_buf, shot_w, shot_h);
}

pub fn draw() void {
    const theme = ds.tokens.current;
    var col = ds.column(@src()).gap(theme.space_md).expand(.horizontal).draw();
    defer col.deinit();

    ds.label(@src(), "Chat cards").style(.title).draw();
    ds.label(@src(), "toolCard / approvalCard / questionCard / screenshotCard / planCard / errorCard / checkpoint").style(.muted).draw();

    // ─── Tool cards: every status, then collapsed / expanded with details ───
    ds.label(@src(), "Tool cards").style(.secondary).font(.heading).draw();
    {
        var stack = ds.column(@src()).gap(theme.space_xs).expand(.horizontal).draw();
        defer stack.deinit();
        ds.chat.toolCard(@src(), "screenshot", "waiting for the frame", .running).draw();
        ds.chat.toolCard(@src(), "set_component", "Ball / MeshRenderer.color", .ok).draw();
        ds.chat.toolCard(@src(), "zig build", "2 errors", .failed).draw();
        ds.chat.toolCard(@src(), "Bash", "rm -rf build/ and a much longer summary that keeps going so it has to be ellipsized on one line", .denied).draw();
        ds.chat.toolCard(@src(), "Read", "src/main.zig", .ok).details("const std = @import(\"std\");\npub fn main() void {}").expanded(&tool_collapsed).draw();
        ds.chat.toolCard(@src(), "set_component", "Ball / MeshRenderer.color", .ok).details("{ \"entity\": 3, \"color\": [1, 0, 0, 1] }\n{ \"ok\": true }").expanded(&tool_expanded).draw();
    }

    // ─── Approval: without and with the note input ──────────────────────────
    ds.label(@src(), "Approval").style(.secondary).font(.heading).draw();
    {
        var stack = ds.column(@src()).gap(theme.space_sm).expand(.horizontal).draw();
        defer stack.deinit();
        const plain = ds.chat.approvalCard(@src(), "Run `zig build check` in the project?", "zig build check").draw();
        if (plain != .none) last_approval = plain;
        const with_note = ds.chat.approvalCard(@src(), "Delete the build directory?", "The agent wants to clear stale artifacts before rebuilding.").note(&note_buffer).draw();
        if (with_note != .none) last_approval = with_note;
        dvui.label(@src(), "last choice: {s}", .{@tagName(last_approval)}, .{ .color_text = .{ .color = theme.text_muted }, .font = ds.font(theme.font_size_sm) });
    }

    // ─── Questions: a single-select and a multi-select, with "Other" ────────
    ds.label(@src(), "Questions").style(.secondary).font(.heading).draw();
    if (ds.chat.questionCard(@src(), &questions, &selections).other(&other_buffer).draw()) submitted_count += 1;
    dvui.label(@src(), "submitted {d} time(s)", .{submitted_count}, .{ .color_text = .{ .color = theme.text_muted }, .font = ds.font(theme.font_size_sm) });

    // ─── Screenshot: a raster source scaled to fit ──────────────────────────
    ds.label(@src(), "Screenshot").style(.secondary).font(.heading).draw();
    if (ds.chat.screenshotCard(@src(), "preview after the change", screenshotSource()).maxWidth(280).draw()) screenshot_clicks += 1;
    dvui.label(@src(), "opened {d} time(s)", .{screenshot_clicks}, .{ .color_text = .{ .color = theme.text_muted }, .font = ds.font(theme.font_size_sm) });

    // ─── Plan ───────────────────────────────────────────────────────────────
    ds.label(@src(), "Plan").style(.secondary).font(.heading).draw();
    const plan = ds.chat.planCard(@src(), "Add a bouncing ball", plan_sample).draw();
    if (plan != .none) last_plan = plan;
    dvui.label(@src(), "last verdict: {s}", .{@tagName(last_plan)}, .{ .color_text = .{ .color = theme.text_muted }, .font = ds.font(theme.font_size_sm) });

    // ─── Errors: a runtime message and compiler output ──────────────────────
    ds.label(@src(), "Errors").style(.secondary).font(.heading).draw();
    {
        var stack = ds.column(@src()).gap(theme.space_sm).expand(.horizontal).draw();
        defer stack.deinit();
        if (ds.chat.errorCard(@src(), "attempt to index a nil value (global 'ball')", "scripts/ball.lua:12").draw()) fix_clicks += 1;
        if (ds.chat.errorCard(@src(), compiler_sample, null).draw()) fix_clicks += 1;
        dvui.label(@src(), "fix requested {d} time(s)", .{fix_clicks}, .{ .color_text = .{ .color = theme.text_muted }, .font = ds.font(theme.font_size_sm) });
    }

    // ─── Checkpoint ─────────────────────────────────────────────────────────
    ds.label(@src(), "Checkpoint").style(.secondary).font(.heading).draw();
    if (ds.chat.checkpoint(@src(), "turn 7 / 2 files").draw()) undo_clicks += 1;
    dvui.label(@src(), "undo clicked {d} time(s)", .{undo_clicks}, .{ .color_text = .{ .color = theme.text_muted }, .font = ds.font(theme.font_size_sm) });
}
