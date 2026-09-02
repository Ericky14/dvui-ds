//! Screenshot fixtures for the chat message widgets (ds.chat.message / markdown /
//! codeBlock / composer). Run: `zig build screenshots`. Add one `test` per state.
const std = @import("std");
const dvui = @import("dvui");
const ds = @import("dvui_ds");
const shots = @import("screenshots.zig");

var composer_buffer: [128]u8 = @splat(0);

test "chat messages" {
    const Local = struct {
        fn frame() !dvui.App.Result {
            var bg = shots.background(@src());
            defer bg.deinit();
            var col = ds.column(@src()).padding(ds.tokens.current.space_md).gap(ds.tokens.current.space_sm).expand(.horizontal).draw();
            defer col.deinit();
            ds.chat.message(@src(), .user, "make the ball red").draw();
            ds.chat.message(@src(), .assistant, "Done. The ball is **red** now.").draw();
            ds.chat.message(@src(), .assistant, "Checking the floor contact").streaming(true).draw();
            _ = ds.chat.composer(@src(), &composer_buffer).draw();
            return .ok;
        }
    };
    try shots.capture("chat_messages.png", 420, 300, Local.frame);
}
