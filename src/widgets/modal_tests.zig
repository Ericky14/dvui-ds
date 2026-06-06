const std = @import("std");
const modal_mod = @import("modal.zig");

test "modal defaults: no title, default width, bound open flag" {
    var open = false;
    const dialog = modal_mod.modal(@src(), &open);
    try std.testing.expect(dialog.title_text == null);
    try std.testing.expectEqual(@as(f32, 360), dialog.width_val);
    try std.testing.expect(dialog.open == &open);
}

test "modal setters copy-on-set" {
    var open = false;
    const base = modal_mod.modal(@src(), &open);
    const styled = base.title("Confirm").width(420);

    // original untouched
    try std.testing.expect(base.title_text == null);
    try std.testing.expectEqual(@as(f32, 360), base.width_val);

    // copy carries the mutations
    try std.testing.expectEqualStrings("Confirm", styled.title_text.?);
    try std.testing.expectEqual(@as(f32, 420), styled.width_val);
    try std.testing.expect(styled.open == &open);
}
