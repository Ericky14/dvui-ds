/// Slider — custom Material 3 slider with an accent thumb + state layer.
///
/// A thin pill track (inactive `surface_3`, active portion in `accent`) with a
/// filled accent thumb that carries an M3 state-layer halo on hover/focus/press
/// and an `surface_0` gap ring. Drag with the mouse, or focus + arrow keys to
/// nudge. The fraction is a `*f32` in 0..1 read+written in place; `draw()`
/// returns true when the value changed this frame.
///
/// Usage:
///   var volume: f32 = 0.4;
///   if (ds.slider(@src(), &volume).draw()) { applyVolume(volume); }
///   _ = ds.slider(@src(), &brightness).size(.lg).expand(.horizontal).draw();
///   _ = ds.slider(@src(), &locked).disabled(true).draw();
const std = @import("std");
const dvui = @import("dvui");
const ds = @import("../ds.zig");
const tokens = @import("../tokens.zig");
const anim = @import("../anim/anim.zig");

const Rect = dvui.Rect;
const Point = dvui.Point;

pub fn slider(src: std.builtin.SourceLocation, fraction: *f32) Slider {
    return .{ .src = src, .fraction = fraction };
}

pub const Slider = struct {
    src: std.builtin.SourceLocation,
    fraction: *f32,
    slider_size: tokens.Size = .md,
    is_disabled: bool = false,
    expand_val: dvui.Options.Expand = .none,
    id_extra: ?usize = null,

    /// Set the control size (sm / md / lg) — controls thumb + track size.
    pub fn size(self: Slider, val: tokens.Size) Slider {
        var copy = self;
        copy.slider_size = val;
        return copy;
    }

    /// Disable interaction and dim the control.
    pub fn disabled(self: Slider, val: bool) Slider {
        var copy = self;
        copy.is_disabled = val;
        return copy;
    }

    /// Set how the slider expands within its parent (default: none → fixed width).
    pub fn expand(self: Slider, val: dvui.Options.Expand) Slider {
        var copy = self;
        copy.expand_val = val;
        return copy;
    }

    /// Disambiguate this instance when sliders share a `@src()` (loops/groups).
    pub fn idExtra(self: Slider, val: usize) Slider {
        var copy = self;
        copy.id_extra = val;
        return copy;
    }

    /// Draw the slider. Returns true if the fraction changed this frame.
    /// When disabled, the control is dimmed and never reports a change.
    pub fn draw(self: Slider) bool {
        const theme = tokens.current;
        const thumb_d = thumbDiameter(self.slider_size);
        const track_h = trackHeight(self.slider_size);
        const ctrl_h = thumb_d * 1.8; // reserve room for the state-layer halo

        var opacity: ?ds.Opacity = null;
        if (self.is_disabled) opacity = ds.withOpacity(theme.opacity_disabled);
        defer if (opacity) |dim| dim.restore();

        var b = dvui.box(self.src, .{ .dir = .horizontal }, .{
            .min_size_content = .{ .w = 160, .h = ctrl_h },
            .expand = self.expand_val,
            .id_extra = self.id_extra,
        });
        defer b.deinit();

        dvui.tabIndexSet(b.data().id, b.data().options.tab_index, b.data().rectScale().r);

        // Track geometry: a thin centered bar inset by half the thumb on each end
        // so the thumb stays inside the control. (Mirrors dvui's native slider.)
        const br = b.data().contentRect();
        // Inset by ~half the state-layer halo (0.9·thumb) so the halo stays inside
        // the control at fraction 0/1; clamp so a too-narrow parent never produces
        // a negative track width.
        const inset = thumb_d * 0.9;
        const track = Rect{ .x = inset, .y = br.h / 2.0 - track_h / 2.0, .w = @max(0, br.w - inset * 2.0), .h = track_h };
        const trackrs = b.widget().screenRectScale(track);
        const rs = b.data().contentRectScale();

        var hovered = false;
        var changed = false;
        if (!self.is_disabled) {
            const id = b.data().id;
            for (dvui.events()) |*e| {
                if (!dvui.eventMatch(e, .{ .id = id, .r = rs.r })) continue;
                switch (e.evt) {
                    .mouse => |me| {
                        var pos: ?Point.Physical = null;
                        if (me.action == .focus) {
                            e.handle(@src(), b.data());
                            dvui.focusWidget(id, null, e.num);
                        } else if (me.action == .press and me.button.pointer()) {
                            dvui.captureMouse(b.data(), e.num);
                            e.handle(@src(), b.data());
                            pos = me.p;
                        } else if (me.action == .release and me.button.pointer()) {
                            dvui.captureMouse(null, e.num);
                            dvui.dragEnd();
                            e.handle(@src(), b.data());
                        } else if (me.action == .motion and dvui.captured(id)) {
                            e.handle(@src(), b.data());
                            pos = me.p;
                        } else if (me.action == .position) {
                            dvui.cursorSet(.hand);
                            hovered = true;
                        }
                        if (pos) |pp| {
                            const min = trackrs.r.x;
                            const max = trackrs.r.x + trackrs.r.w;
                            if (max > min) {
                                self.fraction.* = std.math.clamp((pp.x - min) / (max - min), 0, 1);
                                changed = true;
                            }
                        }
                    },
                    .key => |ke| {
                        if (ke.action == .down or ke.action == .repeat) {
                            switch (ke.code) {
                                .left, .down => {
                                    e.handle(@src(), b.data());
                                    self.fraction.* = @max(0, self.fraction.* - 0.05);
                                    changed = true;
                                },
                                .right, .up => {
                                    e.handle(@src(), b.data());
                                    self.fraction.* = @min(1, self.fraction.* + 0.05);
                                    changed = true;
                                },
                                else => {},
                            }
                        }
                    },
                    else => {},
                }
            }
        }

        if (b.data().visible()) {
            const focused = !self.is_disabled and ds.focusVisible() and b.data().id == dvui.focusedWidgetId();
            const pressed = !self.is_disabled and dvui.captured(b.data().id);
            drawTrackAndThumb(b.data().id, std.math.clamp(self.fraction.*, 0, 1), trackrs, track_h, thumb_d, .{ .hovered = hovered, .pressed = pressed, .focused = focused }, self.is_disabled, theme);
        }

        return changed;
    }
};

