/// Switch — Material 3 toggle switch with an animated knob + state layer.
///
/// Mirrors `dvui.checkbox` semantics (toggles a `*bool`, returns true on change)
/// but draws the M3 switch treatment: a pill track that animates between the
/// neutral surface and the accent, a knob that slides across and grows when on,
/// and a circular hover/focus/press state layer that follows the knob.
///
/// The builder fn is named `toggle` because `switch` is a Zig keyword; the type
/// is `Switch`.
///
/// Usage:
///   if (ds.toggle(@src(), &wifi).label("Wi-Fi").draw()) { ... }
///   _ = ds.toggle(@src(), &enabled).size(.lg).draw();
///   _ = ds.toggle(@src(), &locked).label("Locked").disabled(true).draw();
///   // In a loop / group, give each item a stable extra id:
///   _ = ds.toggle(@src(), &flags[idx]).idExtra(idx).draw();
const std = @import("std");
const dvui = @import("dvui");
const ds = @import("../ds.zig");
const tokens = @import("../tokens.zig");
const anim = @import("../anim/anim.zig");
const motion = @import("../motion.zig");
const ds_focus = @import("ds_focus");

const Color = dvui.Color;
const RectScale = dvui.RectScale;
const Point = dvui.Point;
const Rect = dvui.Rect;

/// Track geometry for a given size, in logical pixels.
const TrackGeometry = struct {
    width: f32,
    height: f32,
};

pub fn toggle(src: std.builtin.SourceLocation, target: *bool) Switch {
    return .{ .src = src, .target = target };
}

