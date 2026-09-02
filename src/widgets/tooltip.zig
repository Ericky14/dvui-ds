/// Tooltip — themed wrapper over `dvui.tooltip`.
///
/// Shows a small floating bubble when the mouse hovers the trigger's physical
/// rect. The caller passes that rect (e.g. `some_widget.data().rectScale().r`),
/// so the tooltip is decoupled from the trigger's layout.
///
/// Usage:
///   var trigger = ds.row(@src()).draw();
///   defer trigger.deinit();
///   ds.label(@src(), "Hover me").draw();
///   ds.tooltip(@src(), trigger.data().rectScale().r)
///       .text("Helpful hint")
///       .position(.vertical)
///       .draw();
const std = @import("std");
const dvui = @import("dvui");
const ds = @import("../ds.zig");
const tokens = @import("../tokens.zig");

/// Re-export of dvui's tooltip placement enum for convenient access via the DS.
pub const Position = dvui.FloatingTooltipWidget.Position;

/// Default delay before the tooltip appears, in microseconds (matches M3 feel).
const default_delay: i32 = 300_000;

pub fn tooltip(src: std.builtin.SourceLocation, active_rect: dvui.Rect.Physical) Tooltip {
    return .{ .src = src, .active_rect = active_rect };
}

pub const Tooltip = struct {
    src: std.builtin.SourceLocation,
    active_rect: dvui.Rect.Physical,
    text_str: []const u8 = "",
    position_val: Position = .vertical,
    delay_val: i32 = default_delay,

    /// Set the tooltip's text content.
    pub fn text(self: Tooltip, value: []const u8) Tooltip {
        var copy = self;
        copy.text_str = value;
        return copy;
    }

    /// Set how the bubble is placed relative to the trigger rect.
    pub fn position(self: Tooltip, value: Position) Tooltip {
        var copy = self;
        copy.position_val = value;
        return copy;
    }

    /// Set the hover delay before the tooltip appears, in microseconds.
    pub fn delay(self: Tooltip, microseconds: i32) Tooltip {
        var copy = self;
        copy.delay_val = microseconds;
        return copy;
    }

    /// Materialize the tooltip. Renders nothing until the mouse hovers the
    /// trigger rect for the configured delay.
    pub fn draw(self: Tooltip) void {
        dvui.tooltip(
            self.src,
            .{
                .active_rect = self.active_rect,
                .position = self.position_val,
                .delay = self.delay_val,
            },
            "{s}",
            .{self.text_str},
            self.opts(),
        );
    }

    fn opts(self: Tooltip) dvui.Options {
        _ = self;
        const theme = tokens.current;
        const radius = dvui.CornerRect.round(theme.radius_md);
        return .{
            .color_fill = .{ .color = theme.surface_2 },
            .background = true,
            .corners = radius,
            .border = dvui.Rect.all(theme.border_width),
            .color_border = .{ .color = theme.border },
            .color_text = .{ .color = theme.text_primary },
            .font = ds.font(theme.font_size_sm),
            .padding = ds.paddingXY(theme.space_sm, theme.space_3xs),
            .box_shadow = .{
                .color = theme.shadow_color,
                .corners = radius,
                .offset = .{ .x = 0, .y = 2 },
                .fade = 12,
                .alpha = theme.shadow_alpha,
            },
        };
    }
};

test {
    _ = @import("tooltip_tests.zig");
}
