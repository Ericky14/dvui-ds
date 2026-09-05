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
        const colors = toneColors(self.pill_tone);

        var box = dvui.box(self.src, .{ .dir = .horizontal, .gap = metrics.gap }, .{
            .id_extra = self.id_extra,
            .tag = self.tag_val,
            .background = true,
            .corners = dvui.CornerRect.round(self.radius_val orelse metrics.height),
            .color_fill = .{ .color = colors.fill },
            .padding = ds.paddingXY(metrics.padding_x, 0),
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
                    .min_size_content = .{ .w = theme.icon_sm, .h = theme.icon_sm },
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
        .gap = pixels.snapPx(theme.space_xs, scale),
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
