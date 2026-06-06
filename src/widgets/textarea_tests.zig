/// Tests for the textarea builder.
const std = @import("std");
const ta = @import("textarea.zig");

test "textarea builder defaults" {
    var buf: [16]u8 = undefined;
    const t = ta.textarea(@src(), &buf);
    try std.testing.expectApproxEqAbs(@as(f32, 4), t.visible_rows, 0.001);
    try std.testing.expect(t.placeholder_text == null);
    try std.testing.expect(t.label_text == null);
    try std.testing.expect(t.helper_text == null);
    try std.testing.expect(!t.is_error);
    try std.testing.expect(!t.is_disabled);
    try std.testing.expect(t.input_expand == null);
}

test "textarea builder rows" {
    var buf: [16]u8 = undefined;
    const t = ta.textarea(@src(), &buf).rows(8);
    try std.testing.expectApproxEqAbs(@as(f32, 8), t.visible_rows, 0.001);
}

test "textarea builder placeholder + label + helper" {
    var buf: [16]u8 = undefined;
    const t = ta.textarea(@src(), &buf)
        .placeholder("Notes…")
        .label("Bio")
        .helper("Tell us about yourself");
    try std.testing.expectEqualStrings("Notes…", t.placeholder_text.?);
    try std.testing.expectEqualStrings("Bio", t.label_text.?);
    try std.testing.expectEqualStrings("Tell us about yourself", t.helper_text.?);
}

test "textarea builder error + disabled + expand" {
    var buf: [16]u8 = undefined;
    const t = ta.textarea(@src(), &buf).err(true).disabled(true).expand(.both);
    try std.testing.expect(t.is_error);
    try std.testing.expect(t.is_disabled);
    try std.testing.expectEqual(@import("dvui").Options.Expand.both, t.input_expand.?);
}
