/// Card — Material 3 surface container.
///
/// A themed `dvui.box` with the three M3 card treatments: `elevated` (shadow),
/// `filled` (tonal surface), and `outlined` (border). Returns a layout handle —
/// `defer card.deinit();` and put your content inside.
///
/// Usage:
///   var c = ds.card(@src()).draw();
///   defer c.deinit();
///   ds.label(@src(), "Title").style(.title).draw();
///
///   var c = ds.card(@src()).variant(.outlined).padding(16).draw();
///   defer c.deinit();
const std = @import("std");
const dvui = @import("dvui");
const ds = @import("../ds.zig");
const tokens = @import("../tokens.zig");

/// The three Material 3 card treatments.
pub const CardVariant = enum {
    /// Tonal surface lifted by a soft drop shadow.
    elevated,
    /// Tonal surface, no shadow, no border.
    filled,
    /// Surface with a 1px outline, no shadow.
    outlined,
};

pub fn card(src: std.builtin.SourceLocation) Card {
    return .{ .src = src };
}

pub const Card = struct {
    src: std.builtin.SourceLocation,
    card_variant: CardVariant = .elevated,
    dir: dvui.enums.Direction = .vertical,
    gap_val: f32 = 0,
    pad_override: ?dvui.Rect = null,
    expand_override: ?dvui.Options.Expand = null,

    /// Set the card treatment (elevated / filled / outlined).
    pub fn variant(self: Card, val: CardVariant) Card {
        var c = self;
        c.card_variant = val;
        return c;
    }

    /// Lay children out horizontally instead of vertically.
    pub fn horizontal(self: Card) Card {
        var c = self;
        c.dir = .horizontal;
        return c;
    }

    /// Gap between children (px).
    pub fn gap(self: Card, px: f32) Card {
        var c = self;
        c.gap_val = px;
        return c;
    }

    /// Override the inner padding (default: theme.space_lg uniform).
    pub fn padding(self: Card, px: f32) Card {
        var c = self;
        c.pad_override = dvui.Rect.all(px);
        return c;
    }

    /// Override the inner padding with a custom rect.
    pub fn paddingRect(self: Card, rect: dvui.Rect) Card {
        var c = self;
        c.pad_override = rect;
        return c;
    }

    /// Expand to fill available space.
    pub fn expand(self: Card, val: dvui.Options.Expand) Card {
        var c = self;
        c.expand_override = val;
        return c;
    }

    /// Materialize the card container. Call `deinit()` on the result when done.
    pub fn draw(self: Card) *dvui.BoxWidget {
        const box = dvui.box(self.src, .{ .dir = self.dir, .gap = self.gap_val }, self.opts());
        if (self.card_variant == .outlined) drawOutline(box);
        return box;
    }

    fn opts(self: Card) dvui.Options {
        const theme = tokens.current;
        const radius = dvui.Rect.all(theme.radius_lg);
        const pad = self.pad_override orelse dvui.Rect.all(theme.space_lg);

        var options: dvui.Options = .{
            .background = true,
            .corner_radius = radius,
            .padding = pad,
            .expand = self.expand_override,
        };

        switch (self.card_variant) {
            .elevated => {
                options.color_fill = theme.surface_2;
                options.box_shadow = .{
                    .color = .black,
                    .corner_radius = radius,
                    .offset = .{ .x = 0, .y = 3 },
                    .fade = 16,
                    .alpha = 0.4,
                };
            },
            .filled => {
                options.color_fill = theme.surface_1;
            },
            .outlined => {
                // The border is painted manually in `drawOutline` as an even SDF
                // ring — dvui's thin uniform-border stroke renders unevenly on
                // horizontal vs vertical edges at fractional scales. The box
                // itself paints nothing.
                options.background = false;
            },
        }
        return options;
    }
};

/// Paint the outlined card's border as two concentric SDF fills (border color,
/// then the surface inset by the border width). SDF rounded-rect fills are
/// symmetric on all sides, unlike a thin stroked path.
fn drawOutline(box: *dvui.BoxWidget) void {
    const theme = tokens.current;
    const rs = box.data().borderRectScale();
    if (rs.r.empty()) return;
    const radius = theme.radius_lg * rs.s;
    const border_w = theme.border_width * rs.s;
    rs.r.fill(dvui.Rect.Physical.all(radius), .{ .color = theme.border, .fade = 1.0 });
    rs.r.insetAll(border_w).fill(dvui.Rect.Physical.all(@max(0, radius - border_w)), .{ .color = theme.surface_0, .fade = 1.0 });
}

test {
    _ = @import("card_tests.zig");
}
