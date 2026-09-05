/// Glass — a translucent surface floating over a blurred copy of what is
/// behind it (CSS `backdrop-filter: blur()`).
///
/// A backdrop has to be *captured before the surface is drawn*, so glass is a
/// two-part bracket rather than one call: `.behind()` opens the capture, the
/// caller draws the content that should show through, and `.draw()` closes the
/// capture and paints the surface. Everything else — the tint, the hairline,
/// the top edge highlight, the fallback when there is no blur — is one call.
///
/// Usage — one panel over a live 3-D preview:
///   var drawer = ds.glass(@src())
///       .rect(drawer_rect)
///       .witness(preview_frame_counter) // re-blurs only when this changes
///       .radius(ds.tokens.current.radius_lg)
///       .behind();
///   drawPreview();                      // whatever shows through the glass
///   var surface = drawer.draw();
///   defer surface.deinit();
///   ds.label(@src(), "Inspect").style(.title).draw();
///
/// Usage — several panels over the *same* content (a floating toolbar, a status
/// row and a drawer all over one viewport). Capture the scene once with
/// `ds.glassScene` and let each panel sample its own patch of it: one blur per
/// frame instead of three, and no ordering rule between the panels.
///   var scene = ds.glassScene(@src()).rect(viewport).witness(frame_no).begin();
///   drawPreview();                       // the content behind the glass
///   var bar = ds.glass(@src()).rect(bar_rect).scene(scene).draw();
///   bar.deinit();
///   var drawer = ds.glass(@src()).rect(drawer_rect).scene(scene).draw();
///   drawer.deinit();
///   scene.end();                         // after the panels — see below
///
/// ⚠ The panels go **inside** the bracket. An open bracket is what makes dvui
/// defer the background's drawing, and only draws made while it is open land in
/// their own subwindow queue and therefore *above* that background. Close the
/// scene first and the panels are painted straight onto the target, then the
/// deferred background replays over them and they disappear — no error, just
/// nothing. Anything else that overlaps the captured area (a vignette, a frame
/// hairline) belongs inside the bracket too, and is then part of what gets
/// blurred.
///
/// Usage — an inline frosted surface (no `.rect()`, so no blur, just the glass
/// tint + hairline + highlight; right for a composer or a card that sits on an
/// opaque column, where a blur would have nothing to reveal):
///   var composer = ds.glass(@src()).expand(.horizontal).draw();
///   defer composer.deinit();
///
/// Performance: the blurred capture is cached and only redone when `rect` or
/// `witness` changes. Over a *live* view that means the caller passes the
/// view's frame counter while it is playing and a constant while it is paused —
/// pass a constant and the glass keeps showing the last frame it captured.
const std = @import("std");
const dvui = @import("dvui");
const ds = @import("../ds.zig");
const tokens = @import("../tokens.zig");
const pixels = @import("../helpers/pixels.zig");

/// Start a glass surface. See the file doc comment for the bracket.
pub fn glass(src: std.builtin.SourceLocation) Glass {
    return .{ .src = src };
}

/// Capture one blurred backdrop that several glass panels can share.
pub fn glassScene(src: std.builtin.SourceLocation) GlassScene {
    return .{ .src = src };
}

pub const GlassScene = struct {
    src: std.builtin.SourceLocation,
    area: ?dvui.Rect = null,
    witness_val: u64 = 0,
    blur_val: ?f32 = null,

    /// The region to capture, in logical window coordinates — usually the whole
    /// viewport the panels float over.
    pub fn rect(self: GlassScene, value: dvui.Rect) GlassScene {
        var copy = self;
        copy.area = value;
        return copy;
    }

    /// See `Glass.witness`.
    pub fn witness(self: GlassScene, value: u64) GlassScene {
        var copy = self;
        copy.witness_val = value;
        return copy;
    }

    /// Blur radius in logical px (default `theme.glass_blur`).
    pub fn blur(self: GlassScene, logical_px: f32) GlassScene {
        var copy = self;
        copy.blur_val = logical_px;
        return copy;
    }

    /// Open the capture. Draw the content that shows through, then the glass
    /// panels, then `end()`.
    pub fn begin(self: GlassScene) Scene {
        const area = self.area orelse return .{ .backdrop = null };
        const capture = dvui.BlurBackdrop.get(self.src);
        capture.radius_px = (self.blur_val orelse tokens.current.glass_blur) * pixels.pixelScale();
        capture.init(area, .{ self.witness_val, capture.radius_px });
        return .{ .backdrop = capture };
    }
};

