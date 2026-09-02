/// Radio — Material 3 radio button with an animated inner dot + state layer.
///
/// Like `ds.checkbox` but circular and group-oriented: the caller owns the
/// group's selection. Pass whether THIS option is the selected one; `draw()`
/// returns true when the option was clicked, and the caller updates its
/// selection. Draws the M3 treatment: an outer ring that tints to the accent
/// when active, an inner dot that springs in/out, and a circular
/// hover/focus/press state layer.
///
/// Usage:
///   if (ds.radio(@src(), choice == 0, "Option A").draw()) choice = 0;
///   if (ds.radio(@src(), choice == 1, "Option B").draw()) choice = 1;
///   _ = ds.radio(@src(), true, null).size(.lg).draw();
///   _ = ds.radio(@src(), false, "Locked").disabled(true).idExtra(7).draw();
const std = @import("std");
const dvui = @import("dvui");
const ds = @import("../ds.zig");
const tokens = @import("../tokens.zig");
const anim = @import("../anim/anim.zig");
const motion = @import("../motion.zig");

const Color = dvui.Color;
const RectScale = dvui.RectScale;
const Point = dvui.Point;
const Rect = dvui.Rect;

pub fn radio(src: std.builtin.SourceLocation, active: bool, label_str: ?[]const u8) Radio {
    return .{ .src = src, .is_active = active, .label_text = label_str };
}

pub const Radio = struct {
    src: std.builtin.SourceLocation,
    is_active: bool,
    label_text: ?[]const u8 = null,
    radio_size: tokens.Size = .md,
    is_disabled: bool = false,
    id_extra: usize = 0,

    /// Set the control size (sm / md / lg).
    pub fn size(self: Radio, val: tokens.Size) Radio {
        var copy = self;
        copy.radio_size = val;
        return copy;
    }

    /// Disable interaction and dim the control.
    pub fn disabled(self: Radio, val: bool) Radio {
        var copy = self;
        copy.is_disabled = val;
        return copy;
    }

    /// Disambiguate instances built from the same `@src()` (loops / groups).
    pub fn idExtra(self: Radio, val: usize) Radio {
        var copy = self;
        copy.id_extra = val;
        return copy;
    }

    /// Draw the radio. Returns true if it was clicked this frame.
    pub fn draw(self: Radio) bool {
        const theme = tokens.current;

        var opacity: ?ds.Opacity = null;
        if (self.is_disabled) opacity = ds.withOpacity(theme.opacity_disabled);
        defer if (opacity) |o| o.restore();

        const circle_size = circleSize(self.radio_size);
        const font_size = labelFontSize(self.radio_size);

        // Root box owns the hit area + focus. Using self.src (the caller's
        // @src()) plus id_extra keeps each instance unique, so child ids derive
        // uniquely too.
        var b = dvui.box(self.src, .{ .dir = .horizontal, .gap = theme.space_sm }, .{
            .padding = ds.paddingXY(theme.space_3xs, theme.space_3xs),
            .id_extra = self.id_extra,
        });
        defer b.deinit();

        dvui.tabIndexSet(b.data().id, b.data().options.tab_index, b.data().rectScale().r);

        var hovered = false;
        var clicked = false;
        if (!self.is_disabled) {
            if (dvui.clicked(b.data(), .{ .hovered = &hovered })) {
                clicked = true;
            }
        }
        const focused = !self.is_disabled and ds.focusVisible() and b.data().id == dvui.focusedWidgetId();
        const pressed = !self.is_disabled and dvui.captured(b.data().id);

        // Reserve only the circle for layout (so the label sits close); the
        // state-layer halo is drawn larger and overflows into the gap.
        const reserve = dvui.spacer(@src(), .{ .min_size_content = dvui.Size.all(circle_size), .gravity_y = 0.5 });
        if (b.data().visible()) {
            drawCircle(b.data().id, self.is_active, .{ .hovered = hovered, .pressed = pressed, .focused = focused }, reserve.borderRectScale(), circle_size, theme);
        }

        if (self.label_text) |str| {
            dvui.labelNoFmt(@src(), str, .{}, .{
                .color_text = .{ .color = theme.text_primary },
                .font = ds.font(font_size),
                .gravity_y = 0.5,
            });
        }

        return clicked;
    }
};

fn circleSize(sz: tokens.Size) f32 {
    return switch (sz) {
        .sm => 16,
        .md => 18,
        .lg => 20,
    };
}

fn labelFontSize(sz: tokens.Size) u16 {
    const theme = tokens.current;
    return switch (sz) {
        .sm => theme.font_size_sm,
        .md => theme.font_size_md,
        .lg => theme.font_size_lg,
    };
}

/// Draw the state layer, the (animated) ring, and the (animated) inner dot.
fn drawCircle(id: dvui.Id, active: bool, state: anim.InteractionState, rs: RectScale, circle_size_logical: f32, theme: tokens.Theme) void {
    const scale = rs.s;
    const center = rs.r.center();

    // Circular state-layer halo behind the ring. Ink is the accent when active,
    // neutral text otherwise.
    const ink = if (active) theme.accent else theme.text_primary;
    const layer = anim.stateLayer(id, "sl", ink, state);
    centeredSquare(center, circle_size_logical * 1.7 * scale).fill(dvui.CornerRect.Physical.round(1000), .{ .color = .{ .color = layer }, .fade = 1.0 });

    // The outer ring: centered circle, animated border, transparent fill.
    const diameter = circle_size_logical * scale;
    const ring_rect = centeredSquare(center, diameter);
    const circle_corner = dvui.CornerRect.Physical.round(1000);

    const border_target = if (active) theme.accent else theme.border_strong;
    const border_color = anim.color(id, "bd", border_target, .{ .duration = motion.normal });
    ring_rect.stroke(circle_corner, .{ .thickness = 2 * scale, .color = .{ .color = border_color } });

    // Inner dot springs in/out with the active state.
    const progress = anim.float(id, "dot", if (active) 1.0 else 0.0, .{ .duration = motion.normal, .easing = motion.bounce });
    if (progress > 0.01) {
        const base_dot = circle_size_logical * 0.5 * scale;
        const dot_diameter = base_dot * @min(progress, 1.1);
        const dot_rect = centeredSquare(center, dot_diameter);
        dot_rect.fill(circle_corner, .{
            .color = .{ .color = theme.accent.opacity(@min(progress, 1.0)) },
            .fade = 1.0,
        });
    }
}

fn centeredSquare(center: Point.Physical, side: f32) Rect.Physical {
    return .{ .x = center.x - side / 2.0, .y = center.y - side / 2.0, .w = side, .h = side };
}

test {
    _ = @import("radio_tests.zig");
}
