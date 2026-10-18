/// ScreenshotCard — a screenshot the agent captured, shown inline. Returns true
/// when clicked (the caller opens it enlarged). CONTRACT:
///   - Image at its natural size — one image pixel per physical pixel
///     (`ds.imageNaturalSize`), never upscaled — narrowed so that it and its
///     border fit `max_width`, keeping its aspect ratio (`fitSize`), corners
///     round(radius_md), `border_subtle` border; hover lifts the border to
///     `border_strong`.
///   - Caption row below: camera icon (muted) + caption (muted caption font),
///     never wider than `max_width` — a longer caption (a file's path) wraps
///     there instead of ending in "…", the icon level with its first line.
///   - Accepts `ds.Source` images (bytes or file path); vector sources render as-is
///     (at the large icon size) inside the same frame.
///
/// Usage:
///   if (ds.chat.screenshotCard(@src(), "preview after the change", ds.Source.imageBytes(png)).draw()) open(png);
///   _ = ds.chat.screenshotCard(@src(), caption, ds.Source.pixels(rgba, 640, 360)).maxWidth(320).idExtra(index).draw();
const std = @import("std");
const dvui = @import("dvui");
const ds = @import("../../ds.zig");
const tokens = @import("../../tokens.zig");
const anim = @import("../../anim/anim.zig");
const icon_widget = @import("../icon.zig");

/// Natural size assumed when a raster source cannot report one (corrupt bytes).
const fallback_size: dvui.Size = .{ .w = 160, .h = 90 };

pub fn screenshotCard(src: std.builtin.SourceLocation, caption: []const u8, image: ds.Source) ScreenshotCard {
    return .{ .src = src, .caption = caption, .image = image };
}

pub const ScreenshotCard = struct {
    src: std.builtin.SourceLocation,
    caption: []const u8,
    image: ds.Source,
    max_width: f32 = 420,
    id_extra: usize = 0,

    /// Cap the rendered width in logical pixels (default 420): the picture
    /// with its border, and the caption, never wider than this.
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
        const theme = tokens.current;

        var card = dvui.box(self.src, .{ .dir = .vertical, .gap = theme.space_2xs }, .{ .id_extra = self.id_extra });
        defer card.deinit();

        var clicked = false;
        {
            // The frame is the hover / click target; the image inside carries the
            // rounded border so the hover colour can be resolved first.
            var frame = dvui.box(@src(), .{}, .{});
            defer frame.deinit();

            var hovered = false;
            if (dvui.clicked(frame.data(), .{ .hovered = &hovered })) clicked = true;
            const border_target = if (hovered) theme.border_strong else theme.border_subtle;
            const border_color = anim.color(frame.data().id, "bd", border_target, .{});

            switch (self.image.kind) {
                .image => |image_source| {
                    const natural = ds.imageNaturalSize(image_source) catch fallback_size;
                    // `max_width` holds the card as drawn, its border
                    // included: the picture gets what the border leaves.
                    const edge = ds.border(theme.border_width);
                    const fitted = fitSize(natural, @max(0, self.max_width - edge.x - edge.w));
                    _ = dvui.image(@src(), .{ .source = image_source, .shrink = .ratio }, imageOpts(theme, fitted, border_color));
                },
                .tvg, .named_icon => {
                    var holder = dvui.box(@src(), .{}, vectorHolderOpts(theme, border_color));
                    defer holder.deinit();
                    ds.icon(@src(), self.image).size(.lg).style(.secondary).draw();
                },
            }
        }

        {
            var caption = dvui.box(@src(), .{ .dir = .horizontal, .gap = theme.space_2xs }, .{
                .expand = .horizontal,
                // The card's cap holds the words too: past it they wrap.
                .max_size_content = .{ .w = self.max_width, .h = dvui.max_float_safe },
            });
            defer caption.deinit();
            {
                // A lane the row's height with the icon at the first line's
                // level, however many lines the words wrap to.
                var lane = dvui.box(@src(), .{ .dir = .vertical }, .{ .expand = .vertical, .padding = .{ .y = iconTop(theme) } });
                defer lane.deinit();
                ds.icon(@src(), ds.Source.namedIcon("camera", ds.icons.camera)).style(.muted).size(.sm).gravityY(0).draw();
            }
            var words = dvui.textLayout(@src(), .{ .break_lines = true }, captionOpts(theme));
            defer words.deinit();
            words.addText(self.caption, .{});
        }

        return clicked;
    }
};

/// Scale `natural` down to `max_width` keeping its aspect ratio; smaller images
/// keep their natural size (never upscaled). Degenerate sizes pass through.
/// The picture-size rule's own `ds.imageFitWidth`.
pub const fitSize = ds.imageFitWidth;

/// Rounded, bordered raster image at its fitted size.
fn imageOpts(theme: tokens.Theme, fitted: dvui.Size, border_color: dvui.Color) dvui.Options {
    return .{
        .min_size_content = fitted,
        .corners = dvui.CornerRect.round(theme.radius_md),
        .border = ds.border(theme.border_width),
        .color_border = .{ .color = border_color },
    };
}

/// The same frame for vector sources, which have no natural size: padded around
/// a large icon.
fn vectorHolderOpts(theme: tokens.Theme, border_color: dvui.Color) dvui.Options {
    return .{
        .corners = dvui.CornerRect.round(theme.radius_md),
        .border = ds.border(theme.border_width),
        .color_border = .{ .color = border_color },
        .padding = ds.padding(theme.space_lg),
    };
}

/// How far below the caption row's top the camera icon sits: centred on the
/// first line of the words (their top padding plus half a line).
fn iconTop(theme: tokens.Theme) f32 {
    const line = ds.font(theme.font_size_sm).lineHeight();
    const offset = theme.space_3xs + line / 2 - icon_widget.iconSize(.sm) / 2;
    return if (offset > 0) ds.snapPx(offset, ds.pixelScale()) else 0;
}

fn captionOpts(theme: tokens.Theme) dvui.Options {
    return .{
        .expand = .horizontal,
        .background = false,
        .color_text = .{ .color = theme.text_muted },
        .font = ds.font(theme.font_size_sm),
        .padding = ds.paddingXY(0, theme.space_3xs),
        .gravity_y = 0.5,
    };
}

test {
    _ = @import("screenshot_card_tests.zig");
}
