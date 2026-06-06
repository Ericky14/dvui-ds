const std = @import("std");
const dropdown_mod = @import("dropdown.zig");
const tokens = @import("../tokens.zig");

const entries = [_][]const u8{ "Apple", "Banana", "Cherry" };

test "dropdown defaults: md, default placeholder, enabled, no id_extra" {
    var selected: usize = 0;
    const dd = dropdown_mod.dropdown(@src(), &selected, &entries);
    try std.testing.expectEqual(tokens.Size.md, dd.dropdown_size);
    try std.testing.expectEqualStrings("Select ...", dd.placeholder_text);
    try std.testing.expect(!dd.is_disabled);
    try std.testing.expect(dd.id_extra == null);
    try std.testing.expect(dd.selected == &selected);
    try std.testing.expectEqual(@as(usize, 3), dd.entries.len);
}

test "dropdown setters copy-on-set" {
    var selected: usize = 0;
    const base = dropdown_mod.dropdown(@src(), &selected, &entries);
    const styled = base.size(.lg).placeholder("Choose a fruit").disabled(true).idExtra(7);

    // original untouched
    try std.testing.expectEqual(tokens.Size.md, base.dropdown_size);
    try std.testing.expectEqualStrings("Select ...", base.placeholder_text);
    try std.testing.expect(!base.is_disabled);
    try std.testing.expect(base.id_extra == null);

    // copy mutated
    try std.testing.expectEqual(tokens.Size.lg, styled.dropdown_size);
    try std.testing.expectEqualStrings("Choose a fruit", styled.placeholder_text);
    try std.testing.expect(styled.is_disabled);
    try std.testing.expectEqual(@as(usize, 7), styled.id_extra.?);
}
