/// An engine / build / script error surfaced into the chat. Returns true on the frame
/// "Fix it" is clicked (the caller sends the error to the agent). CONTRACT:
///   - Container: destructive-tinted fill (ds.alpha destructive at tonal-fill opacity),
///     destructive border, corners round(radius_md).
///   - Row: error icon (destructive) + message (primary; mono when multi-line or
///     compiler-shaped), then `location` (muted mono, e.g. "scripts/ball.lua:12").
///   - "Fix it" button: outlined danger, sm, right-aligned.
///
/// STATUS: scaffold. The body below is a placeholder that compiles and renders a
/// plain box so consumers can integrate against the API; the real widget replaces
/// `draw()` (and adds private `opts()` resolvers) without changing this surface.
const std = @import("std");
const dvui = @import("dvui");
const ds = @import("../../ds.zig");
const tokens = @import("../../tokens.zig");

pub fn errorCard(src: std.builtin.SourceLocation, message_text: []const u8, location: ?[]const u8) ErrorCard {
    return .{ .src = src, .message_text = message_text, .location = location };
}

pub const ErrorCard = struct {
    src: std.builtin.SourceLocation,
    message_text: []const u8,
    location: ?[]const u8,
    id_extra: usize = 0,

    /// Disambiguate identity when used in a loop / list.
    pub fn idExtra(self: ErrorCard, val: usize) ErrorCard {
        var copy = self;
        copy.id_extra = val;
        return copy;
    }

    /// Draw the widget.
    pub fn draw(self: ErrorCard) bool {
        var box = dvui.box(self.src, .{ .dir = .vertical }, .{
            .id_extra = self.id_extra,
            .expand = .horizontal,
            .background = true,
            .color_fill = .{ .color = ds.alpha(tokens.current.destructive, tokens.current.opacity_tonal_fill) },
            .padding = dvui.Rect.all(tokens.current.space_sm),
        });
        defer box.deinit();
        dvui.labelNoFmt(@src(), self.message_text, .{}, .{});
        if (self.location) |loc| dvui.labelNoFmt(@src(), loc, .{}, .{ .color_text = .{ .color = tokens.current.text_muted } });
        return false;
    }
};

test {
    _ = @import("error_card_tests.zig");
}