/// A capture in progress. Hand it to every panel with
/// `ds.glass(...).scene(scene)`, then `end()` it once those panels are drawn —
/// see the ⚠ in this file's doc comment for why that order and not the obvious
/// one.
pub const Scene = struct {
    backdrop: ?*dvui.BlurBackdrop,

    pub fn end(self: Scene) void {
        const capture = self.backdrop orelse return;
        capture.deinit();
        // The first frame of any laid-out content draws nothing (min sizes are
        // still unknown), so the capture legitimately comes back empty and
        // stays dirty. Ask for another frame, or a UI that would otherwise
        // settle right now would settle with no glass on it.
        if (capture.small == null) dvui.refresh(null, @src(), null);
    }
};

pub const Glass = struct {
    src: std.builtin.SourceLocation,
    panel_rect: ?dvui.Rect = null,
    witness_val: u64 = 0,
    blur_val: ?f32 = null,
    radius_val: ?f32 = null,
    is_solid: bool = false,
    pad_override: ?dvui.Rect = null,
    dir: dvui.enums.Direction = .vertical,
    gap_val: f32 = 0,
    expand_override: ?dvui.Options.Expand = null,
    tag_val: ?[]const u8 = null,
    id_extra: usize = 0,
    /// Set by `behind()` or `scene()`; null means "no blur" (inline,
    /// `.solid()`, or the caller never opened a bracket).
    backdrop: ?*dvui.BlurBackdrop = null,
    /// True only when this panel opened the capture itself, and so must close
    /// it. A shared `Scene` is closed by its own `end()`.
    owns_backdrop: bool = false,

    /// Place the surface, in logical window coordinates. A glass panel with a
    /// rect floats in its own subwindow *over* the content it blurs — which is
    /// what makes the ordering work at all — so overlays (drawers, sheets,
    /// floating toolbars) give a rect and inline surfaces do not.
    ///
    /// The rect is **rounded to whole physical pixels** before it is used. A
    /// sheet's rect is rarely a round number — it comes from a pane split, a
    /// percentage, a `previewFrame.reserve` — and a panel that keeps that
    /// fraction hands it to everything inside it: every row in a list then
    /// starts on a half pixel, and no amount of snapping the list or the rows
    /// can move them. The panel is the boundary where that gets rounded, the
    /// same way `ds.padding` rounds an inset.
    pub fn rect(self: Glass, value: dvui.Rect) Glass {
        var copy = self;
        copy.panel_rect = value;
        return copy;
    }

    /// Anything that should invalidate the cached blur when it changes: a
    /// frame counter while a preview is playing, a scroll offset, a revision
    /// number. Cheap to pass every frame; the blur only redoes work when the
    /// value actually differs from last frame's.
    pub fn witness(self: Glass, value: u64) Glass {
        var copy = self;
        copy.witness_val = value;
        return copy;
    }

    /// Blur radius in logical px (default `theme.glass_blur`).
    pub fn blur(self: Glass, logical_px: f32) Glass {
        var copy = self;
        copy.blur_val = logical_px;
        return copy;
    }

    /// Corner radius (default `theme.radius_lg`).
    pub fn radius(self: Glass, logical_px: f32) Glass {
        var copy = self;
        copy.radius_val = logical_px;
        return copy;
    }

    /// Skip the blur and paint a near-opaque surface instead — for a backend
    /// with no render targets, or a user who prefers reduced transparency.
    /// (`opaque` is a Zig keyword, hence `solid`.)
    ///
    /// Honoured whether this panel captures its own backdrop or samples a
    /// shared `ds.glassScene`: a reduced-transparency setting is the user's,
    /// and it cannot depend on which of the two the caller happened to use.
    pub fn solid(self: Glass, value: bool) Glass {
        var copy = self;
        copy.is_solid = value;
        return copy;
    }

    /// Lay children out horizontally instead of vertically.
    pub fn horizontal(self: Glass) Glass {
        var copy = self;
        copy.dir = .horizontal;
        return copy;
    }

    /// Gap between children (px).
    pub fn gap(self: Glass, logical_px: f32) Glass {
        var copy = self;
        copy.gap_val = logical_px;
        return copy;
    }

    /// Override the inner padding (default `theme.space_md`). Snapped to whole
    /// physical pixels like every other ds inset — a glass panel's padding
    /// positions everything inside it, and an unsnapped one puts the whole
    /// content box on a half pixel at 175 %.
    pub fn padding(self: Glass, logical_px: f32) Glass {
        var copy = self;
        copy.pad_override = ds.padding(logical_px);
        return copy;
    }

    /// Expand to fill the parent — only meaningful for an inline surface.
    pub fn expand(self: Glass, value: dvui.Options.Expand) Glass {
        var copy = self;
        copy.expand_override = value;
        return copy;
    }

    /// Name this surface for tests and UI automation (`dvui.tagGet`).
    pub fn tag(self: Glass, name: []const u8) Glass {
        var copy = self;
        copy.tag_val = name;
        return copy;
    }

    /// Disambiguate instances built from the same `@src()`.
    pub fn idExtra(self: Glass, value: usize) Glass {
        var copy = self;
        copy.id_extra = value;
        return copy;
    }

    /// Sample a backdrop captured by `ds.glassScene`, instead of capturing one
    /// of this panel's own. Prefer this whenever more than one panel floats
    /// over the same content.
    pub fn scene(self: Glass, value: Scene) Glass {
        var copy = self;
        copy.backdrop = value.backdrop;
        copy.owns_backdrop = false;
        return copy;
    }

    /// Open a backdrop capture just for this panel. Call this, then draw
    /// whatever should show through the glass, then `draw()`. A no-op for an
    /// inline or `.solid()` surface, so it is always safe to call.
    ///
    /// One panel per bracket: two overlapping `behind()` captures have to be
    /// closed in the exact reverse of the order they were opened, or the second
    /// panel is painted over by the background it was supposed to blur.
    /// `ds.glassScene` exists so that rule never has to be remembered.
    pub fn behind(self: Glass) Glass {
        var copy = self;
        const panel = self.panel_rect orelse return copy;
        if (self.is_solid) return copy;

        const scale = pixels.pixelScale();
        const capture = dvui.BlurBackdrop.get(self.src);
        // `radius_px` is measured in physical pixels, so a CSS-style logical
        // radius has to be scaled or the blur weakens as the display gets
        // denser — the opposite of what a 24 px design token means.
        capture.radius_px = (self.blur_val orelse tokens.current.glass_blur) * scale;
        // The *same* snapped rect the panel will use, or the blur is captured
        // from one rectangle and drawn into another a fraction of a pixel away.
        capture.init(snapRect(panel, scale), .{ self.witness_val, capture.radius_px });
        copy.backdrop = capture;
        copy.owns_backdrop = true;
        return copy;
    }

    /// Close the capture and paint the surface. Returns a handle to put content
    /// in; `deinit()` it when done.
    pub fn draw(self: Glass) Handle {
        const theme = tokens.current;
        const scale = pixels.pixelScale();
        const corner = self.radius_val orelse theme.radius_lg;
        const corners = dvui.CornerRect.round(corner);
        // A glass edge is decoration, not structure: exactly one physical
        // pixel at every scale. Rounded up (`hairline`) it is 2 px at 1.75,
        // which over a dark scene doubles the ink and turns the panel's edge
        // from a hint into a ring — measured on a black backdrop, where every
        // white alpha reads at full contrast.
        const line = pixels.thinLine(scale);

        // The blur only counts as live once a capture actually exists: the
        // first frames of any panel, and every frame on a backend without
        // render targets, have nothing to show through, and a 55 %-alpha panel
        // over raw scene content is unreadable. Fall back to near-opaque.
        // `.solid` is checked here, not only in `behind()`. A panel that samples
        // a *shared* `ds.glassScene` never calls `behind()`, so deciding purely
        // from "is there a capture" made `.solid(true)` a no-op on exactly the
        // page that has a reduced-transparency switch — the scene had a capture,
        // so the panel drew it whatever the caller asked for.
        const blur_live = !self.is_solid and
            if (self.backdrop) |capture| capture.small != null else false;
        // Same reason as `Scene.end`: keep the frames coming until there is a
        // capture to show, then stop.
        if (!self.is_solid and self.backdrop != null and !blur_live) dvui.refresh(null, @src(), null);
        const tint = theme.glass_tint orelse theme.surface_1;
        const fill = ds.alpha(tint, if (blur_live) theme.glass_alpha else theme.glass_alpha_opaque);

        var floater: ?*dvui.FloatingWidget = null;
        if (self.panel_rect) |requested| {
            const panel = snapRect(requested, scale);
            const window = dvui.widgetAlloc(dvui.FloatingWidget);
            window.init(self.src, .{}, .{ .rect = panel, .id_extra = self.id_extra });
            floater = window;

            // Draw the cached blur ourselves rather than via `BlurBackdrop.draw`,
            // which paints a square quad — a square blur under a rounded panel
            // leaves four grey ears at the corners.
            if (if (self.is_solid) null else self.backdrop) |capture| {
                if (capture.small) |texture| {
                    // `uv_rect` is the capture's own extent, so a panel that
                    // covers part of a shared scene samples exactly the patch of
                    // blur that sits under it.
                    dvui.renderTexture(
                        texture,
                        .{ .r = dvui.windowRectScale().rectToPhysical(panel), .s = scale },
                        .{ .corners = corners, .uv_rect = capture.rect, .fade = 1 },
                    ) catch {};
                }
            }
        }

        const surface_opts: dvui.Options = .{
            .background = true,
            .color_fill = .{ .color = fill },
            .corners = corners,
            .border = dvui.Rect.all(line),
            .color_border = .{ .color = ds.alpha(.white, theme.glass_border_alpha) },
            .padding = self.pad_override orelse dvui.Rect.all(pixels.snapPx(theme.space_md, scale)),
            .expand = if (floater != null) .both else self.expand_override,
            .tag = self.tag_val,
        };

        const box = if (floater != null)
            dvui.box(@src(), .{ .dir = self.dir, .gap = self.gap_val }, surface_opts)
        else
            dvui.box(self.src, .{ .dir = self.dir, .gap = self.gap_val }, surface_opts.override(.{ .id_extra = self.id_extra }));

        drawEdgeHighlight(box, corner, scale, theme.glass_edge_alpha);

        return .{
            .box = box,
            .floater = floater,
            .backdrop = if (self.owns_backdrop and !self.is_solid) self.backdrop else null,
        };
    }
};

