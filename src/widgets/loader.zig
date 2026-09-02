/// Loader — animated loading spinner for dvui-ds.
///
/// Renders a spinning arc over a track ring using dvui's GPU texture pipeline.
/// The track is a full-circle stroke icon (dimmed), the arc is a 270° stroke
/// that rotates via GPU texture transforms. Pixel-perfect at any size.
///
/// Usage:
///   ds.loader(@src()).draw();
///   ds.loader(@src()).size(.sm).style(.accent).draw();
const std = @import("std");
const dvui = @import("dvui");
const ds = @import("../ds.zig");
const tokens = @import("../tokens.zig");

const render = dvui.render;
const Color = dvui.Color;

pub const LoaderStyle = enum {
    /// Uses text color matching button label
    primary,
    /// Uses accent color
    accent,
    /// Inherits from parent options
    inherit,
};

pub fn loader(src: std.builtin.SourceLocation) Loader {
    return .{ .src = src };
}

/// Track ring SVG — full circle stroke, used as the dim background ring.
const track_svg =
    \\<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
    \\<circle cx="12" cy="12" r="9"/>
    \\</svg>
;

/// Arc SVG — ~90° arc stroke (top quarter), matching CSS border-t-accent spinner.
const arc_svg =
    \\<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
    \\<path d="M12 3 A9 9 0 0 1 21 12"/>
    \\</svg>
;

pub const Loader = struct {
    src: std.builtin.SourceLocation,
    loader_size: tokens.Size = .md,
    loader_style: LoaderStyle = .primary,
    explicit_color: ?Color = null,

    pub fn size(self: Loader, val: tokens.Size) Loader {
        var l = self;
        l.loader_size = val;
        return l;
    }

    pub fn style(self: Loader, val: LoaderStyle) Loader {
        var l = self;
        l.loader_style = val;
        return l;
    }

    pub fn color(self: Loader, val: Color) Loader {
        var l = self;
        l.explicit_color = val;
        return l;
    }

    pub fn draw(self: Loader) void {
        const theme = tokens.current;
        const sz = spinnerSize(self.loader_size);
        const arc_color = self.explicit_color orelse switch (self.loader_style) {
            .primary => theme.text_primary,
            .accent => theme.accent,
            .inherit => theme.text_secondary,
        };
        // Track: same color at 20% opacity (border-accent/20)
        const track_color = Color{ .r = arc_color.r, .g = arc_color.g, .b = arc_color.b, .a = arc_color.a / tokens.current.opacity_track };

        // Get or create cached TVG bytes for track and arc
        const wid = dvui.parentGet().extendId(self.src, 0);
        const track_tvg = ds.cachedTvg(wid, "_trk", track_svg) orelse return;
        const arc_tvg = ds.cachedTvg(wid, "_arc", arc_svg) orelse return;

        // Continuous spinning animation (0.7s per rotation, seamless looping)
        var t: f32 = 0;
        const anim = dvui.Animation{ .end_time = tokens.current.spinner_duration };
        if (dvui.animationGet(wid, "_spin")) |a| {
            var aa = a;
            if (aa.done()) {
                aa = anim;
                aa.start_time = a.end_time;
                aa.end_time += a.end_time;
                dvui.animation(wid, "_spin", aa);
            }
            t = aa.value();
        } else {
            dvui.animation(wid, "_spin", anim);
        }

        const rotation = 2.0 * std.math.pi * t;

        // Use IconWidget for the arc — it properly participates in parent layout
        var iw: dvui.IconWidget = undefined;
        iw.init(self.src, "_ds_loader_arc", arc_tvg, .{
            .stroke_color = .{ .color = arc_color },
            .fill_color = .transparent,
        }, .{
            .min_size_content = .{ .w = sz, .h = sz },
            .rotation = rotation,
            .gravity_y = 0.5,
        });

        // Render track ring at the same rect as the arc (behind it)
        const rs = iw.data().parent.screenRectScale(iw.data().contentRect());
        render.renderIcon("_ds_loader_track", track_tvg, rs, .{}, .{
            .stroke_color = .{ .color = track_color },
            .fill_color = .transparent,
        }) catch {};

        // Draw rotating arc on top
        iw.draw();
        iw.deinit();
    }
};

fn spinnerSize(sz: tokens.Size) f32 {
    const theme = tokens.current;
    return switch (sz) {
        .sm => theme.spinner_sm,
        .md => theme.spinner_md,
        .lg => theme.spinner_lg,
    };
}
