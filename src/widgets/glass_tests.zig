const std = @import("std");
const dvui = @import("dvui");
const glass_mod = @import("glass.zig");
const tokens = @import("../tokens.zig");

test "glass defaults: inline, no blur bracket, vertical" {
    const surface = glass_mod.glass(@src());
    try std.testing.expect(surface.panel_rect == null);
    try std.testing.expect(surface.backdrop == null);
    try std.testing.expectEqual(@as(u64, 0), surface.witness_val);
    try std.testing.expectEqual(dvui.enums.Direction.vertical, surface.dir);
    try std.testing.expect(!surface.is_solid);
}

test "glass setters copy-on-set" {
    const base = glass_mod.glass(@src());
    const styled = base
        .rect(.{ .x = 10, .y = 20, .w = 300, .h = 200 })
        .witness(42)
        .blur(12)
        .radius(18)
        .solid(true)
        .horizontal()
        .gap(8)
        .padding(20)
        .expand(.horizontal)
        .tag("drawer")
        .idExtra(3);

    // The original is untouched — value semantics.
    try std.testing.expect(base.panel_rect == null);
    try std.testing.expectEqual(@as(u64, 0), base.witness_val);
    try std.testing.expect(base.blur_val == null);

    try std.testing.expectEqual(@as(f32, 300), styled.panel_rect.?.w);
    try std.testing.expectEqual(@as(u64, 42), styled.witness_val);
    try std.testing.expectEqual(@as(f32, 12), styled.blur_val.?);
    try std.testing.expectEqual(@as(f32, 18), styled.radius_val.?);
    try std.testing.expect(styled.is_solid);
    try std.testing.expectEqual(dvui.enums.Direction.horizontal, styled.dir);
    try std.testing.expectEqual(@as(f32, 8), styled.gap_val);
    try std.testing.expect(styled.pad_override != null);
    try std.testing.expectEqual(dvui.Options.Expand.horizontal, styled.expand_override.?);
    try std.testing.expectEqualStrings("drawer", styled.tag_val.?);
    try std.testing.expectEqual(@as(usize, 3), styled.id_extra);
}

test "the glass tint falls back to surface_1 when the theme names none" {
    const theme = tokens.default_theme;
    try std.testing.expect(theme.glass_tint == null);
    const tint = theme.glass_tint orelse theme.surface_1;
    try std.testing.expectEqual(theme.surface_1.r, tint.r);
    try std.testing.expectEqual(theme.surface_1.g, tint.g);
    try std.testing.expectEqual(theme.surface_1.b, tint.b);
}

test "the opaque fallback is markedly less transparent than live glass" {
    const theme = tokens.default_theme;
    // Otherwise the no-blur fallback would show raw, *unblurred* scene content
    // through a translucent panel and the text on it would be unreadable.
    try std.testing.expect(theme.glass_alpha_opaque > theme.glass_alpha);
    try std.testing.expect(theme.glass_alpha_opaque - theme.glass_alpha >= 32);
}
