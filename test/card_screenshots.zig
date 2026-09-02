//! Screenshot fixtures for the chat cards (ds.chat.toolCard / approvalCard /
//! questionCard / screenshotCard / planCard / errorCard / checkpoint).
//! Run: `zig build screenshots`. Add one `test` per state.
const std = @import("std");
const dvui = @import("dvui");
const ds = @import("dvui_ds");
const shots = @import("screenshots.zig");

var expanded: bool = false;

test "chat cards" {
    const Local = struct {
        fn frame() !dvui.App.Result {
            var bg = shots.background(@src());
            defer bg.deinit();
            var col = ds.column(@src()).padding(ds.tokens.current.space_md).gap(ds.tokens.current.space_sm).expand(.horizontal).draw();
            defer col.deinit();
            ds.chat.toolCard(@src(), "set_component", "Ball / MeshRenderer.color", .ok).expanded(&expanded).draw();
            _ = ds.chat.approvalCard(@src(), "Run zig build check?", "Verifies the script compiles.").draw();
            _ = ds.chat.errorCard(@src(), "attempt to index a nil value", "scripts/ball.lua:12").draw();
            _ = ds.chat.checkpoint(@src(), "turn 7 / 2 files").draw();
            return .ok;
        }
    };
    try shots.capture("chat_cards.png", 420, 320, Local.frame);
}
