/// Chip — a square icon chip, for dense strips of same-shaped actions
/// (a history rail, a tool rail, a tab strip of icons).
///
/// A chip is not a small icon button: it is a *position in a sequence*, so it
/// carries a state the caller sets rather than only the state the mouse
/// produces. `.current` marks where you are (accent ring), `.active` marks a
/// held selection (filled), `.faded` marks entries that exist but are not in
/// play — a redoable future, a disabled-but-present step. All of them stay
/// clickable, because in a strip you navigate by clicking the thing you can
/// see.
///
/// The chip is `theme.chrome_chip_size` square (28 px — over the 24 px minimum
/// hit target and matching the `sm` button height) and its icon is centred, at
/// whole physical pixels on every scale.
///
/// Usage:
///   if (ds.chip(@src(), "undo", ds.icons.undo).idExtra(index).draw()) { … }
///   if (ds.chip(@src(), "edit", ds.icons.pencil)
///          .state(.current)
///          .tooltip("Your edit · 22 min ago")
///          .idExtra(index)
///          .draw()) { … }
const std = @import("std");
const dvui = @import("dvui");
const ds = @import("../ds.zig");
const tokens = @import("../tokens.zig");
const anim = @import("../anim/anim.zig");
const pixels = @import("../helpers/pixels.zig");
pub const Source = @import("../source.zig");

const Color = dvui.Color;

/// Where a chip sits in its strip.
pub const ChipState = enum {
    /// An ordinary entry.
    rest,
    /// A held selection — the tool you are using.
    active,
    /// Where you are in the sequence. Gets the accent ring.
    current,
    /// Present but not in play (a redoable future). Dimmed, still clickable.
    faded,
};

pub fn chip(src: std.builtin.SourceLocation, comptime name: [:0]const u8, svg_bytes: []const u8) Chip {
    return .{ .src = src, .icon_source = Source.namedIcon(name, svg_bytes) };
}

/// Build a chip from any visual `Source` (a pre-made TVG, a raster image).
pub fn chipSource(src: std.builtin.SourceLocation, asset: Source) Chip {
    return .{ .src = src, .icon_source = asset };
}

pub const Chip = struct {
    src: std.builtin.SourceLocation,
    icon_source: Source,
    chip_state: ChipState = .rest,
    tooltip_text: ?[]const u8 = null,
    tag_val: ?[]const u8 = null,
    tag_icon: ?[]const u8 = null,
    id_extra: usize = 0,

    /// Set the chip's place in the strip (rest / active / current / faded).
    pub fn state(self: Chip, value: ChipState) Chip {
        var copy = self;
        copy.chip_state = value;
        return copy;
    }

    /// Show a tooltip on hover.
    pub fn tooltip(self: Chip, text: []const u8) Chip {
        var copy = self;
        copy.tooltip_text = text;
        return copy;
    }

    /// Name the chip for tests and UI automation (`dvui.tagGet`).
    pub fn tag(self: Chip, name: []const u8) Chip {
        var copy = self;
        copy.tag_val = name;
        return copy;
    }

    /// Name the chip's icon, so a test can assert it is centred.
    pub fn tagIcon(self: Chip, name: []const u8) Chip {
        var copy = self;
        copy.tag_icon = name;
        return copy;
    }

    /// Disambiguate this instance — a strip of chips shares one `@src()`.
    pub fn idExtra(self: Chip, value: usize) Chip {
        var copy = self;
        copy.id_extra = value;
        return copy;
    }

    /// Draw the chip. Returns true on click.
    pub fn draw(self: Chip) bool {
        const theme = tokens.current;
        const scale = pixels.pixelScale();
        const metrics = chipMetrics(scale);
        const colors = stateColors(self.chip_state);

        const dim = ds.withOpacity(if (self.chip_state == .faded) theme.opacity_disabled + 0.2 else 1.0);
        defer dim.restore();

        var button: dvui.ButtonWidget = undefined;
        button.init(self.src, .{ .draw_focus = ds.focusVisible() }, .{
            .id_extra = self.id_extra,
            .tag = self.tag_val,
            .corners = dvui.CornerRect.round(theme.radius_sm),
            .margin = dvui.Rect.all(0),
            .padding = dvui.Rect.all(metrics.inset),
            .min_size_content = .{ .w = metrics.content, .h = metrics.content },
            .color_fill = .{ .color = colors.fill },
            .color_fill_hover = .{ .color = colors.fill_hover },
            .color_fill_press = .{ .color = colors.fill_press },
        });
        defer button.deinit();
        defer button.drawFocus();
        button.processEvents();

        const fill = anim.color(button.data().id, "fill", targetFill(&button), .{});
        button.data().borderAndBackground(.{ .fill_color = .{ .color = fill } });

        if (self.chip_state == .current) {
            drawCurrentRing(&button, theme.radius_sm, scale, theme.accent);
        }

        const glyph = anim.color(button.data().id, "icon", colors.icon, .{});
        if (self.icon_source.resolveToTvg()) |resolved| {
            dvui.icon(@src(), resolved.name, resolved.bytes, .{
                .fill_color = .{ .color = glyph },
                .stroke_color = .{ .color = glyph },
            }, .{
                .gravity_x = 0.5,
                .gravity_y = 0.5,
                .tag = self.tag_icon,
                .min_size_content = .{ .w = metrics.content, .h = metrics.content },
            });
        }

        // Inside the button's scope on purpose: the tooltip derives its id from
        // the current parent, so a strip of chips built from one `@src()` still
        // gets one tooltip per chip instead of a single colliding id.
        if (self.tooltip_text) |text| {
            ds.tooltip(@src(), button.data().rectScale().r).text(text).draw();
        }

        return button.clicked();
    }
};

