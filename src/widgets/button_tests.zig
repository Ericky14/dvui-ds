/// Tests for button builder, opts(), and utility functions.
const std = @import("std");
const dvui = @import("dvui");
const btn = @import("button.zig");
const tokens = @import("../tokens.zig");

const Color = dvui.Color;
const Button = btn.Button;

// ─── Builder tests ───────────────────────────────────────────────────────────

test "button builder defaults" {
    const b = btn.button(@src(), "Click me");
    try std.testing.expectEqual(tokens.Variant.ghost, b.btn_variant);
    try std.testing.expectEqual(tokens.Size.sm, b.btn_size);
    try std.testing.expect(b.btn_source == null);
    try std.testing.expect(!b.icon_first_flag);
    try std.testing.expect(!b.is_disabled);
    try std.testing.expect(!b.is_loading);
    try std.testing.expect(b.override_text_color == null);
    try std.testing.expect(b.override_fill_color == null);
    try std.testing.expect(b.override_fill_hover == null);
    try std.testing.expect(b.override_fill_press == null);
    try std.testing.expect(b.override_gravity_x == null);
    try std.testing.expect(b.override_expand == null);
    try std.testing.expect(b.override_padding == null);
}

test "button builder variant" {
    const b = btn.button(@src(), "Save").variant(.filled);
    try std.testing.expectEqual(tokens.Variant.filled, b.btn_variant);
}

test "button builder size" {
    const b = btn.button(@src(), "Save").size(.lg);
    try std.testing.expectEqual(tokens.Size.lg, b.btn_size);
}

test "button builder disabled" {
    const b = btn.button(@src(), "Save").disabled(true);
    try std.testing.expect(b.is_disabled);
}

test "button builder loading" {
    const b = btn.button(@src(), "Save").loading(true);
    try std.testing.expect(b.is_loading);
}

test "button builder textColor override" {
    const c = Color{ .r = 255, .g = 0, .b = 0, .a = 255 };
    const b = btn.button(@src(), "Go").textColor(c);
    try std.testing.expectEqual(c, b.override_text_color.?);
}

test "button builder fillColor override" {
    const c = Color{ .r = 0, .g = 255, .b = 0, .a = 128 };
    const b = btn.button(@src(), "Go").fillColor(c);
    try std.testing.expectEqual(c, b.override_fill_color.?);
}

test "button builder fillHover override" {
    const c = Color{ .r = 10, .g = 20, .b = 30, .a = 40 };
    const b = btn.button(@src(), "Go").fillHover(c);
    try std.testing.expectEqual(c, b.override_fill_hover.?);
}

test "button builder fillPress override" {
    const c = Color{ .r = 50, .g = 60, .b = 70, .a = 80 };
    const b = btn.button(@src(), "Go").fillPress(c);
    try std.testing.expectEqual(c, b.override_fill_press.?);
}

test "button builder gravityX" {
    const b = btn.button(@src(), "Go").gravityX(0.0);
    try std.testing.expectApproxEqAbs(0.0, b.override_gravity_x.?, 0.001);
}

test "button builder expand" {
    const b = btn.button(@src(), "Go").expand(.horizontal);
    try std.testing.expectEqual(dvui.Options.Expand.horizontal, b.override_expand.?);
}

test "button builder padding" {
    const p = dvui.Rect{ .x = 8, .y = 6, .w = 8, .h = 6 };
    const b = btn.button(@src(), "Go").padding(p);
    const bp = b.override_padding.?;
    try std.testing.expectApproxEqAbs(@as(f32, 8), bp.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 6), bp.y, 0.001);
}

test "button builder chaining" {
    const c = Color{ .r = 100, .g = 200, .b = 50, .a = 255 };
    const b = btn.button(@src(), "Nav")
        .variant(.ghost)
        .size(.sm)
        .textColor(c)
        .fillColor(Color.transparent)
        .gravityX(0)
        .expand(.horizontal)
        .padding(.{ .x = 8, .y = 6, .w = 8, .h = 6 });

    try std.testing.expectEqual(tokens.Variant.ghost, b.btn_variant);
    try std.testing.expectEqual(tokens.Size.sm, b.btn_size);
    try std.testing.expectEqual(c, b.override_text_color.?);
    try std.testing.expectEqual(Color.transparent, b.override_fill_color.?);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), b.override_gravity_x.?, 0.001);
    try std.testing.expectEqual(dvui.Options.Expand.horizontal, b.override_expand.?);
}

// ─── opts() tests ────────────────────────────────────────────────────────────

test "opts ghost sm has transparent fill" {
    const o = btn.opts(.ghost, .sm);
    try std.testing.expectEqual(Color.transparent, o.color_fill.?.toColor());
}

test "opts ghost sm has zero border" {
    const o = btn.opts(.ghost, .sm);
    const border = o.border.?;
    try std.testing.expectApproxEqAbs(@as(f32, 0), border.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0), border.y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0), border.w, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0), border.h, 0.001);
}

test "opts ghost sm has zero margin" {
    const o = btn.opts(.ghost, .sm);
    const margin = o.margin.?;
    try std.testing.expectApproxEqAbs(@as(f32, 0), margin.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0), margin.y, 0.001);
}

test "opts outlined has 1px border" {
    const o = btn.opts(.outlined, .md);
    const border = o.border.?;
    try std.testing.expectApproxEqAbs(@as(f32, 1), border.x, 0.001);
}

test "opts filled sm has accent-based fill" {
    const o = btn.opts(.filled, .sm);
    const fill = o.color_fill.?;
    // Alpha should be 30 (accent at ~12% opacity)
    try std.testing.expectEqual(@as(u8, 30), fill.toColor().a);
}

test "opts sm padding uses space_md x space_xs" {
    const o = btn.opts(.ghost, .sm);
    const p = o.padding.?;
    try std.testing.expectApproxEqAbs(@as(f32, 12), p.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 6), p.y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 12), p.w, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 6), p.h, 0.001);
}

test "opts md padding uses space_lg x space_sm" {
    const o = btn.opts(.ghost, .md);
    const p = o.padding.?;
    try std.testing.expectApproxEqAbs(@as(f32, 16), p.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 8), p.y, 0.001);
}

test "opts lg padding uses space_xl x space_md" {
    const o = btn.opts(.ghost, .lg);
    const p = o.padding.?;
    try std.testing.expectApproxEqAbs(@as(f32, 20), p.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 12), p.y, 0.001);
}

test "opts has no gravity_y set" {
    const o = btn.opts(.ghost, .sm);
    try std.testing.expect(o.gravity_y == null);
}
