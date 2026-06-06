const std = @import("std");
const dvui = @import("dvui");
const slider_mod = @import("slider.zig");
const tokens = @import("../tokens.zig");

test "slider defaults: md, enabled, no expand, no id_extra" {
    var fraction: f32 = 0.4;
    const sl = slider_mod.slider(@src(), &fraction);
    try std.testing.expectEqual(tokens.Size.md, sl.slider_size);
    try std.testing.expect(!sl.is_disabled);
    try std.testing.expectEqual(dvui.Options.Expand.none, sl.expand_val);
    try std.testing.expect(sl.id_extra == null);
    try std.testing.expect(sl.fraction == &fraction);
}

test "slider setters copy-on-set" {
    var fraction: f32 = 0.4;
    const base = slider_mod.slider(@src(), &fraction);
    const styled = base.size(.lg).disabled(true).expand(.horizontal).idExtra(7);

    // original untouched
    try std.testing.expectEqual(tokens.Size.md, base.slider_size);
    try std.testing.expect(!base.is_disabled);
    try std.testing.expectEqual(dvui.Options.Expand.none, base.expand_val);
    try std.testing.expect(base.id_extra == null);

    // copy carries the mutations
    try std.testing.expectEqual(tokens.Size.lg, styled.slider_size);
    try std.testing.expect(styled.is_disabled);
    try std.testing.expectEqual(dvui.Options.Expand.horizontal, styled.expand_val);
    try std.testing.expectEqual(@as(?usize, 7), styled.id_extra);
}
