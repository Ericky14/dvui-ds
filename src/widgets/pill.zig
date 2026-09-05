/// Pill — a small, fully rounded status or selection readout.
///
/// The chrome's unit of *state you are told*, as opposed to state you press:
/// what is selected ("Ground · 2"), how fast it is running ("60 fps"), what
/// mode is on. Fully rounded on purpose, so it never reads as a button — a
/// rounded-rect readout sitting in a toolbar of rounded-rect buttons is the
/// single most common way a dark UI ends up looking noisy.
///
/// Fixed at `theme.chrome_pill_height`, so a row of pills and a row of chips
/// share a baseline instead of each finding its own.
///
/// Usage:
///   ds.pill(@src(), "Ground · 2").tone(.accent).icon("box", ds.icons.box).draw();
///   ds.pill(@src(), "60 fps").mono(true).draw();
///   ds.pill(@src(), "3 errors").tone(.danger).draw();
const std = @import("std");
const dvui = @import("dvui");
const ds = @import("../ds.zig");
const tokens = @import("../tokens.zig");
const pixels = @import("../helpers/pixels.zig");
pub const Source = @import("../source.zig");

const Color = dvui.Color;

/// A pill's colour role.
pub const PillTone = enum {
    /// Ambient readout — a faint white wash, secondary text.
    neutral,
    /// The thing that is selected or live.
    accent,
    /// Something wrong.
    danger,
};

pub fn pill(src: std.builtin.SourceLocation, text: []const u8) Pill {
    return .{ .src = src, .text = text };
}

