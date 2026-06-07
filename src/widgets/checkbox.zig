/// Checkbox — Material 3 checkbox with an animated check + state layer.
///
/// Mirrors `dvui.checkbox` (toggles a `*bool`, returns true on change) but draws
/// the M3 treatment: a rounded box that fills with the accent when checked, a
/// checkmark that springs in, and a circular hover/focus/press state layer.
///
/// Usage:
///   if (ds.checkbox(@src(), &accepted).label("I accept").draw()) { ... }
///   _ = ds.checkbox(@src(), &enabled).size(.lg).draw();
///   _ = ds.checkbox(@src(), &locked).label("Locked").disabled(true).draw();
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

pub fn checkbox(src: std.builtin.SourceLocation, target: *bool) Checkbox {
    return .{ .src = src, .target = target };
}

pub const Checkbox = struct {
    src: std.builtin.SourceLocation,
    target: *bool,
    cb_size: tokens.Size = .md,
    label_text: ?[]const u8 = null,
    is_disabled: bool = false,
    id_extra: usize = 0,

    /// Set the control size (sm / md / lg).
    pub fn size(self: Checkbox, val: tokens.Size) Checkbox {
        var c = self;
        c.cb_size = val;
        return c;
    }

    /// Disambiguate instances built from the same `@src()` (loops / groups).
    pub fn idExtra(self: Checkbox, val: usize) Checkbox {
        var c = self;
        c.id_extra = val;
        return c;
    }

    /// Set a label to the right of the box.
    pub fn label(self: Checkbox, text: []const u8) Checkbox {
        var c = self;
        c.label_text = text;
        return c;
    }

    /// Disable interaction and dim the control.
    pub fn disabled(self: Checkbox, val: bool) Checkbox {
        var c = self;
        c.is_disabled = val;
        return c;
    }

    /// Draw the checkbox. Returns true if the value changed this frame.
    pub fn draw(self: Checkbox) bool {
        const theme = tokens.current;

        var opacity: ?ds.Opacity = null;
        if (self.is_disabled) opacity = ds.withOpacity(theme.opacity_disabled);
        defer if (opacity) |o| o.restore();

        const box_size = boxSize(self.cb_size);
        const font_size = labelFontSize(self.cb_size);

        // Root box owns the hit area + focus. Using self.src (the caller's
        // @src()) keeps each instance unique, so child ids derive uniquely too.
        var b = dvui.box(self.src, .{ .dir = .horizontal, .gap = theme.space_sm }, .{
            .id_extra = self.id_extra,
            .padding = ds.paddingXY(theme.space_3xs, theme.space_3xs),
        });
        defer b.deinit();

        dvui.tabIndexSet(b.data().id, b.data().options.tab_index, b.data().rectScale().r);

        var hovered = false;
        var changed = false;
        if (!self.is_disabled) {
            if (dvui.clicked(b.data(), .{ .hovered = &hovered })) {
                self.target.* = !self.target.*;
                changed = true;
            }
        }
        const focused = !self.is_disabled and ds.focusVisible() and b.data().id == dvui.focusedWidgetId();
        const pressed = !self.is_disabled and dvui.captured(b.data().id);

        // Reserve only the box itself for layout (so the label sits close); the
        // state-layer halo is drawn larger, overflowing into the gap — it's
        // translucent and only visible on hover/focus, so the overflow is fine.
        const reserve = dvui.spacer(@src(), .{ .min_size_content = dvui.Size.all(box_size), .gravity_y = 0.5 });
        if (b.data().visible()) {
            drawBox(b.data().id, self.target.*, .{ .hovered = hovered, .pressed = pressed, .focused = focused }, reserve.borderRectScale(), box_size, theme);
        }

        if (self.label_text) |str| {
            dvui.labelNoFmt(@src(), str, .{}, .{
                .color_text = theme.text_primary,
                .font = ds.font(font_size),
                .gravity_y = 0.5,
            });
        }

        return changed;
    }
};

fn boxSize(sz: tokens.Size) f32 {
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

/// Draw the state layer, the (animated) box, and the (animated) checkmark.
fn drawBox(id: dvui.Id, checked: bool, state: anim.InteractionState, rs: RectScale, box_size_logical: f32, theme: tokens.Theme) void {
    const scale = rs.s;
    const center = rs.r.center();

    // Circular state-layer halo (larger than the box, centered) behind it. Ink
    // is the accent when checked, neutral text otherwise.
    const ink = if (checked) theme.accent else theme.text_primary;
    const layer = anim.stateLayer(id, "sl", ink, state);
    centeredSquare(center, box_size_logical * 1.7 * scale).fill(Rect.Physical.all(1000), .{ .color = layer, .fade = 1.0 });

    // The box itself: centered square, animated fill + border.
    const side = box_size_logical * scale;
    const box_rect = centeredSquare(center, side);
    const corner = Rect.Physical.all(theme.radius_sm * scale);

    const fill_target = if (checked) theme.accent else ds.alpha(theme.accent, 0);
    const fill = anim.color(id, "fill", fill_target, .{ .duration = motion.normal });
    box_rect.fill(corner, .{ .color = fill, .fade = 1.0 });

    const border_target = if (checked) theme.accent else theme.border_strong;
    const border_color = anim.color(id, "bd", border_target, .{ .duration = motion.normal });
    box_rect.stroke(corner, .{ .thickness = 2 * scale, .color = border_color });

    // Checkmark springs in/out with the checked state.
    const progress = anim.float(id, "chk", if (checked) 1.0 else 0.0, .{ .duration = motion.normal, .easing = motion.bounce });
    if (progress > 0.01) {
        drawCheckmark(box_rect, progress, theme.surface_0);
    }
}

/// A compact three-point checkmark, positioned by fractions of the box so it's
/// well-proportioned at any size. It scales up from its centroid by `progress`
/// (0..~1.1) and fades in by the same, so it grows in with a subtle overshoot.
fn drawCheckmark(box: Rect.Physical, progress: f32, color: Color) void {
    const w = box.w;
    const thick = w * 0.13;

    const raw = [3]Point.Physical{
        .{ .x = box.x + w * 0.28, .y = box.y + w * 0.52 },
        .{ .x = box.x + w * 0.43, .y = box.y + w * 0.66 },
        .{ .x = box.x + w * 0.72, .y = box.y + w * 0.36 },
    };
    const cx = (raw[0].x + raw[1].x + raw[2].x) / 3.0;
    const cy = (raw[0].y + raw[1].y + raw[2].y) / 3.0;
    const grown = [3]Point.Physical{
        scaleAbout(raw[0], cx, cy, progress),
        scaleAbout(raw[1], cx, cy, progress),
        scaleAbout(raw[2], cx, cy, progress),
    };

    const path: dvui.Path = .{ .points = &grown };
    path.stroke(.{
        .thickness = thick,
        .color = color.opacity(@min(progress, 1.0)),
        .endcap_style = .none,
    });
}

fn scaleAbout(p: Point.Physical, cx: f32, cy: f32, factor: f32) Point.Physical {
    return .{ .x = cx + (p.x - cx) * factor, .y = cy + (p.y - cy) * factor };
}

fn centeredSquare(center: Point.Physical, side: f32) Rect.Physical {
    return .{ .x = center.x - side / 2.0, .y = center.y - side / 2.0, .w = side, .h = side };
}

test {
    _ = @import("checkbox_tests.zig");
}