/// A live glass surface: put content in it, then `deinit()`.
pub const Handle = struct {
    box: *dvui.BoxWidget,
    floater: ?*dvui.FloatingWidget,
    /// Only set when this panel owns its capture; a shared `Scene` closes its own.
    backdrop: ?*dvui.BlurBackdrop,

    /// The surface's widget data — its rect, id, tag.
    pub fn data(self: Handle) *dvui.WidgetData {
        return self.box.data();
    }

    pub fn deinit(self: Handle) void {
        self.box.deinit();
        if (self.floater) |window| window.deinit();
        // Last, and only for a capture this panel owns: the capture reads the
        // command queue of the subwindow *below* the panel, so it has to close
        // after the panel's own subwindow does.
        if (self.backdrop) |capture| capture.deinit();
    }
};

/// A panel rect rounded so all four of its edges land on whole physical pixels.
///
/// Width and height are rounded from the *far* edge rather than on their own,
/// so the right and bottom edges are whole too — rounding a fractional origin
/// and a fractional size independently can still leave the far edge on a half
/// pixel.
fn snapRect(rect: dvui.Rect, scale: f32) dvui.Rect {
    const left = pixels.snapPx(rect.x, scale);
    const top = pixels.snapPx(rect.y, scale);
    return .{
        .x = left,
        .y = top,
        .w = @max(0, pixels.snapPx(rect.x + rect.w, scale) - left),
        .h = @max(0, pixels.snapPx(rect.y + rect.h, scale) - top),
    };
}

