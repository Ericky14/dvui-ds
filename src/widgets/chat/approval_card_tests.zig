/// Tests for the approval card builder and its command / path heuristic.
const std = @import("std");
const widget = @import("approval_card.zig");
const ds = @import("../../ds.zig");

test "approvalCard: builder defaults" {
    const card = widget.approvalCard(@src(), "Run it?", "zig build");
    try std.testing.expectEqualStrings("Run it?", card.title);
    try std.testing.expectEqualStrings("zig build", card.detail);
    try std.testing.expect(card.note_buffer == null);
    try std.testing.expectEqual(@as(usize, 0), card.id_extra);
}

test "approvalCard: setters copy instead of mutating" {
    var buffer: [16]u8 = @splat(0);
    const base = widget.approvalCard(@src(), "Run it?", "zig build");
    const with_note = base.note(&buffer).idExtra(3);
    try std.testing.expect(base.note_buffer == null);
    try std.testing.expectEqual(@as(usize, 0), base.id_extra);
    try std.testing.expect(with_note.note_buffer.?.ptr == &buffer);
    try std.testing.expectEqual(@as(usize, 3), with_note.id_extra);
}

test "approvalCard: commands and paths render mono" {
    try std.testing.expect(widget.looksLikeCommandOrPath("zig build check"));
    try std.testing.expect(widget.looksLikeCommandOrPath("rm -rf build/"));
    try std.testing.expect(widget.looksLikeCommandOrPath("src/main.zig"));
    try std.testing.expect(widget.looksLikeCommandOrPath("C:\\Users\\erick\\project"));
    try std.testing.expect(widget.looksLikeCommandOrPath("git commit -m \"msg\" --no-verify please"));
    try std.testing.expect(widget.looksLikeCommandOrPath("  npm install  "));
}

test "approvalCard: prose stays proportional" {
    try std.testing.expect(!widget.looksLikeCommandOrPath(""));
    try std.testing.expect(!widget.looksLikeCommandOrPath("Verifies the script compiles."));
    try std.testing.expect(!widget.looksLikeCommandOrPath("The agent wants to verify the script compiles"));
    try std.testing.expect(!widget.looksLikeCommandOrPath("make it bounce higher next time around"));
    try std.testing.expect(!widget.looksLikeCommandOrPath("zig"));
    try std.testing.expect(!widget.looksLikeCommandOrPath("Really run this?"));
}

test "Deny reads on the card even though it has no fill of its own" {
    const theme = ds.tokens.current;
    // Deny is the `.danger` variant with its fill overridden to transparent, so
    // its ink lands on the approval card's blue-tinted panel rather than on a
    // danger tint. Both pairings have to hold, and the base red does not: it is
    // 4.18:1 on the card. That is why `on_danger_mix` exists and why it is
    // tuned against this pairing as well as against the tint.
    const ink = theme.onDangerSoft();
    const card_fill = ds.mix(theme.accentSoft(), theme.surface_1, 0.55);
    try std.testing.expect(ds.contrastRatio(ink, card_fill) >= 4.5);
    try std.testing.expect(ds.contrastRatio(ink, theme.dangerSoft()) >= 4.5);
    try std.testing.expect(ds.contrastRatio(theme.destructive, card_fill) < 4.5);
}