pub const Switch = struct {
    src: std.builtin.SourceLocation,
    target: *bool,
    sw_size: tokens.Size = .md,
    label_text: ?[]const u8 = null,
    is_disabled: bool = false,
    id_extra: usize = 0,

    /// Set the control size (sm / md / lg).
    pub fn size(self: Switch, val: tokens.Size) Switch {
        var copy = self;
        copy.sw_size = val;
        return copy;
    }

    /// Set a label to the right of the switch.
    pub fn label(self: Switch, text: []const u8) Switch {
        var copy = self;
        copy.label_text = text;
        return copy;
    }

    /// Disable interaction and dim the control.
    pub fn disabled(self: Switch, val: bool) Switch {
        var copy = self;
        copy.is_disabled = val;
        return copy;
    }

    /// Extra id disambiguator for switches drawn in a loop or group, where the
    /// caller's `@src()` is shared across items. Pass the loop index.
    pub fn idExtra(self: Switch, val: usize) Switch {
        var copy = self;
        copy.id_extra = val;
        return copy;
    }

    /// Draw the switch. Returns true if the value changed this frame.
    pub fn draw(self: Switch) bool {
        const theme = tokens.current;

        var opacity: ?ds.Opacity = null;
        if (self.is_disabled) opacity = ds.withOpacity(theme.opacity_disabled);
        defer if (opacity) |o| o.restore();

        const track = trackGeometry(self.sw_size);
        const knob_on_diameter = track.height - 4;
        const knob_off_diameter = track.height - 8;
        const reserve_height = @max(track.height, knob_on_diameter * 1.7);
        // The state-layer halo (≈1.7× the on-knob) can reach past the track ends
        // at the travel extremes; reserve that horizontal overhang so it doesn't
        // bleed into the label/adjacent content.
        const halo_radius = knob_on_diameter * 1.7 / 2.0;
        const knob_inset = (track.height - knob_off_diameter) / 2.0 + knob_off_diameter / 2.0;
        const reserve_width = track.width + @max(0, halo_radius - knob_inset) * 2.0;
        const font_size = labelFontSize(self.sw_size);

        // Root box owns the hit area + focus. Using self.src (the caller's
        // @src()) keeps each instance unique; .id_extra disambiguates loops.
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
        const focused = !self.is_disabled and ds_focus.visible() and b.data().id == dvui.focusedWidgetId();
        const pressed = !self.is_disabled and dvui.captured(b.data().id);

        const reserve = dvui.spacer(@src(), .{
            .min_size_content = .{ .w = reserve_width, .h = reserve_height },
            .gravity_y = 0.5,
        });
        if (b.data().visible()) {
            drawSwitch(
                b.data().id,
                self.target.*,
                .{ .hovered = hovered, .pressed = pressed, .focused = focused },
                reserve.borderRectScale(),
                track,
                theme,
            );
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

fn trackGeometry(sz: tokens.Size) TrackGeometry {
    return switch (sz) {
        .sm => .{ .width = 36, .height = 20 },
        .md => .{ .width = 44, .height = 24 },
        .lg => .{ .width = 52, .height = 28 },
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

/// Draw the state-layer halo, the (animated) track pill, and the (animated)
/// sliding knob. The reserve rect `rs` may be taller than the track (it leaves
/// room for the halo), so the track is centered vertically inside it.
fn drawSwitch(id: dvui.Id, on: bool, state: anim.InteractionState, rs: RectScale, track: TrackGeometry, theme: tokens.Theme) void {
    const scale = rs.s;
    const center = rs.r.center();

    const track_width = track.width * scale;
    const track_height = track.height * scale;
    const off_diameter = (track.height - 8) * scale;
    const on_diameter = (track.height - 4) * scale;

    // Knob diameter grows from off -> on. Animate the LOGICAL diameter and scale
    // the result, so a DPI/scale change doesn't spuriously restart the animation.
    const diameter = anim.float(id, "dia", if (on) (track.height - 4) else (track.height - 8), .{ .duration = motion.normal, .easing = motion.inOut }) * scale;

    // Track pill centered in the reserved rect.
    const track_rect = Rect.Physical{
        .x = center.x - track_width / 2.0,
        .y = center.y - track_height / 2.0,
        .w = track_width,
        .h = track_height,
    };

    // Knob slides between the left and right insets. The inset is measured from
    // the off-diameter so the smaller knob is symmetric in the track ends.
    const inset = (track_height - off_diameter) / 2.0;
    const knob_radius = diameter / 2.0;
    const left_center_x = track_rect.x + inset + off_diameter / 2.0;
    const right_center_x = track_rect.x + track_width - inset - off_diameter / 2.0;
    const progress = anim.float(id, "pos", if (on) 1.0 else 0.0, .{ .duration = motion.normal, .easing = motion.inOut });
    const knob_center = Point.Physical{
        .x = left_center_x + (right_center_x - left_center_x) * progress,
        .y = center.y,
    };

    // 1) Circular state-layer halo, centered on the knob, behind everything.
    const ink = if (on) theme.accent else theme.text_primary;
    const layer = anim.stateLayer(id, "sl", ink, state);
    const halo_radius = (on_diameter * 1.7) / 2.0;
    const halo_rect = circleRect(knob_center, halo_radius);
    halo_rect.fill(Rect.Physical.all(1000), .{ .color = layer, .fade = 1.0 });

    // 2) Track pill, animating fill color between surface_3 and accent.
    const track_target = if (on) theme.accent else theme.surface_3;
    const track_color = anim.color(id, "trk", track_target, .{ .duration = motion.normal });
    track_rect.fill(Rect.Physical.all(1000), .{ .color = track_color, .fade = 1.0 });

    // 3) Knob circle, animating fill color between text_muted and surface_0.
    const knob_target = if (on) theme.surface_0 else theme.text_muted;
    const knob_color = anim.color(id, "knb", knob_target, .{ .duration = motion.normal });
    const knob_rect = circleRect(knob_center, knob_radius);
    knob_rect.fill(Rect.Physical.all(1000), .{ .color = knob_color, .fade = 1.0 });
}

/// Build a square physical rect of the given radius centered on `center` — a
/// full-pill corner radius turns it into a circle.
fn circleRect(center: Point.Physical, radius: f32) Rect.Physical {
    return .{ .x = center.x - radius, .y = center.y - radius, .w = radius * 2.0, .h = radius * 2.0 };
}

test {
    _ = @import("switch_tests.zig");
}
