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

test "inputOpts sm padding is 10px x 6px" {
    var buf: [64]u8 = @splat(0);
    const t = ti.textInput(@src(), &buf).size(.sm);
    const o = t.inputOpts(tokens.current.border_input);
    const p = o.padding.?;
    try std.testing.expectApproxEqAbs(@as(f32, 10), p.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 6), p.y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 10), p.w, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 6), p.h, 0.001);
}

test "inputOpts md padding is 12px x 8px" {
    var buf: [64]u8 = @splat(0);
    const t = ti.textInput(@src(), &buf).size(.md);
    const o = t.inputOpts(tokens.current.border_input);
    const p = o.padding.?;
    try std.testing.expectApproxEqAbs(@as(f32, 12), p.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 8), p.y, 0.001);
}

test "inputOpts lg padding is 14px x 11px" {
    var buf: [64]u8 = @splat(0);
    const t = ti.textInput(@src(), &buf).size(.lg);
    const o = t.inputOpts(tokens.current.border_input);
    const p = o.padding.?;
    try std.testing.expectApproxEqAbs(@as(f32, 14), p.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 11), p.y, 0.001);
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
        const r = o.corner_radius.?;
        try std.testing.expectApproxEqAbs(tokens.current.radius_md, r.x, 0.001);
    }
}

test "inputOpts uses transparent fill" {
    var buf: [64]u8 = @splat(0);
    const t = ti.textInput(@src(), &buf);
    const o = t.inputOpts(tokens.current.border_input);
    try std.testing.expectEqual(dvui.Color.transparent, o.color_fill.?);
}

test "inputOpts uses text_primary for text color" {
    var buf: [64]u8 = @splat(0);
    const t = ti.textInput(@src(), &buf);
    const o = t.inputOpts(tokens.current.border_input);
    try std.testing.expectEqual(tokens.current.text_primary, o.color_text.?);
}

test "inputOpts passes border color through" {
    var buf: [64]u8 = @splat(0);
    const t = ti.textInput(@src(), &buf);
    const o = t.inputOpts(tokens.current.destructive);
    try std.testing.expectEqual(tokens.current.destructive, o.color_border.?);
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
