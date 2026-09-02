/// Storybook page: chat messages, markdown, code block, composer (ds.chat.*).
/// Owned by the "chat widgets" work; the cards page is `chat_cards.zig`.
const std = @import("std");
const dvui = @import("dvui");
const ds = @import("dvui_ds");

var composer_buffer: [512]u8 = @splat(0);

const markdown_sample =
    \\## Heading
    \\A paragraph with **bold**, *italic* and `inline code`.
    \\
    \\- first item
    \\- second item
    \\
    \\1. step one
    \\2. step two
;

const lua_sample =
    \\function on_update(dt)
    \\  ball.velocity.y = ball.velocity.y - 9.8 * dt
    \\end
;

pub fn draw() void {
    const theme = ds.tokens.current;
    var col = ds.column(@src()).gap(theme.space_md).expand(.horizontal).draw();
    defer col.deinit();

    ds.label(@src(), "Chat").style(.title).draw();
    ds.label(@src(), "message / markdown / codeBlock / composer").style(.muted).draw();

    ds.chat.message(@src(), .user, "make the ball red and have it bounce on the floor").draw();
    ds.chat.message(@src(), .assistant, "Done. The ball is **red** and bounces with restitution `0.8`.").draw();
    ds.chat.message(@src(), .assistant, "Thinking about the floor contact").streaming(true).draw();
    ds.chat.message(@src(), .system, "session resumed").draw();

    ds.chat.markdown(@src(), markdown_sample).draw();

    _ = ds.chat.codeBlock(@src(), "lua", lua_sample).draw();

    _ = ds.chat.composer(@src(), &composer_buffer).draw();
    _ = ds.chat.composer(@src(), &composer_buffer).busy(true).idExtra(1).draw();
}
