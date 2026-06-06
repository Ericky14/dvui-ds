/// ScrollArea — vertical scroll container with a Chrome/macOS-style overlay
/// scrollbar.
///
/// The scrollbar overlays the content (it never takes layout width), is colored
/// from the theme, and only appears on interaction: it fades in when you hover
/// or scroll the area and fades back out when idle.
///
/// Usage:
///   var sc = ds.scrollArea(@src()).draw();
///   defer sc.deinit();
///   // ... tall content; it scrolls vertically ...
const std = @import("std");
const dvui = @import("dvui");
const ds = @import("../ds.zig");
const tokens = @import("../tokens.zig");
const anim = @import("../anim/anim.zig");
const motion = @import("../motion.zig");

pub fn scrollArea(src: std.builtin.SourceLocation) ScrollArea {
    return .{ .src = src };
}

pub const ScrollArea = struct {
    src: std.builtin.SourceLocation,
    expand_val: dvui.Options.Expand = .both,
    id_extra: ?usize = null,

    /// Set how the scroll area expands within its parent (default `.both`).
    pub fn expand(self: ScrollArea, val: dvui.Options.Expand) ScrollArea {
        var copy = self;
        copy.expand_val = val;
        return copy;
    }

    /// Disambiguate instances built from the same `@src()` (loops / groups).
    pub fn idExtra(self: ScrollArea, val: usize) ScrollArea {
        var copy = self;
        copy.id_extra = val;
        return copy;
    }

    /// Materialize the scroll container. Put content inside, then `deinit()`.
    pub fn draw(self: ScrollArea) Handle {
        const theme = tokens.current;

        // Stable id (independent of the inner widget) for the fade state, known
        // before the scroll area is created so we can set its bar color.
        const id: dvui.Id = @enumFromInt(@as(usize, self.src.line) +% (@as(usize, self.src.column) *% 65599) +% (self.id_extra orelse 0));

        // Fade the bar toward visible while the area was interacted with last
        // frame; fast in, slow out (a gentle Chrome/macOS-style disappearance).
        const active_prev = dvui.dataGet(null, id, "_active", bool) orelse false;
        const target: f32 = if (active_prev) 1.0 else 0.0;
        const visible = anim.float(id, "bar", target, .{ .duration = if (active_prev) motion.fast else motion.slower });
        const bar_alpha: u8 = @intFromFloat(std.math.clamp(visible, 0, 1) * 255.0);

        // dvui colors the overlay grab as color(.text).opacity(0.5); since
        // `opacity` multiplies alpha, animating the text color's alpha fades the
        // bar. `.auto_overlay` floats the grab over content (no reserved width).
        const sa = dvui.scrollArea(self.src, .{
            .vertical_bar = .auto_overlay,
            .horizontal_bar = .hide,
        }, .{
            .expand = self.expand_val,
            .id_extra = self.id_extra,
            .background = false,
            .color_text = ds.alpha(theme.text_secondary, bar_alpha),
        });

        return .{ .sa = sa, .id = id };
    }
};

/// Live scroll-container handle. Put content inside, then `deinit()`.
pub const Handle = struct {
    sa: *dvui.ScrollAreaWidget,
    id: dvui.Id,

    pub fn deinit(self: Handle) void {
        // Record whether the area was interacted with this frame (hover, or the
        // scroll offset moved) so next frame's bar fades in/out accordingly.
        const rect = self.sa.data().rectScale().r;
        var active = false;
        for (dvui.events()) |*e| {
            if (e.evt == .mouse and e.evt.mouse.action == .position and rect.contains(e.evt.mouse.p)) {
                active = true;
            }
        }
        const vp_y = self.sa.si.viewport.y;
        const prev_y = dvui.dataGet(null, self.id, "_vpy", f32) orelse vp_y;
        if (@abs(vp_y - prev_y) > 0.01) active = true;
        dvui.dataSet(null, self.id, "_vpy", vp_y);
        dvui.dataSet(null, self.id, "_active", active);

        self.sa.deinit();
    }
};

test {
    _ = @import("scroll_area_tests.zig");
}
