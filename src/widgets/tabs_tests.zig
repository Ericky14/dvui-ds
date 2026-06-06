const std = @import("std");
const tabs_mod = @import("tabs.zig");

const sample_labels = [_][]const u8{ "Design", "Code", "Preview" };

test "tabs defaults: bound target, labels, no id_extra" {
    var active: usize = 0;
    const tab_row = tabs_mod.tabs(@src(), &active, &sample_labels);
    try std.testing.expect(tab_row.active == &active);
    try std.testing.expect(tab_row.labels.ptr == (&sample_labels).ptr);
    try std.testing.expectEqual(@as(usize, 3), tab_row.labels.len);
    try std.testing.expect(tab_row.id_extra == null);
}

test "tabs idExtra copy-on-set" {
    var active: usize = 1;
    const base = tabs_mod.tabs(@src(), &active, &sample_labels);
    const keyed = base.idExtra(7);
    try std.testing.expect(base.id_extra == null); // original untouched
    try std.testing.expectEqual(@as(usize, 7), keyed.id_extra.?);
    // The active pointer and labels survive the copy.
    try std.testing.expect(keyed.active == &active);
    try std.testing.expectEqual(@as(usize, 3), keyed.labels.len);
}
