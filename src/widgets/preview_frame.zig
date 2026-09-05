/// PreviewFrame — the frame around a picture (a 3-D viewport, a render, a
/// screenshot).
///
/// A raw render butted straight against the chrome looks like a hole in the
/// app. The frame fixes that with four things, in this order: a gutter so the
/// picture is inset from the pane, a rounded corner so it belongs to the same
/// family as the panels around it, an inner vignette so a bright render stops
/// bleeding into the chrome, and a hairline *over* the picture's edge so the
/// boundary is a deliberate line rather than wherever the render happens to
/// end.
///
/// The vignette and the hairline are drawn by `deinit()`, i.e. over whatever
/// the caller put inside — so draw the picture inside the frame, and float
/// overlays (a glass toolbar, a row of status pills) with `ds.glass`, which
/// renders in its own subwindow above it. `toolbarRect` / `statusRect` hand you
/// the rects to float them in.
///
/// Usage:
///   var preview = ds.previewFrame(@src()).draw();
///   defer preview.deinit();
///   drawViewportTexture(preview.corners());        // the picture
///   var bar = ds.glass(@src()).rect(preview.toolbarRect(360, 40)).behind();
///   // …
const std = @import("std");
const dvui = @import("dvui");
const ds = @import("../ds.zig");
const tokens = @import("../tokens.zig");
const pixels = @import("../helpers/pixels.zig");

pub fn previewFrame(src: std.builtin.SourceLocation) PreviewFrame {
    return .{ .src = src };
}

pub const PreviewFrame = struct {
    src: std.builtin.SourceLocation,
    radius_val: ?f32 = null,
    inset_val: ?f32 = null,
    vignette_val: ?u8 = null,
    tag_val: ?[]const u8 = null,

    /// Corner radius of the picture (default `theme.preview_radius`).
    pub fn radius(self: PreviewFrame, logical_px: f32) PreviewFrame {
        var copy = self;
        copy.radius_val = logical_px;
        return copy;
    }

    /// Gutter between the pane and the picture (default `theme.preview_inset`).
    pub fn inset(self: PreviewFrame, logical_px: f32) PreviewFrame {
        var copy = self;
        copy.inset_val = logical_px;
        return copy;
    }

    /// Strength of the inner vignette, 0 = off (default
    /// `theme.preview_vignette_alpha`).
    pub fn vignette(self: PreviewFrame, alpha: u8) PreviewFrame {
        var copy = self;
        copy.vignette_val = alpha;
        return copy;
    }

    /// Name this frame for tests and UI automation (`dvui.tagGet`).
    pub fn tag(self: PreviewFrame, name: []const u8) PreviewFrame {
        var copy = self;
        copy.tag_val = name;
        return copy;
    }

    /// Draw the gutter and open the picture area. `deinit()` the handle when
    /// the picture is drawn — that is when the vignette and hairline land.
    pub fn draw(self: PreviewFrame) Handle {
        const theme = tokens.current;
        const scale = pixels.pixelScale();
        const corner = self.radius_val orelse theme.preview_radius;
        const gutter = pixels.snapPx(self.inset_val orelse theme.preview_inset, scale);

        const outer = dvui.box(self.src, .{}, .{
            .expand = .both,
            .background = true,
            .color_fill = .{ .color = theme.surface_0 },
            .padding = dvui.Rect.all(gutter),
        });

        const picture = dvui.box(@src(), .{}, .{
            .expand = .both,
            .tag = self.tag_val,
        });

        return .{
            .outer = outer,
            .picture = picture,
            .corner = corner,
            .scale = scale,
            .vignette_alpha = self.vignette_val orelse theme.preview_vignette_alpha,
            .bounds = dvui.windowRectScale().rectFromPhysical(picture.data().rectScale().r),
        };
    }
};

/// Which side of the picture a docked panel occupies. See `Handle.reserve`.
pub const Edge = enum { left, right, top, bottom };

