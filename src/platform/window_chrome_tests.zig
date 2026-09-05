const std = @import("std");
const dvui = @import("dvui");
const chrome = @import("window_chrome.zig");

/// A 900x600 window with a 36px title bar and three 28px caption buttons on the
/// right, the shape the editor actually has.
fn editorLike() chrome.State {
    var state: chrome.State = .{
        .active = true,
        .resizable = true,
        .resize_margin = 6,
        .width = 900,
        .height = 600,
        .drag = .{ .x = 0, .y = 0, .w = 900, .h = 36 },
        .button_count = 3,
    };
    state.buttons[0] = .{ .x = 810, .y = 4, .w = 28, .h = 28 };
    state.buttons[1] = .{ .x = 838, .y = 4, .w = 28, .h = 28 };
    state.buttons[2] = .{ .x = 866, .y = 4, .w = 28, .h = 28 };
    return state;
}

test "the title bar drags and the content below it does not" {
    const state = editorLike();
    try std.testing.expectEqual(chrome.Hit.drag, chrome.classify(400, 20, state));
    try std.testing.expectEqual(chrome.Hit.normal, chrome.classify(400, 300, state));
    // Just below the title bar is content, not chrome.
    try std.testing.expectEqual(chrome.Hit.normal, chrome.classify(400, 36, state));
}

test "a caption button is a hole in the drag region" {
    const state = editorLike();
    // Dead centre of the close button: the click must reach the widget.
    try std.testing.expectEqual(chrome.Hit.normal, chrome.classify(880, 18, state));
    // One pixel to the left of the first button is still title bar.
    try std.testing.expectEqual(chrome.Hit.drag, chrome.classify(809, 18, state));
    // And the seam between two buttons belongs to the second, not to the drag.
    try std.testing.expectEqual(chrome.Hit.normal, chrome.classify(838, 18, state));
}

test "resize borders beat the title bar, including at the corners" {
    const state = editorLike();
    // The top edge crosses the title bar; resize has to win or the window can
    // be dragged but never resized from the top.
    try std.testing.expectEqual(chrome.Hit.resize_top, chrome.classify(400, 2, state));
    try std.testing.expectEqual(chrome.Hit.resize_top_left, chrome.classify(2, 2, state));
    try std.testing.expectEqual(chrome.Hit.resize_top_right, chrome.classify(898, 2, state));
    try std.testing.expectEqual(chrome.Hit.resize_bottom_left, chrome.classify(2, 598, state));
    try std.testing.expectEqual(chrome.Hit.resize_bottom_right, chrome.classify(898, 598, state));
    try std.testing.expectEqual(chrome.Hit.resize_left, chrome.classify(2, 300, state));
    try std.testing.expectEqual(chrome.Hit.resize_right, chrome.classify(898, 300, state));
    try std.testing.expectEqual(chrome.Hit.resize_bottom, chrome.classify(400, 598, state));
    // …and a corner beats an edge, even over a caption button.
    try std.testing.expectEqual(chrome.Hit.resize_top_right, chrome.classify(897, 3, state));
}

test "the resize border ends exactly at the margin" {
    const state = editorLike();
    try std.testing.expectEqual(chrome.Hit.resize_left, chrome.classify(5.9, 300, state));
    try std.testing.expectEqual(chrome.Hit.normal, chrome.classify(6, 300, state));
    try std.testing.expectEqual(chrome.Hit.normal, chrome.classify(893, 300, state));
    try std.testing.expectEqual(chrome.Hit.resize_right, chrome.classify(894, 300, state));
}

test "a window that is not resizable has no resize borders" {
    var state = editorLike();
    state.resizable = false;
    try std.testing.expectEqual(chrome.Hit.drag, chrome.classify(2, 2, state));
    try std.testing.expectEqual(chrome.Hit.normal, chrome.classify(2, 300, state));
}

test "an undeclared frame leaves the window normal but still resizable" {
    var state = editorLike();
    state.drag = null;
    state.button_count = 0;
    try std.testing.expectEqual(chrome.Hit.normal, chrome.classify(400, 20, state));
    // The resize borders survive: a window is never stuck at one size because a
    // frame forgot to declare its title bar.
    try std.testing.expectEqual(chrome.Hit.resize_top, chrome.classify(400, 2, state));
}

test "a zero-sized window classifies everything as normal instead of dividing by it" {
    var state = editorLike();
    state.width = 0;
    state.height = 0;
    state.drag = null;
    try std.testing.expectEqual(chrome.Hit.normal, chrome.classify(0, 0, state));
}