fn thumbDiameter(sz: tokens.Size) f32 {
    return switch (sz) {
        .sm => 12,
        .md => 14,
        .lg => 16,
    };
}

fn trackHeight(sz: tokens.Size) f32 {
    return switch (sz) {
        .sm => 4,
        .md => 5,
        .lg => 6,
    };
}

fn drawTrackAndThumb(id: dvui.Id, perc: f32, trackrs: dvui.RectScale, track_h: f32, thumb_d: f32, state: anim.InteractionState, disabled: bool, theme: tokens.Theme) void {
    if (trackrs.r.w <= 0) return; // no room to draw a meaningful track
    const scale = trackrs.s;
    const pill = dvui.CornerRect.Physical.round((track_h / 2.0) * scale);

    // Disabled goes neutral/gray (not just dimmed accent) so it clearly reads as
    // inert; the active track and thumb use a muted fill and the thumb shrinks
    // its surface gap ring.
    const active_color = if (disabled) theme.text_muted else theme.accent;

    // Inactive (full) track, then the active portion on top.
    trackrs.r.fill(pill, .{ .color = .{ .color = if (disabled) theme.surface_2 else theme.surface_3 }, .fade = 1.0 });
    var active = trackrs.r;
    active.w *= perc;
    active.fill(pill, .{ .color = .{ .color = active_color }, .fade = 1.0 });

    // Thumb centered on the track at the current fraction.
    const center: Point.Physical = .{
        .x = trackrs.r.x + trackrs.r.w * perc,
        .y = trackrs.r.y + trackrs.r.h / 2.0,
    };

    // State-layer halo behind the thumb (always transparent when disabled).
    const halo = anim.stateLayer(id, "sl", active_color, state);
    centeredSquare(center, thumb_d * 1.8 * scale).fill(dvui.CornerRect.Physical.round(1000), .{ .color = .{ .color = halo }, .fade = 1.0 });

    // M3 gap ring (surface_0) then the thumb.
    centeredSquare(center, (thumb_d + 4) * scale).fill(dvui.CornerRect.Physical.round(1000), .{ .color = .{ .color = theme.surface_0 }, .fade = 1.0 });
    centeredSquare(center, thumb_d * scale).fill(dvui.CornerRect.Physical.round(1000), .{ .color = .{ .color = active_color }, .fade = 1.0 });
}

fn centeredSquare(center: Point.Physical, side: f32) Rect.Physical {
    return .{ .x = center.x - side / 2.0, .y = center.y - side / 2.0, .w = side, .h = side };
}

test {
    _ = @import("slider_tests.zig");
}
