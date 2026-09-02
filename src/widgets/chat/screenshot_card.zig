/// A screenshot the agent captured, shown inline. Returns true when clicked (the
/// caller opens it enlarged). CONTRACT:
///   - Image scaled to fit `max_width` keeping its aspect ratio (use the source's
///     natural size), corners round(radius_md), `border_subtle` border; hover lifts
///     the border to `border_strong`.
///   - Caption row below: camera icon (muted) + caption (muted caption font).
///   - Accepts `ds.Source` images (bytes or file path); vector sources render as-is.
///
/// STATUS: scaffold. The body below is a placeholder that compiles and renders a
/// plain box so consumers can integrate against the API; the real widget replaces
/// `draw()` (and adds private `opts()` resolvers) without changing this surface.
const std = @import("std");
const dvui = @import("dvui");
const ds = @import("../../ds.zig");
const tokens = @import("../../tokens.zig");

pub fn screenshotCard(src: std.builtin.SourceLocation, caption: []const u8, image: ds.Source) ScreenshotCard {
    return .{ .src = src, .caption = caption, .image = image };
}

pub const ScreenshotCard = struct {
    src: std.builtin.SourceLocation,
    caption: []const u8,
    image: ds.Source,
    max_width: f32 = 420,
    id_extra: usize = 0,

    /// Cap the rendered width in logical pixels (default 420).
    pub fn maxWidth(self: ScreenshotCard, val: f32) ScreenshotCard {
        var copy = self;
        copy.max_width = val;
        return copy;
    }

    /// Disambiguate identity when used in a loop / list.
    pub fn idExtra(self: ScreenshotCard, val: usize) ScreenshotCard {
        var copy = self;
        copy.id_extra = val;
        return copy;
    }

    /// Draw the widget.
    pub fn draw(self: ScreenshotCard) bool {
        var box = dvui.box(self.src, .{ .dir = .vertical }, .{ .id_extra = self.id_extra });
        defer box.deinit();
        dvui.labelNoFmt(@src(), self.caption, .{}, .{ .color_text = .{ .color = tokens.current.text_muted } });
        _ = self.image;
        _ = self.max_width;
        return false;
    }
};

test {
    _ = @import("screenshot_card_tests.zig");
}
