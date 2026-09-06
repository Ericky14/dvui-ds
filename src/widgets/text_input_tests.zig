/// Tests for textInput builder and inputOpts().
const std = @import("std");
const dvui = @import("dvui");
const ti = @import("text_input.zig");
const tokens = @import("../tokens.zig");

const TextInput = ti.TextInput;

// ─── Builder defaults ────────────────────────────────────────────────────────

test "textInput builder defaults" {
    var buf: [64]u8 = @splat(0);
    const t = ti.textInput(@src(), &buf);
    try std.testing.expectEqual(tokens.Size.md, t.input_size);
    try std.testing.expect(t.placeholder_text == null);
    try std.testing.expect(t.label_text == null);
    try std.testing.expect(t.helper_text == null);
    try std.testing.expect(!t.is_error);
    try std.testing.expect(!t.is_disabled);
    try std.testing.expect(!t.is_password);
    try std.testing.expect(t.input_expand == null);
}

// ─── Builder chaining ────────────────────────────────────────────────────────

test "textInput builder size" {
    var buf: [64]u8 = @splat(0);
    const t = ti.textInput(@src(), &buf).size(.lg);
    try std.testing.expectEqual(tokens.Size.lg, t.input_size);
}

test "textInput builder placeholder" {
    var buf: [64]u8 = @splat(0);
    const t = ti.textInput(@src(), &buf).placeholder("Enter name");
    try std.testing.expectEqualStrings("Enter name", t.placeholder_text.?);
}

test "textInput builder label" {
    var buf: [64]u8 = @splat(0);
    const t = ti.textInput(@src(), &buf).label("Username");
    try std.testing.expectEqualStrings("Username", t.label_text.?);
}

test "textInput builder helper" {
    var buf: [64]u8 = @splat(0);
    const t = ti.textInput(@src(), &buf).helper("Required field");
    try std.testing.expectEqualStrings("Required field", t.helper_text.?);
}

test "textInput builder err" {
    var buf: [64]u8 = @splat(0);
    const t = ti.textInput(@src(), &buf).err(true);
    try std.testing.expect(t.is_error);
}

test "textInput builder disabled" {
    var buf: [64]u8 = @splat(0);
    const t = ti.textInput(@src(), &buf).disabled(true);
    try std.testing.expect(t.is_disabled);
}

test "textInput builder password" {
    var buf: [64]u8 = @splat(0);
    const t = ti.textInput(@src(), &buf).password(true);
    try std.testing.expect(t.is_password);
}

test "textInput builder expand" {
    var buf: [64]u8 = @splat(0);
    const t = ti.textInput(@src(), &buf).expand(.both);
    try std.testing.expectEqual(dvui.Options.Expand.both, t.input_expand.?);
}

test "textInput builder full chaining" {
    var buf: [64]u8 = @splat(0);
    const t = ti.textInput(@src(), &buf)
        .size(.lg)
        .placeholder("Email")
        .label("Email Address")
        .helper("We won't spam you")
        .err(false)
        .disabled(false)
        .password(false)
        .expand(.horizontal);

    try std.testing.expectEqual(tokens.Size.lg, t.input_size);
    try std.testing.expectEqualStrings("Email", t.placeholder_text.?);
    try std.testing.expectEqualStrings("Email Address", t.label_text.?);
    try std.testing.expectEqualStrings("We won't spam you", t.helper_text.?);
    try std.testing.expect(!t.is_error);
    try std.testing.expect(!t.is_disabled);
    try std.testing.expect(!t.is_password);
    try std.testing.expectEqual(dvui.Options.Expand.horizontal, t.input_expand.?);
}

// ─── inputOpts tests ─────────────────────────────────────────────────────────

test "inputOpts keeps the CSS spec's horizontal padding" {
    var buf: [64]u8 = @splat(0);
    inline for (&[_]struct { tokens.Size, f32 }{ .{ .sm, 10 }, .{ .md, 12 }, .{ .lg, 14 } }) |row| {
        const t = ti.textInput(@src(), &buf).size(row[0]);
        const p = t.inputOpts(tokens.current.border_input).padding.?;
        try std.testing.expectApproxEqAbs(row[1], p.x, 0.001);
        try std.testing.expectApproxEqAbs(row[1], p.w, 0.001);
    }
}

// **The vertical padding is DERIVED, and the control comes out its spec height.**
//
// It used to be a table (6 / 8 / 11) computed at authoring time from
// "approximate line heights 12px->16, 13px->17, 14px->18" — an approximation of
// a number the FONT decides. dvui then caps a single-line entry at the box it
// measured in the THEME's font, so a face taller than the guess had its
// descenders cut off with nothing able to see it (`inputOpts`, 2026-09-06).
test "inputOpts derives the vertical padding so the control is exactly its spec height" {
    var buf: [64]u8 = @splat(0);
    inline for (&[_]struct { tokens.Size, f32, f32 }{
        .{ .sm, 28, 16 },
        .{ .md, 32, 17 },
        .{ .lg, 40, 18 },
    }) |row| {
        const t = ti.textInput(@src(), &buf).size(row[0]);
        const o = t.inputOpts(tokens.current.border_input);
        const p = o.padding.?;
        const border = o.border.?;
        const content = o.min_size_content.?.h;
        // Outside a frame the line box is the CSS table's own approximation.
        try std.testing.expect(content >= row[2] - 0.001);
        // …and border + padding + content is the spec height, to the pixel.
        try std.testing.expectApproxEqAbs(row[1], content + p.y + p.h + border.y + border.h, 0.001);
        try std.testing.expectApproxEqAbs(p.y, p.h, 0.001);
    }
}