/// The chip's physical-pixel geometry — the same `squareMetrics` an icon button
/// uses, so a chip and an `sm` icon button are the same square and their icons
/// are inset identically.
pub fn chipMetrics(scale: f32) pixels.Square {
    const theme = tokens.current;
    return pixels.squareMetrics(theme.chrome_chip_size, theme.icon_md, scale);
}

const StateColors = struct { fill: Color, fill_hover: Color, fill_press: Color, icon: Color };

fn stateColors(chip_state: ChipState) StateColors {
    const theme = tokens.current;
    return switch (chip_state) {
        .rest, .faded => .{
            .fill = .transparent,
            .fill_hover = ds.alpha(.white, theme.opacity_ghost_hover),
            .fill_press = ds.alpha(.white, theme.opacity_ghost_press),
            .icon = theme.text_secondary,
        },
        .active => .{
            .fill = ds.alpha(theme.accent, theme.opacity_fill_rest),
            .fill_hover = ds.alpha(theme.accent, theme.opacity_fill_hover),
            .fill_press = ds.alpha(theme.accent, theme.opacity_fill_press),
            .icon = theme.accent,
        },
        .current => .{
            .fill = ds.alpha(theme.accent, theme.opacity_subtle_rest),
            .fill_hover = ds.alpha(theme.accent, theme.opacity_subtle_hover),
            .fill_press = ds.alpha(theme.accent, theme.opacity_subtle_press),
            .icon = theme.text_primary,
        },
    };
}

fn targetFill(button: *dvui.ButtonWidget) Color {
    if (dvui.captured(button.data().id)) return button.data().options.color(.fill_press).toColor();
    if (button.hover) return button.data().options.color(.fill_hover).toColor();
    return button.data().options.color(.fill).toColor();
}

/// The accent ring that marks "you are here". 2 logical px, snapped, stroked
/// inside the chip so a ring never overlaps its neighbour in a tight strip.
fn drawCurrentRing(button: *dvui.ButtonWidget, corner: f32, scale: f32, accent: Color) void {
    const rs = button.data().backgroundRectScale();
    if (rs.r.w < 2 or rs.r.h < 2) return;
    const thickness = @max(1, @round(2 * scale));
    const inset = thickness / 2;
    const ring: dvui.Rect.Physical = .{
        .x = rs.r.x + inset,
        .y = rs.r.y + inset,
        .w = @max(0, rs.r.w - thickness),
        .h = @max(0, rs.r.h - thickness),
    };
    ring.stroke(.round(@max(0, corner * scale - inset)), .{
        .thickness = thickness,
        .color = .{ .color = accent },
        .closed = true,
        .fade = 1,
    });
}

test {
    _ = @import("chip_tests.zig");
}
