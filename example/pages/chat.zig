/// Storybook page: chat messages, markdown, code block, composer (ds.chat.*).
/// Owned by the "chat widgets" work; the cards page is `chat_cards.zig`.
const std = @import("std");
const dvui = @import("dvui");
const ds = @import("dvui_ds");

var composer_buffer: [512]u8 = @splat(0);
var busy_buffer: [512]u8 = @splat(0);
var last_composer_event: []const u8 = "nothing yet";
var copies: usize = 0;

/// Every construct the markdown-lite grammar supports, plus malformed input.
const markdown_sample =
    \\# Heading one
    \\## Heading two
    \\### Heading three
    \\A paragraph with **bold**, *italic*, ***both***, `inline code` and a
    \\[link](https://example.test) that soft-wraps across source lines.
    \\
    \\- first item
    \\- second item with **bold** and `code`
    \\  - nested item
    \\* star bullet
    \\
    \\1. step one
    \\2. step two
    \\10. step ten wraps when the item text is long enough to need more than one line
    \\
    \\```lua
    \\local speed = 9.8 * dt
    \\```
    \\Unbalanced **markers, a `stray backtick and 2 * 3 render literally.
;

/// Tab-indented on purpose: the code block renders tabs as four-column gaps.
const lua_sample = "function on_update(dt)\n" ++
    "\tball.velocity.y = ball.velocity.y - 9.8 * dt\n" ++
    "\tif ball.position.y < floor then ball.velocity.y = -ball.velocity.y * restitution end -- long line scrolls horizontally\n" ++
    "end";

const long_user_text = "Make the ball red, have it bounce on the floor with a restitution of 0.8, and add a faint trail behind it so the motion reads clearly at a distance.";

/// A long inline code span that lands right at the pane edge: it must wrap to
/// a fresh line as a whole chip rather than splitting mid-word.
const code_wrap_sample =
    \\Open `scenes/main.json`, then confirm the gate with
    \\`zigame.physics.is_grounded(self.id)` before wiring the trigger.
;

pub fn draw() void {
    const theme = ds.tokens.current;
    // The page is taller than the window; scroll it (the storybook content area does not).
    var scroll = ds.scrollArea(@src()).draw();
    defer scroll.deinit();
    var col = ds.column(@src()).gap(theme.space_md).expand(.horizontal).draw();
    defer col.deinit();

    ds.label(@src(), "Chat").style(.title).draw();
    ds.label(@src(), "message / markdown / codeBlock / composer").style(.muted).draw();

    // ─── Messages ────────────────────────────────────────────────────────
    ds.label(@src(), "Messages").style(.secondary).font(.heading).draw();
    ds.chat.message(@src(), .user, "make the ball red and have it bounce on the floor").draw();
    ds.chat.message(@src(), .assistant, "Done. The ball is **red** and bounces with restitution `0.8`.").draw();
    ds.chat.message(@src(), .user, long_user_text).draw();
    ds.chat.message(@src(), .assistant, "Plain text mode: **no** markdown here.").markdown(false).draw();
    ds.chat.message(@src(), .assistant, "Thinking about the floor contact").streaming(true).draw();
    ds.chat.message(@src(), .assistant, "").streaming(true).idExtra(1).draw();
    ds.chat.message(@src(), .system, "session resumed").draw();

    // ─── Markdown ────────────────────────────────────────────────────────
    ds.label(@src(), "Markdown").style(.secondary).font(.heading).draw();
    ds.chat.markdown(@src(), markdown_sample).draw();

    ds.label(@src(), "Inline code chip wrap").style(.secondary).font(.heading).draw();
    {
        // Narrow on purpose to force the long chip past the edge of the pane.
        var narrow = dvui.box(@src(), .{ .dir = .vertical }, .{
            .min_size_content = .{ .w = 260, .h = 0 },
            .max_size_content = .{ .w = 260, .h = dvui.max_float_safe },
        });
        defer narrow.deinit();
        ds.chat.markdown(@src(), code_wrap_sample).draw();
    }

    // ─── Code block ──────────────────────────────────────────────────────
    ds.label(@src(), "Code block").style(.secondary).font(.heading).draw();
    if (ds.chat.codeBlock(@src(), "lua", lua_sample).draw()) {
        dvui.clipboardTextSet(lua_sample);
        copies += 1;
    }
    _ = ds.chat.codeBlock(@src(), "", "no language tag").idExtra(1).draw();
    dvui.label(@src(), "copied {d} time(s)", .{copies}, .{ .color_text = .{ .color = theme.text_muted }, .font = ds.font(theme.font_size_sm) });

    // ─── Composer ────────────────────────────────────────────────────────
    ds.label(@src(), "Composer").style(.secondary).font(.heading).draw();
    const idle = ds.chat.composer(@src(), &composer_buffer).draw();
    if (idle.submitted) {
        last_composer_event = "submitted";
        @memset(&composer_buffer, 0);
    }
    if (idle.attach_clicked) last_composer_event = "attach clicked";

    const running = ds.chat.composer(@src(), &busy_buffer).busy(true).placeholder("Type the next message while the agent works…").idExtra(1).draw();
    if (running.interrupted) last_composer_event = "interrupted";
    if (running.submitted) last_composer_event = "submitted while busy";
    if (running.attach_clicked) last_composer_event = "attach clicked (busy)";

    dvui.label(@src(), "last composer event: {s}", .{last_composer_event}, .{ .color_text = .{ .color = theme.text_muted }, .font = ds.font(theme.font_size_sm) });
}
