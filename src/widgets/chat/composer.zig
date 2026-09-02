/// The chat composer at the bottom of the chat pane. CONTRACT:
///   - Multi-line text entry over `buffer`, auto-growing from 1 to 8 rows, then scrolls.
///   - Enter submits when the buffer is non-empty; Shift+Enter inserts a newline; Esc
///     reports `interrupted` when `busy`.
///   - Left: attach icon button (ghost). Right: Send (filled, accent) or, when busy, a
///     Stop button (danger), both sm.
///   - Below: a muted mono hint row "enter send / shift+enter newline / esc stop".
///   - Container: `surface_1` fill, `border_strong` border, corners round(radius_md),
///     focus ring in accent when the entry has focus.
///   - The buffer is owned by the caller and is never resized here.
///
/// STATUS: scaffold. The body below is a placeholder that compiles and renders a
/// plain box so consumers can integrate against the API; the real widget replaces
/// `draw()` (and adds private `opts()` resolvers) without changing this surface.
const std = @import("std");
const dvui = @import("dvui");
const ds = @import("../../ds.zig");
const tokens = @import("../../tokens.zig");

/// What the composer reported this frame.
pub const ComposerResult = struct {
    /// Enter was pressed with a non-empty buffer (or Send clicked). The caller reads
    /// the buffer, sends it, and clears it.
    submitted: bool = false,
    /// Esc was pressed or Stop clicked while `busy`.
    interrupted: bool = false,
    /// The attach (paperclip) button was clicked.
    attach_clicked: bool = false,
};
pub fn composer(src: std.builtin.SourceLocation, buffer: []u8) Composer {
    return .{ .src = src, .buffer = buffer };
}

pub const Composer = struct {
    src: std.builtin.SourceLocation,
    buffer: []u8,
    placeholder_text: []const u8 = "Ask for anything...",
    is_busy: bool = false,
    id_extra: usize = 0,

    /// Placeholder shown when the buffer is empty.
    pub fn placeholder(self: Composer, val: []const u8) Composer {
        var copy = self;
        copy.placeholder_text = val;
        return copy;
    }

    /// Agent is running: show Stop instead of Send; Esc interrupts.
    pub fn busy(self: Composer, val: bool) Composer {
        var copy = self;
        copy.is_busy = val;
        return copy;
    }

    /// Disambiguate identity when used in a loop / list.
    pub fn idExtra(self: Composer, val: usize) Composer {
        var copy = self;
        copy.id_extra = val;
        return copy;
    }

    /// Draw the widget.
    pub fn draw(self: Composer) ComposerResult {
        var box = dvui.box(self.src, .{ .dir = .vertical }, .{ .id_extra = self.id_extra, .expand = .horizontal });
        defer box.deinit();
        ds.textarea(@src(), self.buffer).placeholder(self.placeholder_text).rows(2).expand(.horizontal).draw();
        _ = self.is_busy;
        return .{};
    }
};

test {
    _ = @import("composer_tests.zig");
}
