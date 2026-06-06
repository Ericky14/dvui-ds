/// Tests for the iconButton builder.
const std = @import("std");
const ib = @import("icon_button.zig");
const tokens = @import("../tokens.zig");
const icons = @import("../icons.zig");

test "iconButton builder defaults" {
    const b = ib.iconButton(@src(), "cog", icons.cog);
    try std.testing.expectEqual(tokens.Variant.ghost, b.btn_variant);
    try std.testing.expectEqual(tokens.Size.sm, b.btn_size);
    try std.testing.expect(!b.is_disabled);
    try std.testing.expect(!b.is_loading);
    try std.testing.expect(std.meta.activeTag(b.icon_source.kind) == .named_icon);
}

test "iconButton builder variant + size" {
    const b = ib.iconButton(@src(), "delete", icons.delete).variant(.danger).size(.lg);
    try std.testing.expectEqual(tokens.Variant.danger, b.btn_variant);
    try std.testing.expectEqual(tokens.Size.lg, b.btn_size);
}

test "iconButton builder disabled + loading" {
    const b = ib.iconButton(@src(), "copy", icons.copy).disabled(true).loading(true);
    try std.testing.expect(b.is_disabled);
    try std.testing.expect(b.is_loading);
}

test "iconButton from arbitrary source" {
    const b = ib.iconButtonSource(@src(), ib.Source.tvg("x", &[_]u8{}));
    try std.testing.expect(std.meta.activeTag(b.icon_source.kind) == .tvg);
}
