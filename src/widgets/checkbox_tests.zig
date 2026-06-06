const std = @import("std");
const checkbox_mod = @import("checkbox.zig");
const tokens = @import("../tokens.zig");

test "checkbox defaults: md, no label, enabled" {
    var value = false;
    const c = checkbox_mod.checkbox(@src(), &value);
    try std.testing.expectEqual(tokens.Size.md, c.cb_size);
    try std.testing.expect(c.label_text == null);
    try std.testing.expect(!c.is_disabled);
    try std.testing.expect(c.target == &value);
}

test "checkbox setters copy-on-set" {
    var value = false;
    const base = checkbox_mod.checkbox(@src(), &value);
    const styled = base.size(.lg).label("Accept").disabled(true);
    try std.testing.expectEqual(tokens.Size.md, base.cb_size); // original untouched
    try std.testing.expectEqual(tokens.Size.lg, styled.cb_size);
    try std.testing.expectEqualStrings("Accept", styled.label_text.?);
    try std.testing.expect(styled.is_disabled);
}
