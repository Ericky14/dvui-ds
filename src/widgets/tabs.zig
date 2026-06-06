/// Tabs — Material 3 tab row with an animated sliding underline.
///
/// Custom-drawn (not `dvui.TabsWidget`) so the active-tab indicator slides and
/// stretches smoothly between tabs. Each tab gets an M3 state layer on
/// hover/focus/press; the active label is drawn in the accent color while the
/// rest stay secondary. `draw()` returns true on the frame the active index
/// changes.
///
/// Usage:
///   var active: usize = 0;
///   const labels = [_][]const u8{ "Design", "Code", "Preview" };
///   if (ds.tabs(@src(), &active, &labels).draw()) { ... }
///   _ = ds.tabs(@src(), &active, &labels).idExtra(group_index).draw();
const std = @import("std");
const dvui = @import("dvui");
const ds = @import("../ds.zig");
const tokens = @import("../tokens.zig");
const anim = @import("../anim/anim.zig");
const motion = @import("../motion.zig");
const ds_focus = @import("ds_focus");

const Rect = dvui.Rect;

pub fn tabs(src: std.builtin.SourceLocation, active: *usize, labels: []const []const u8) Tabs {
    return .{ .src = src, .active = active, .labels = labels };
}

pub const Tabs = struct {
    src: std.builtin.SourceLocation,
    active: *usize,
    labels: []const []const u8,
    id_extra: ?usize = null,

    /// Disambiguate this instance when several tab rows share a call site
    /// (e.g. rendered inside a loop). Forwarded to the root widget's id_extra.
    pub fn idExtra(self: Tabs, val: usize) Tabs {
        var copy = self;
        copy.id_extra = val;
        return copy;
    }

    /// Draw the tab row + sliding indicator. Returns true if the active index
    /// changed this frame.
    pub fn draw(self: Tabs) bool {
        const theme = tokens.current;

        var changed = false;
        var active_x: f32 = 0;
        var active_w: f32 = 0;
        var active_y: f32 = 0;
        var active_h: f32 = 0;
        var active_scale: f32 = 1;
        var have_active_rect = false;
        var root_id: dvui.Id = undefined;
        var row_x: f32 = 0;

        {
            var row = dvui.box(self.src, .{ .dir = .horizontal, .gap = theme.space_2xs }, .{
                .id_extra = self.id_extra,
            });
            defer row.deinit();
            root_id = row.data().id;
            row_x = row.data().rectScale().r.x;

            for (self.labels, 0..) |text, index| {
                var tab = dvui.box(@src(), .{ .dir = .horizontal }, .{
                    .id_extra = index,
                    .padding = ds.paddingXY(theme.space_md, theme.space_sm),
                    .corner_radius = Rect.all(theme.radius_sm),
                });
                defer tab.deinit();

                dvui.tabIndexSet(tab.data().id, tab.data().options.tab_index, tab.data().rectScale().r);

                var hovered = false;
                if (dvui.clicked(tab.data(), .{ .hovered = &hovered })) {
                    if (index != self.active.*) {
                        self.active.* = index;
                        changed = true;
                    }
                }
                const focused = ds_focus.visible() and tab.data().id == dvui.focusedWidgetId();
                const pressed = dvui.captured(tab.data().id);

                const is_active = index == self.active.*;

                // M3 state layer over the tab's rounded rect — accent ink for the
                // active tab, neutral for the rest.
                if (tab.data().visible()) {
                    const rect_scale = tab.data().rectScale();
                    const ink = if (is_active) theme.accent else theme.text_primary;
                    const layer = anim.stateLayer(tab.data().id, "sl", ink, .{
                        .hovered = hovered,
                        .pressed = pressed,
                        .focused = focused,
                    });
                    rect_scale.r.fill(Rect.Physical.all(theme.radius_sm * rect_scale.s), .{ .color = layer, .fade = 1.0 });
                }

                const label_color = if (is_active) theme.accent else theme.text_secondary;
                dvui.labelNoFmt(@src(), text, .{}, .{
                    .color_text = label_color,
                    .font = ds.fontMedium(theme.font_size_md),
                    .gravity_y = 0.5,
                });

                if (is_active and tab.data().visible()) {
                    const rect_scale = tab.data().rectScale();
                    active_x = rect_scale.r.x;
                    active_y = rect_scale.r.y;
                    active_w = rect_scale.r.w;
                    active_h = rect_scale.r.h;
                    active_scale = rect_scale.s;
                    have_active_rect = true;
                }
            }
        }

        // Sliding underline indicator. Animate the X position RELATIVE to the row
        // origin (not absolute screen coords) so scrolling / moving / resizing the
        // container doesn't make the indicator chase a moving target; the row's
        // current origin is added back at draw time. Guard the first frame where
        // layout hasn't produced a measured rect yet.
        if (have_active_rect and active_w > 0) {
            const rel_x = active_x - row_x;
            const indicator_rel_x = anim.float(root_id, "ix", rel_x, .{ .duration = motion.normal, .easing = motion.inOut });
            const indicator_w = anim.float(root_id, "iw", active_w, .{ .duration = motion.normal, .easing = motion.inOut });
            const thickness = 3 * active_scale;
            const indicator: Rect.Physical = .{
                .x = row_x + indicator_rel_x,
                .y = active_y + active_h - thickness,
                .w = indicator_w,
                .h = thickness,
            };
            indicator.fill(Rect.Physical.all(1.5 * active_scale), .{ .color = theme.accent, .fade = 1.0 });
        }

        return changed;
    }
};

test {
    _ = @import("tabs_tests.zig");
}