// **The height is PINNED, on both ends.** dvui sizes a single-line entry from
// `min_sizeM(defaultMWidth, 1)` in the theme's font and then sets
// `max_size_content = min_size_content`; stating both here is what takes that
// decision away from a font the caller never chose.
test "inputOpts pins the content height and leaves the width free to expand" {
    var buf: [64]u8 = @splat(0);
    const t = ti.textInput(@src(), &buf).size(.md);
    const o = t.inputOpts(tokens.current.border_input);
    try std.testing.expectApproxEqAbs(o.min_size_content.?.h, o.max_size_content.?.h, 0.001);
    try std.testing.expect(o.max_size_content.?.w > 1000);
}

test "inputOpts has 1px border" {
    var buf: [64]u8 = @splat(0);
    const t = ti.textInput(@src(), &buf);
    const o = t.inputOpts(tokens.current.border_input);
    const border = o.border.?;
    try std.testing.expectApproxEqAbs(@as(f32, 1), border.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1), border.y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1), border.w, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1), border.h, 0.001);
}

test "inputOpts has no margin" {
    var buf: [64]u8 = @splat(0);
    const t = ti.textInput(@src(), &buf);
    const o = t.inputOpts(tokens.current.border_input);
    try std.testing.expectEqual(@as(?dvui.Rect, null), o.margin);
}

test "inputOpts all sizes have 8px radius" {
    var buf: [64]u8 = @splat(0);
    inline for (&[_]tokens.Size{ .sm, .md, .lg }) |s| {
        const t = ti.textInput(@src(), &buf).size(s);
        const o = t.inputOpts(tokens.current.border_input);
        const r = o.corners.?;
        try std.testing.expectEqual(dvui.Corner.Style.round, r.tl.kind);
        try std.testing.expectApproxEqAbs(tokens.current.radius_md, r.tl.rx, 0.001);
        try std.testing.expectApproxEqAbs(tokens.current.radius_md, r.br.rx, 0.001);
    }
}

test "inputOpts uses transparent fill" {
    var buf: [64]u8 = @splat(0);
    const t = ti.textInput(@src(), &buf);
    const o = t.inputOpts(tokens.current.border_input);
    try std.testing.expectEqual(dvui.Color.transparent, o.color_fill.?.toColor());
}

test "inputOpts uses text_primary for text color" {
    var buf: [64]u8 = @splat(0);
    const t = ti.textInput(@src(), &buf);
    const o = t.inputOpts(tokens.current.border_input);
    try std.testing.expectEqual(tokens.current.text_primary, o.color_text.?.toColor());
}

test "inputOpts passes border color through" {
    var buf: [64]u8 = @splat(0);
    const t = ti.textInput(@src(), &buf);
    const o = t.inputOpts(tokens.current.destructive);
    try std.testing.expectEqual(tokens.current.destructive, o.color_border.?.toColor());
}

test "inputOpts defaults to horizontal expand" {
    var buf: [64]u8 = @splat(0);
    const t = ti.textInput(@src(), &buf);
    const o = t.inputOpts(tokens.current.border_input);
    try std.testing.expectEqual(dvui.Options.Expand.horizontal, o.expand.?);
}

test "inputOpts respects expand override" {
    var buf: [64]u8 = @splat(0);
    const t = ti.textInput(@src(), &buf).expand(.both);
    const o = t.inputOpts(tokens.current.border_input);
    try std.testing.expectEqual(dvui.Options.Expand.both, o.expand.?);
}

test "inputOpts has no explicit background" {
    var buf: [64]u8 = @splat(0);
    const t = ti.textInput(@src(), &buf);
    const o = t.inputOpts(tokens.current.border_input);
    try std.testing.expectEqual(@as(?bool, null), o.background);
}

test "inputOpts sm font size is 12px" {
    var buf: [64]u8 = @splat(0);
    const t = ti.textInput(@src(), &buf).size(.sm);
    const o = t.inputOpts(tokens.current.border_input);
    try std.testing.expectEqual(@as(u16, 12), o.font.?.size);
}

test "inputOpts md font size is 13px" {
    var buf: [64]u8 = @splat(0);
    const t = ti.textInput(@src(), &buf).size(.md);
    const o = t.inputOpts(tokens.current.border_input);
    try std.testing.expectEqual(@as(u16, 13), o.font.?.size);
}

test "inputOpts lg font size is 14px" {
    var buf: [64]u8 = @splat(0);
    const t = ti.textInput(@src(), &buf).size(.lg);
    const o = t.inputOpts(tokens.current.border_input);
    try std.testing.expectEqual(@as(u16, 14), o.font.?.size);
}

// ─── textInputAdvanced constructor ───────────────────────────────────────────

test "textInputAdvanced creates from TextOption" {
    var buf: [64]u8 = @splat(0);
    const t = ti.textInputAdvanced(@src(), .{ .buffer = &buf });
    try std.testing.expectEqual(tokens.Size.md, t.input_size);
}
