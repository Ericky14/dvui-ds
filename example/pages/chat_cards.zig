/// Storybook page: the chat cards (tool, approval, question, screenshot, plan,
/// error, checkpoint) from ds.chat.*. Owned by the "chat cards" work; the
/// message/markdown/composer page is `chat.zig`.
const std = @import("std");
const dvui = @import("dvui");
const ds = @import("dvui_ds");

var tool_expanded: bool = false;
var selections: [2]ds.chat.Selection = .{ .{}, .{} };
var note_buffer: [128]u8 = @splat(0);
var other_buffer: [128]u8 = @splat(0);

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
    \\1. Spawn a sphere entity with a `MeshRenderer` and a red material.
    \\2. Attach `scripts/ball.lua` with gravity and a floor bounce.
    \\3. Screenshot and verify the contact point.
;

pub fn draw() void {
    const theme = ds.tokens.current;
    var col = ds.column(@src()).gap(theme.space_md).expand(.horizontal).draw();
    defer col.deinit();

    ds.label(@src(), "Chat cards").style(.title).draw();
    ds.label(@src(), "toolCard / approvalCard / questionCard / screenshotCard / planCard / errorCard / checkpoint").style(.muted).draw();

    ds.chat.toolCard(@src(), "set_component", "Ball / MeshRenderer.color", .ok).details("{ \"entity\": 3, \"color\": [1, 0, 0, 1] }").expanded(&tool_expanded).draw();
    ds.chat.toolCard(@src(), "screenshot", "waiting for the frame", .running).idExtra(1).draw();
    ds.chat.toolCard(@src(), "Bash", "rm -rf build/", .denied).idExtra(2).draw();
    ds.chat.toolCard(@src(), "zig build", "2 errors", .failed).idExtra(3).draw();

    _ = ds.chat.approvalCard(@src(), "Run `zig build check` in the project?", "The agent wants to verify the script compiles.").note(&note_buffer).draw();

    _ = ds.chat.questionCard(@src(), &questions, &selections).other(&other_buffer).draw();

    _ = ds.chat.screenshotCard(@src(), "preview after the change", ds.Source.namedIcon("image", ds.icons.image)).draw();

    _ = ds.chat.planCard(@src(), "Add a bouncing ball", plan_sample).draw();

    _ = ds.chat.errorCard(@src(), "attempt to index a nil value (global 'ball')", "scripts/ball.lua:12").draw();

    _ = ds.chat.checkpoint(@src(), "turn 7 / 2 files").draw();
}
