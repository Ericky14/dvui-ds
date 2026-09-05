const std = @import("std");
const drop = @import("drop.zig");

/// The whole conversation SDL has with a window when a person drags two files
/// onto it and lets go.
fn twoFiles(collector: *drop.Collector) void {
    collector.begin();
    collector.position(120, 80);
    collector.position(340, 210);
    collector.file("C:/Users/someone/Desktop/crate.glb");
    collector.file("C:/Users/someone/Desktop/tile.png");
    collector.complete();
}

test "a drop hands over its files and the point they landed on" {
    var collector: drop.Collector = .{};
    var slots: [drop.max_files][]const u8 = undefined;
    twoFiles(&collector);

    const state = collector.state(&slots);
    try std.testing.expect(state.completed);
    // The hover ends with the drop, but its last position is where the files
    // landed — a target that cleared it would have nothing to place them at.
    try std.testing.expect(!state.hovering);
    try std.testing.expectEqual(@as(f32, 340), state.x);
    try std.testing.expectEqual(@as(f32, 210), state.y);
    try std.testing.expectEqual(@as(usize, 2), state.files.len);
    try std.testing.expectEqualStrings("C:/Users/someone/Desktop/crate.glb", state.files[0]);
    try std.testing.expectEqualStrings("C:/Users/someone/Desktop/tile.png", state.files[1]);
    try std.testing.expectEqual(@as(usize, 0), state.overflow);
}

test "a hovering drag reports its pointer and no files" {
    var collector: drop.Collector = .{};
    var slots: [drop.max_files][]const u8 = undefined;
    collector.begin();
    collector.position(64, 32);

    const state = collector.state(&slots);
    try std.testing.expect(state.hovering);
    try std.testing.expect(!state.completed);
    try std.testing.expectEqual(@as(usize, 0), state.files.len);
    try std.testing.expectEqual(@as(f32, 64), state.x);
}

test "a position before the begin still lights the target up" {
    var collector: drop.Collector = .{};
    var slots: [drop.max_files][]const u8 = undefined;
    collector.position(10, 10);
    try std.testing.expect(collector.state(&slots).hovering);
}

test "the completed set survives exactly one frame" {
    var collector: drop.Collector = .{};
    var slots: [drop.max_files][]const u8 = undefined;
    twoFiles(&collector);
    try std.testing.expectEqual(@as(usize, 2), collector.state(&slots).files.len);

    // The frame after: the host has read it, so it is gone rather than being
    // imported a second time.
    collector.beginFrame();
    const after = collector.state(&slots);
    try std.testing.expect(!after.completed);
    try std.testing.expectEqual(@as(usize, 0), after.files.len);
}

test "a hover that has not completed survives the frame boundary" {
    var collector: drop.Collector = .{};
    var slots: [drop.max_files][]const u8 = undefined;
    collector.begin();
    collector.position(200, 100);
    collector.beginFrame();
    const state = collector.state(&slots);
    try std.testing.expect(state.hovering);
    try std.testing.expectEqual(@as(f32, 200), state.x);
}

test "a second drop replaces the first rather than appending to it" {
    var collector: drop.Collector = .{};
    var slots: [drop.max_files][]const u8 = undefined;
    twoFiles(&collector);
    collector.beginFrame();
    collector.begin();
    collector.file("/home/someone/coin.wav");
    collector.complete();

    const state = collector.state(&slots);
    try std.testing.expectEqual(@as(usize, 1), state.files.len);
    try std.testing.expectEqualStrings("/home/someone/coin.wav", state.files[0]);
}

test "an empty path is not a file" {
    var collector: drop.Collector = .{};
    var slots: [drop.max_files][]const u8 = undefined;
    collector.begin();
    collector.file("");
    collector.complete();
    try std.testing.expectEqual(@as(usize, 0), collector.state(&slots).files.len);
}

test "more files than fit are counted, not truncated" {
    var collector: drop.Collector = .{};
    var slots: [drop.max_files][]const u8 = undefined;
    collector.begin();
    for (0..drop.max_files + 3) |index| {
        var buffer: [32]u8 = undefined;
        collector.file(std.fmt.bufPrint(&buffer, "/tmp/file{d}.png", .{index}) catch unreachable);
    }
    collector.complete();

    const state = collector.state(&slots);
    try std.testing.expectEqual(drop.max_files, state.files.len);
    try std.testing.expectEqual(@as(usize, 3), state.overflow);
    // Every path that DID fit is whole: a truncated path names another file.
    try std.testing.expectEqualStrings("/tmp/file0.png", state.files[0]);
    try std.testing.expectEqualStrings("/tmp/file31.png", state.files[drop.max_files - 1]);
}

test "a drag that leaves without dropping clears itself" {
    var collector: drop.Collector = .{};
    var slots: [drop.max_files][]const u8 = undefined;
    collector.begin();
    collector.position(50, 50);
    collector.file("/tmp/never.png");
    collector.cancel();

    const state = collector.state(&slots);
    try std.testing.expect(!state.hovering);
    try std.testing.expect(!state.completed);
    try std.testing.expectEqual(@as(usize, 0), state.files.len);
}
