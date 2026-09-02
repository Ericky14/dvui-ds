/// Tests for the tool card builder and its status resolver.
const std = @import("std");
const widget = @import("tool_card.zig");
const tokens = @import("../../tokens.zig");

test "toolCard: builder defaults" {
    const card = widget.toolCard(@src(), "Read", "src/main.zig", .ok);
    try std.testing.expectEqualStrings("Read", card.name);
    try std.testing.expectEqualStrings("src/main.zig", card.summary);
    try std.testing.expectEqual(widget.ToolStatus.ok, card.status);
    try std.testing.expectEqualStrings("", card.details_text);
    try std.testing.expect(card.expanded_state == null);
    try std.testing.expectEqual(@as(usize, 0), card.id_extra);
}

test "toolCard: setters copy instead of mutating" {
    var open = true;
    const base = widget.toolCard(@src(), "Bash", "zig build", .running);
    const with_details = base.details("stdout").expanded(&open).idExtra(4);
    try std.testing.expectEqualStrings("", base.details_text);
    try std.testing.expect(base.expanded_state == null);
    try std.testing.expectEqual(@as(usize, 0), base.id_extra);
    try std.testing.expectEqualStrings("stdout", with_details.details_text);
    try std.testing.expect(with_details.expanded_state.? == &open);
    try std.testing.expectEqual(@as(usize, 4), with_details.id_extra);
}

test "toolCard: toggleable only with details and caller-owned state" {
    var open = false;
    try std.testing.expect(!widget.toolCard(@src(), "Bash", "", .ok).isToggleable());
    try std.testing.expect(!widget.toolCard(@src(), "Bash", "", .ok).details("x").isToggleable());
    try std.testing.expect(!widget.toolCard(@src(), "Bash", "", .ok).expanded(&open).isToggleable());
    try std.testing.expect(widget.toolCard(@src(), "Bash", "", .ok).details("x").expanded(&open).isToggleable());
}

test "toolCard: expanded needs both the flag and details" {
    var open = true;
    try std.testing.expect(!widget.toolCard(@src(), "Bash", "", .ok).expanded(&open).isExpanded());
    try std.testing.expect(widget.toolCard(@src(), "Bash", "", .ok).details("x").expanded(&open).isExpanded());
    open = false;
    try std.testing.expect(!widget.toolCard(@src(), "Bash", "", .ok).details("x").expanded(&open).isExpanded());
}

test "toolCard: status colours map onto the theme where it has a token" {
    const theme = tokens.default_theme;
    try std.testing.expect(widget.statusColor(.failed, theme).eql(theme.destructive));
    try std.testing.expect(widget.statusColor(.denied, theme).eql(theme.text_muted));
    // Running and ok use the documented local palette; they must differ from each
    // other and from the theme's destructive so the four states stay distinct.
    const running = widget.statusColor(.running, theme);
    const ok = widget.statusColor(.ok, theme);
    try std.testing.expect(!running.eql(ok));
    try std.testing.expect(!running.eql(theme.destructive));
    try std.testing.expect(!ok.eql(theme.destructive));
}
