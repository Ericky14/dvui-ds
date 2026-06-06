const std = @import("std");
const state_layer = @import("state_layer.zig");
const tokens = @import("../tokens.zig");

test "InteractionState defaults to all-false" {
    const s: state_layer.InteractionState = .{};
    try std.testing.expect(!s.hovered);
    try std.testing.expect(!s.pressed);
    try std.testing.expect(!s.focused);
}

test "state-layer opacity tokens are ordered hover < focus < press" {
    const t = tokens.default_theme;
    try std.testing.expect(t.state_hover < t.state_focus);
    try std.testing.expect(t.state_focus < t.state_press);
}
