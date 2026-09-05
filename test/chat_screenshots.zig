//! Screenshot fixtures for the chat message widgets (ds.chat.message / markdown /
//! codeBlock / composer). Run: `zig build screenshots`. One `test` per state group.
const std = @import("std");
const dvui = @import("dvui");
const ds = @import("dvui_ds");
const shots = @import("screenshots.zig");
const composer_demo = @import("composer_demo");

var composer_buffer: [128]u8 = @splat(0);
var busy_buffer: [128]u8 = @splat(0);

fn chatColumn(src: std.builtin.SourceLocation) *dvui.BoxWidget {
    return ds.column(src).padding(ds.tokens.current.space_md).gap(ds.tokens.current.space_sm).expand(.horizontal).draw();
}

test "chat messages" {
    const Local = struct {
        fn frame() !dvui.App.Result {
            var bg = shots.background(@src());
            defer bg.deinit();
            var col = chatColumn(@src());
            defer col.deinit();
            ds.chat.message(@src(), .user, "make the ball red").draw();
            ds.chat.message(@src(), .assistant, "Done. The ball is **red** now, with restitution `0.8`.").draw();
            ds.chat.message(@src(), .user, "Now make it bounce on the floor and add a faint trail so the motion reads clearly at a distance.").draw();
            ds.chat.message(@src(), .assistant, "Plain text mode keeps **markers** literal.").markdown(false).draw();
            ds.chat.message(@src(), .system, "session resumed").draw();
            return .ok;
        }
    };
    try shots.capture("chat_messages.png", 420, 300, Local.frame);
}

test "chat streaming" {
    const Local = struct {
        fn frame() !dvui.App.Result {
            var bg = shots.background(@src());
            defer bg.deinit();
            var col = chatColumn(@src());
            defer col.deinit();
            ds.chat.message(@src(), .assistant, "Checking the floor contact").streaming(true).draw();
            ds.chat.message(@src(), .assistant, "").streaming(true).idExtra(1).draw();
            ds.chat.message(@src(), .system, "waiting for the agent").draw();
            return .ok;
        }
    };
    try shots.capture("chat_streaming.png", 420, 150, Local.frame);
}

test "chat markdown" {
    const Local = struct {
        const sample =
            \\# Heading one
            \\## Heading two
            \\### Heading three
            \\A paragraph with **bold**, *italic*, ***both***, `inline code` and a
            \\[link](https://example.test) that soft-wraps across source lines.
            \\
            \\- first item
            \\- second item with **bold**
            \\  - nested item
            \\
            \\1. step one
            \\2. step two
            \\
            \\```lua
            \\local speed = 9.8 * dt
            \\```
            \\Unbalanced **markers and a `stray backtick render literally.
        ;
        fn frame() !dvui.App.Result {
            var bg = shots.background(@src());
            defer bg.deinit();
            var col = chatColumn(@src());
            defer col.deinit();
            ds.chat.markdown(@src(), sample).draw();
            return .ok;
        }
    };
    try shots.capture("chat_markdown.png", 460, 520, Local.frame);
}

test "chat code block" {
    const Local = struct {
        // Tab-indented on purpose: tabs render as four-column gaps.
        const code = "function on_update(dt)\n" ++
            "\tball.velocity.y = ball.velocity.y - 9.8 * dt\n" ++
            "\tif ball.position.y < floor then ball.velocity.y = -ball.velocity.y * 0.8 end\n" ++
            "end";
        fn frame() !dvui.App.Result {
            var bg = shots.background(@src());
            defer bg.deinit();
            var col = chatColumn(@src());
            defer col.deinit();
            _ = ds.chat.codeBlock(@src(), "lua", code).draw();
            _ = ds.chat.codeBlock(@src(), "", "no language tag").idExtra(1).draw();
            return .ok;
        }
    };
    try shots.capture("chat_code_block.png", 420, 220, Local.frame);
}

test "chat markdown code chip wrap" {
    const Local = struct {
        // Deliberately narrow: the prose runs right up to the pane edge so the
        // long inline code span that follows cannot fit on the same line but
        // would fit a fresh one — the case that used to split the chip mid-word.
        const sample =
            \\Open `scenes/main.json`, then confirm the gate with
            \\`zigame.physics.is_grounded(self.id)` before wiring the trigger.
        ;
        fn frame() !dvui.App.Result {
            var bg = shots.background(@src());
            defer bg.deinit();
            var col = chatColumn(@src());
            defer col.deinit();
            ds.chat.markdown(@src(), sample).draw();
            return .ok;
        }
    };
    try shots.capture("chat_markdown_code_wrap.png", 320, 170, Local.frame);
}

test "chat markdown code chip glue" {
    const Local = struct {
        // The break that keeps a chip whole is spent from the blank before it, so
        // nothing that isn't in the source can be selected and copied. The second
        // chip is glued to a "(" and has no blank to spend: it wraps at its own
        // character boundaries like any other long word, rather than being torn
        // off the bracket it belongs to.
        const sample =
            \\Call `zigame.physics.set_gravity(0, -9.8)` first.
            \\
            \\Then read (`zigame.physics.is_grounded(self.id)`) once.
        ;
        fn frame() !dvui.App.Result {
            var bg = shots.background(@src());
            defer bg.deinit();
            var col = chatColumn(@src());
            defer col.deinit();
            ds.chat.markdown(@src(), sample).draw();
            return .ok;
        }
    };
    try shots.capture("chat_markdown_code_glue.png", 320, 200, Local.frame);
}

test "chat composer" {
    const Local = struct {
        fn frame() !dvui.App.Result {
            var bg = shots.background(@src());
            defer bg.deinit();
            var col = chatColumn(@src());
            defer col.deinit();
            _ = ds.chat.composer(@src(), &composer_buffer).draw();
            _ = ds.chat.composer(@src(), &busy_buffer).busy(true).idExtra(1).draw();
            return .ok;
        }
    };
    const draft = "make the ball red and\nhave it bounce";
    @memcpy(composer_buffer[0..draft.len], draft);
    try shots.capture("chat_composer.png", 420, 210, Local.frame);
}

// The composer's five states, from the same page the storybook runs, at the two
// scales the chrome has to survive. 1.75 is where the owner's display sits and
// where a half-pixel inset shows.
/// Click the last composer so the "focused" state in the fixture is real focus,
/// not a flag.
fn focusLastComposer() anyerror!void {
    try dvui.testing.moveTo("composer.focused");
    try dvui.testing.click(.left);
}

test "composer states at scale 1.0" {
    try shots.captureDriven("composer_states_1x.png", 470, 660, 1.0, composer_demo.frame, focusLastComposer);
}

test "composer states at scale 1.75" {
    try shots.captureDriven("composer_states_175x.png", 470, 660, 1.75, composer_demo.frame, focusLastComposer);
}
