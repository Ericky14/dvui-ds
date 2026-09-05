//! Composer — the chat input at the bottom of the chat pane.
//!
//! Shared, not copied: `test/chat_screenshots.zig` imports this same file as the
//! `composer_demo` module and renders `states()` at 1.0 and 1.75, so the page the
//! storybook runs and the screenshots the review looks at cannot drift apart.
const std = @import("std");
const dvui = @import("dvui");
const ds = @import("dvui_ds");

var empty_buffer: [256]u8 = @splat(0);
var one_line_buffer: [256]u8 = @splat(0);
var three_line_buffer: [256]u8 = @splat(0);
var busy_buffer: [256]u8 = @splat(0);
var focused_buffer: [256]u8 = @splat(0);

const one_line = "make the ball red";
const three_lines = "make the ball red\nand have it bounce\ntwice before it stops";

var filled: bool = false;

/// Put the sample text in once, so typing into the storybook is not undone every
/// frame.
fn fill() void {
    if (filled) return;
    filled = true;
    @memcpy(one_line_buffer[0..one_line.len], one_line);
    @memcpy(three_line_buffer[0..three_lines.len], three_lines);
}

/// One labelled composer.
fn state(
    src: std.builtin.SourceLocation,
    caption: []const u8,
    buffer: []u8,
    is_busy: bool,
    tag: ?[]const u8,
) void {
    const theme = ds.tokens.current;
    var column = ds.column(src).gap(theme.space_2xs).expand(.horizontal).draw();
    defer column.deinit();
    ds.label(@src(), caption).style(.muted).draw();
    var entry = ds.chat.composer(@src(), buffer).busy(is_busy);
    if (tag) |name| entry = entry.tag(name);
    _ = entry.draw();
}

/// The five states, one under the other. Used by the page and by the fixtures.
pub fn states() void {
    fill();
    const theme = ds.tokens.current;
    var column = ds.column(@src()).gap(theme.space_lg).expand(.horizontal).draw();
    defer column.deinit();

    state(@src(), "empty", &empty_buffer, false, null);
    state(@src(), "one line", &one_line_buffer, false, null);
    state(@src(), "three lines", &three_line_buffer, false, null);
    state(@src(), "busy", &busy_buffer, true, null);
    state(@src(), "focused", &focused_buffer, false, "composer.focused");
}

pub fn draw() void {
    const theme = ds.tokens.current;
    ds.label(@src(), "Composer").style(.title).draw();
    ds.gap(@src(), theme.space_2xs);
    ds.label(@src(), "One control height across the row: the attach button, the entry and Send share a top and a bottom edge, and a single-line composer is 44 px tall.").style(.muted).draw();
    ds.gap(@src(), theme.space_md);
    states();
}

/// The same states as a whole-window frame, for the screenshot fixtures.
pub fn frame() !dvui.App.Result {
    var page = dvui.box(@src(), .{}, .{
        .expand = .both,
        .background = true,
        .color_fill = .{ .color = ds.tokens.current.surface_0 },
        .padding = dvui.Rect.all(ds.tokens.current.space_md),
    });
    defer page.deinit();
    states();
    return .ok;
}