pub const Pill = struct {
    src: std.builtin.SourceLocation,
    text: []const u8,
    pill_tone: PillTone = .neutral,
    icon_source: ?Source = null,
    is_mono: bool = false,
    radius_val: ?f32 = null,
    tag_val: ?[]const u8 = null,
    tag_label: ?[]const u8 = null,
    gravity_y: ?f32 = null,
    id_extra: usize = 0,

    /// Set the colour role (neutral / accent / danger).
    pub fn tone(self: Pill, value: PillTone) Pill {
        var copy = self;
        copy.pill_tone = value;
        return copy;
    }

    /// Add a leading icon from the ds icon set.
    pub fn icon(self: Pill, comptime name: [:0]const u8, svg_bytes: []const u8) Pill {
        var copy = self;
        copy.icon_source = Source.namedIcon(name, svg_bytes);
        return copy;
    }

    /// Add a leading icon from any visual `Source`.
    pub fn iconSource(self: Pill, asset: Source) Pill {
        var copy = self;
        copy.icon_source = asset;
        return copy;
    }

    /// Set the label in the mono family — for numbers that change every frame,
    /// so the pill stops twitching as digits change width.
    pub fn mono(self: Pill, value: bool) Pill {
        var copy = self;
        copy.is_mono = value;
        return copy;
    }

    /// Override the corner radius (default: fully rounded).
    pub fn radius(self: Pill, logical_px: f32) Pill {
        var copy = self;
        copy.radius_val = logical_px;
        return copy;
    }

    /// Name the pill for tests and UI automation (`dvui.tagGet`).
    pub fn tag(self: Pill, name: []const u8) Pill {
        var copy = self;
        copy.tag_val = name;
        return copy;
    }

    /// Name the pill's label, so a test can assert it is centred.
    pub fn tagLabel(self: Pill, name: []const u8) Pill {
        var copy = self;
        copy.tag_label = name;
        return copy;
    }

    /// Vertical gravity inside whatever row holds it (0 = top, 0.5 = middle,
    /// 1 = bottom). A pill is shorter than the controls beside it, so in a row
    /// of mixed heights it has to be told where to sit.
    pub fn gravityY(self: Pill, value: f32) Pill {
        var copy = self;
        copy.gravity_y = value;
        return copy;
    }

    /// Disambiguate this instance — a row of pills shares one `@src()`.
    pub fn idExtra(self: Pill, value: usize) Pill {
        var copy = self;
        copy.id_extra = value;
        return copy;
    }

    /// Draw the pill.
    pub fn draw(self: Pill) void {
        const theme = tokens.current;
        const scale = pixels.pixelScale();
        const metrics = pillMetrics(scale);
        const glyph = pixels.squareMetrics(theme.chrome_pill_height, theme.icon_sm, scale);
        const colors = toneColors(self.pill_tone);

        var box = dvui.box(self.src, .{ .dir = .horizontal, .gap = metrics.gap }, .{
            .id_extra = self.id_extra,
            .tag = self.tag_val,
            .background = true,
            .corners = dvui.CornerRect.round(self.radius_val orelse metrics.height),
            .color_fill = .{ .color = colors.fill },
            .padding = ds.paddingXY(metrics.padding_x, 0),
            .gravity_y = self.gravity_y,
            // Pinned, not merely floored: a caption font's line box is taller
            // than the pill (Geist Mono at 11 px reports ~26 px of line, for a
            // 24 px pill), so without the cap every pill would quietly grow to
            // the font's line height and a row of pills would stop sharing a
            // baseline with the chips beside it. The glyphs are far shorter
            // than their line box, so nothing visible is clipped.
            .min_size_content = .{ .h = metrics.height },
            .max_size_content = .height(metrics.height),
        });
        defer box.deinit();

        if (self.icon_source) |asset| {
            if (asset.resolveToTvg()) |resolved| {
                dvui.icon(@src(), resolved.name, resolved.bytes, .{
                    .fill_color = .{ .color = colors.text },
                    .stroke_color = .{ .color = colors.text },
                }, .{
                    .gravity_y = 0.5,
                    // Sized from the pill's own height rather than straight off
                    // `icon_sm`, for the same reason a chip's glyph is: an
                    // 11 px icon is 19.25 physical px at 175 %, and centring a
                    // 19 px box in a 42 px one leaves half a pixel over. Taking
                    // the size from `height - 2*inset` leaves an even remainder,
                    // so the centre lands on a pixel.
                    .min_size_content = .{ .w = glyph.content, .h = glyph.content },
                });
            }
        }

        dvui.labelNoFmt(@src(), self.text, .{}, .{
            .tag = self.tag_label,
            .color_text = .{ .color = colors.text },
            .font = if (self.is_mono)
                ds.fontMonoMedium(theme.font_size_sm)
            else
                ds.fontMedium(theme.font_size_sm),
            .gravity_y = 0.5,
        });
    }
};

/// The pill's physical-pixel geometry. The height is snapped so a row of pills
/// shares one crisp baseline; the horizontal padding is snapped so the round
/// ends are symmetric.
pub fn pillMetrics(scale: f32) struct { height: f32, padding_x: f32, gap: f32 } {
    const theme = tokens.current;
    return .{
        .height = pixels.snapPx(theme.chrome_pill_height, scale),
        .padding_x = pixels.snapPx(theme.space_md, scale),
        // On the 4 px grid, not `space_xs`: the gap between a pill's icon and
        // its label is a gap between two siblings in a row, and the geometry
        // gate measures it as one. `space_xs` is for a control's own insets.
        .gap = pixels.snapPx(theme.space_2xs, scale),
    };
}

const ToneColors = struct { fill: Color, text: Color };

fn toneColors(pill_tone: PillTone) ToneColors {
    const theme = tokens.current;
    return switch (pill_tone) {
        .neutral => .{
            .fill = ds.alpha(.white, theme.opacity_subtle_rest),
            .text = theme.text_secondary,
        },
        .accent => .{
            .fill = ds.alpha(theme.accent, theme.opacity_tonal_fill),
            .text = theme.accent,
        },
        .danger => .{
            .fill = ds.alpha(theme.destructive, theme.opacity_tonal_fill),
            .text = theme.destructive,
        },
    };
}

test {
    _ = @import("pill_tests.zig");
}