/// A live preview frame. Draw the picture into it, then `deinit()`.
pub const Handle = struct {
    outer: *dvui.BoxWidget,
    picture: *dvui.BoxWidget,
    corner: f32,
    scale: f32,
    vignette_alpha: u8,
    /// The picture area in logical window coordinates — the coordinate space
    /// `ds.glass().rect()` and `dvui.FloatingWidget` want.
    bounds: dvui.Rect,

    /// The corner rounding the picture must draw itself with, so its own edge
    /// matches the frame's. dvui cannot clip to a rounded rect, so the picture
    /// carries the radius rather than being cut to it.
    pub fn corners(self: Handle) dvui.CornerRect {
        return dvui.CornerRect.round(self.corner);
    }

    /// A copy of this handle whose slots are laid out in the picture area minus
    /// `logical_px` along `edge`. Use it when a drawer or panel is docked over
    /// the picture: the floating toolbar should centre on what is still
    /// visible, not on the part hidden behind the drawer.
    ///
    ///   const free = preview.reserve(.right, drawer_width);
    ///   const bar = free.toolbarRect(360, 40);
    pub fn reserve(self: Handle, edge: Edge, logical_px: f32) Handle {
        var copy = self;
        const amount = @max(0, logical_px);
        switch (edge) {
            .left => {
                copy.bounds.x += @min(amount, self.bounds.w);
                copy.bounds.w = @max(0, self.bounds.w - amount);
            },
            .right => copy.bounds.w = @max(0, self.bounds.w - amount),
            .top => {
                copy.bounds.y += @min(amount, self.bounds.h);
                copy.bounds.h = @max(0, self.bounds.h - amount);
            },
            .bottom => copy.bounds.h = @max(0, self.bounds.h - amount),
        }
        return copy;
    }

    /// Rect for a floating toolbar hugging the top edge: `width` × `height`,
    /// horizontally centred, inset from the picture edge by one gutter.
    pub fn toolbarRect(self: Handle, width: f32, height: f32) dvui.Rect {
        const margin = pixels.snapPx(tokens.current.space_md, self.scale);
        return .{
            .x = pixels.snapPx(self.bounds.x + (self.bounds.w - width) / 2, self.scale),
            .y = pixels.snapPx(self.bounds.y + margin, self.scale),
            .w = width,
            .h = height,
        };
    }

    /// Rect for a floating status row hugging the bottom edge.
    pub fn statusRect(self: Handle, width: f32, height: f32) dvui.Rect {
        const margin = pixels.snapPx(tokens.current.space_md, self.scale);
        return .{
            .x = pixels.snapPx(self.bounds.x + (self.bounds.w - width) / 2, self.scale),
            .y = pixels.snapPx(self.bounds.y + self.bounds.h - margin - height, self.scale),
            .w = width,
            .h = height,
        };
    }

    pub fn deinit(self: Handle) void {
        const rs = self.picture.data().rectScale();
        drawVignette(rs.r, self.corner * self.scale, self.vignette_alpha);
        drawEdgeHairline(rs.r, self.corner * self.scale, self.scale);
        self.picture.deinit();
        self.outer.deinit();
    }
};

/// Inner vignette: a radial gradient that is fully transparent through the
/// middle of the picture and darkens towards the corners. One fill, so it costs
/// nothing next to the render underneath it.
fn drawVignette(area: dvui.Rect.Physical, corner_px: f32, alpha: u8) void {
    if (alpha == 0 or area.w < 2 or area.h < 2) return;
    const theme = tokens.current;
    const stops = [_]dvui.Gradient.Stop{
        .{ .color = ds.alpha(theme.shadow_color, 0), .offset = theme.preview_vignette_start },
        .{ .color = ds.alpha(theme.shadow_color, alpha), .offset = 1.0 },
    };
    area.fill(.round(corner_px), .{
        .color = .{ .gradient = .{ .radial = .{ .stops = &stops, .extent = .farthest_corner } } },
        .fade = 1,
    });
}

/// The hairline *over* the picture's edge — drawn last so the boundary is the
/// frame's line, not whatever pixel the render ended on.
fn drawEdgeHairline(area: dvui.Rect.Physical, corner_px: f32, scale: f32) void {
    const thickness = @max(1, @round(scale));
    const inset = thickness / 2;
    const edge: dvui.Rect.Physical = .{
        .x = area.x + inset,
        .y = area.y + inset,
        .w = @max(0, area.w - thickness),
        .h = @max(0, area.h - thickness),
    };
    edge.stroke(.round(@max(0, corner_px - inset)), .{
        .thickness = thickness,
        .color = .{ .color = ds.alpha(.white, tokens.current.preview_hairline_alpha) },
        .closed = true,
        .fade = 1,
    });
}

test {
    _ = @import("preview_frame_tests.zig");
}