/// The 1 px specular line along the top inside edge — the layer that makes a
/// translucent panel read as glass instead of as a weak fill. Drawn as a
/// stroke of the surface's own rounded rect under a top-to-transparent
/// gradient, so it follows the corner curve and dies away down the sides
/// exactly like a real highlight.
fn drawEdgeHighlight(box: *dvui.BoxWidget, corner: f32, scale: f32, edge_alpha: u8) void {
    const rs = box.data().backgroundRectScale();
    if (rs.r.w < 2 or rs.r.h < 2) return;

    // One physical pixel, for the same reason the border is. See `thinLine`.
    const thickness: f32 = 1;
    // A stroke straddles its path, so inset by half of it to keep the whole
    // line inside the fill instead of half-eating the border.
    const inset = thickness / 2;
    const inner: dvui.Rect.Physical = .{
        .x = rs.r.x + inset,
        .y = rs.r.y + inset,
        .w = @max(0, rs.r.w - thickness),
        .h = @max(0, rs.r.h - thickness),
    };
    const stops = [_]dvui.Gradient.Stop{
        .{ .color = ds.alpha(.white, edge_alpha), .offset = 0 },
        .{ .color = ds.alpha(.white, 0), .offset = 0.45 },
    };
    inner.stroke(.round(@max(0, corner * scale - inset)), .{
        .thickness = thickness,
        .color = .{ .gradient = .{ .linear = .{ .stops = &stops, .angle_degrees = 90 } } },
        .closed = true,
        .fade = 1,
    });
}

test {
    _ = @import("glass_tests.zig");
}
