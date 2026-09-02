/// Badge — small Material 3 status badge / chip.
///
/// A static (non-interactive) pill that labels or counts. It renders a tonal
/// rounded-pill background with a medium-weight caption, in one of three variants.
/// In `dot` mode it shrinks to a small filled circle (the text is ignored),
/// useful as a presence/notification indicator next to other content.
///
/// Static by design — a badge is a label, so it has no state layer, hover, or
/// animation.
///
/// Usage:
///   ds.badge(@src(), "New").draw();
///   ds.badge(@src(), "3").variant(.accent).draw();
///   ds.badge(@src(), "Error").variant(.danger).draw();
///   ds.badge(@src(), "").dot(true).variant(.accent).draw();
const std = @import("std");
const dvui = @import("dvui");
const ds = @import("../ds.zig");
const tokens = @import("../tokens.zig");

const Color = dvui.Color;

/// The three badge tones.
pub const BadgeVariant = enum {
    /// Subtle neutral chip — secondary text on a faint white wash.
    neutral,
    /// Accent-tinted chip for highlights / "new".
    accent,
    /// Destructive-tinted chip for errors / warnings.
    danger,
};

pub fn badge(src: std.builtin.SourceLocation, text: []const u8) Badge {
    return .{ .src = src, .text = text };
}

pub const Badge = struct {
    src: std.builtin.SourceLocation,
    text: []const u8,
    badge_variant: BadgeVariant = .neutral,
    is_dot: bool = false,
    id_extra: usize = 0,

    /// Set the badge tone (neutral / accent / danger).
    pub fn variant(self: Badge, val: BadgeVariant) Badge {
        var copy = self;
        copy.badge_variant = val;
        return copy;
    }

    /// Render as a small dot instead of a labelled pill (ignores the text).
    pub fn dot(self: Badge, val: bool) Badge {
        var copy = self;
        copy.is_dot = val;
        return copy;
    }

    /// Disambiguate identity when used in a loop / group.
    pub fn idExtra(self: Badge, val: usize) Badge {
        var copy = self;
        copy.id_extra = val;
        return copy;
    }

    /// Draw the badge.
    pub fn draw(self: Badge) void {
        const theme = tokens.current;
        const base = self.baseColor(theme);

        if (self.is_dot) {
            const diameter = dotSize();
            var box = dvui.box(self.src, .{ .dir = .horizontal }, .{
                .id_extra = self.id_extra,
                .background = true,
                .corners = dvui.CornerRect.round(1000),
                .color_fill = .{ .color = base },
                .min_size_content = dvui.Size.all(diameter),
            });
            box.deinit();
            return;
        }

        var box = dvui.box(self.src, .{ .dir = .horizontal }, .{
            .id_extra = self.id_extra,
            .background = true,
            .corners = dvui.CornerRect.round(1000),
            .padding = ds.paddingXY(theme.space_sm, theme.space_3xs),
            .color_fill = .{ .color = self.fillColor(theme, base) },
        });
        defer box.deinit();

        dvui.labelNoFmt(@src(), self.text, .{}, .{
            .color_text = .{ .color = self.labelColor(theme, base) },
            .font = ds.fontMedium(theme.font_size_sm),
            .gravity_y = 0.5,
        });
    }

    /// The variant's foreground / dot tint.
    fn baseColor(self: Badge, theme: tokens.Theme) Color {
        return switch (self.badge_variant) {
            .neutral => theme.text_secondary,
            .accent => theme.accent,
            .danger => theme.destructive,
        };
    }

    /// The pill background wash for the variant.
    fn fillColor(self: Badge, theme: tokens.Theme, base: Color) Color {
        return switch (self.badge_variant) {
            .neutral => ds.alpha(.white, theme.opacity_subtle_rest),
            .accent, .danger => ds.alpha(base, theme.opacity_tonal_fill),
        };
    }

    /// The label text color for the variant.
    fn labelColor(self: Badge, theme: tokens.Theme, base: Color) Color {
        return switch (self.badge_variant) {
            .neutral => theme.text_secondary,
            .accent, .danger => base,
        };
    }
};

fn dotSize() f32 {
    return 8;
}

test {
    _ = @import("badge_tests.zig");
}
