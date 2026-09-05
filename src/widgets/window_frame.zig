/// WindowFrame — the double border around a custom-chrome window.
///
/// Two hairlines instead of one. The outer ring is near-black and separates the
/// app from whatever is on the desktop behind it; the inner ring is white at
/// ~10 % and lifts the app off that separation. Either line alone reads badly —
/// the dark one as a smudge, the light one as a cheap outline — while the pair
/// reads as a machined edge, which is the whole trick behind every modern
/// dark-mode window.
///
/// Both lines are snapped to whole physical pixels, so they stay crisp at 1.75
/// as well as at 1.0 and 2.0.
///
/// ⚠ **It needs a borderless window.** A double ring drawn inside an OS-decorated
/// window sits *under* somebody else's title bar, and the app's own caption row
/// ends up stacked below the OS one — two title bars. `ds.App` therefore creates
/// its window borderless by default (`AppConfig.borderless`), and the app takes
/// on what the OS decoration was doing:
///
///   var frame = ds.windowFrame(@src()).focused(window_has_focus).draw();
///   defer frame.deinit();
///   drawTitleBar();      // …and, at the end of it:
///   ds.windowChrome.declare(.{
///       .drag = title_bar_rect,                    // logical window coords
///       .buttons = &.{ minimise, maximise, close },// holes in the drag region
///   });
///   drawBody();
///   drawStatusStrip();
///
/// That one call is the whole contract: SDL's hit test answers "drag" over the
/// title bar, "normal" over the caption buttons, and a resize border within 6
/// logical px of every edge and corner. Double-click-to-maximise comes with it
/// on Windows, because "drag" is answered as HTCAPTION and the OS does the rest.
/// `ds.windowChrome.minimise()` / `.toggleMaximise()` are the actions for the
/// buttons; closing stays the app's (it owns the frame loop).
///
/// Usage:
///   var frame = ds.windowFrame(@src()).focused(window_has_focus).draw();
///   defer frame.deinit();
///   drawTitleBar();
///   drawBody();
///   drawStatusStrip();
const std = @import("std");
const dvui = @import("dvui");
const ds = @import("../ds.zig");
const tokens = @import("../tokens.zig");
const pixels = @import("../helpers/pixels.zig");

pub fn windowFrame(src: std.builtin.SourceLocation) WindowFrame {
    return .{ .src = src };
}

pub const WindowFrame = struct {
    src: std.builtin.SourceLocation,
    is_focused: bool = true,
    radius_val: ?f32 = null,
    dir: dvui.enums.Direction = .vertical,
    gap_val: f32 = 0,
    tag_val: ?[]const u8 = null,

    /// Dim the inner ring when the window loses focus, so an unfocused window
    /// visibly recedes.
    pub fn focused(self: WindowFrame, value: bool) WindowFrame {
        var copy = self;
        copy.is_focused = value;
        return copy;
    }

    /// Corner radius (default `theme.radius_window`).
    pub fn radius(self: WindowFrame, logical_px: f32) WindowFrame {
        var copy = self;
        copy.radius_val = logical_px;
        return copy;
    }

    /// Lay children out horizontally instead of vertically.
    pub fn horizontal(self: WindowFrame) WindowFrame {
        var copy = self;
        copy.dir = .horizontal;
        return copy;
    }

    /// Gap between children (px).
    pub fn gap(self: WindowFrame, logical_px: f32) WindowFrame {
        var copy = self;
        copy.gap_val = logical_px;
        return copy;
    }

    /// Name this frame for tests and UI automation (`dvui.tagGet`).
    pub fn tag(self: WindowFrame, name: []const u8) WindowFrame {
        var copy = self;
        copy.tag_val = name;
        return copy;
    }

    /// Draw the frame and return the container for the window's content.
    /// `deinit()` it when done.
    pub fn draw(self: WindowFrame) *dvui.BoxWidget {
        const theme = tokens.current;
        const scale = pixels.pixelScale();
        const corner = self.radius_val orelse theme.radius_window;
        const line = pixels.hairline(scale);

        const box = dvui.box(self.src, .{ .dir = self.dir, .gap = self.gap_val }, .{
            .expand = .both,
            .background = true,
            .color_fill = .{ .color = theme.surface_0 },
            .corners = dvui.CornerRect.round(corner),
            // Outer ring, then a gutter exactly one hairline wide for the inner
            // ring to live in, so content never overlaps either line.
            .border = dvui.Rect.all(line),
            .color_border = .{ .color = theme.border_outer orelse .black },
            .padding = dvui.Rect.all(line),
            .tag = self.tag_val,
        });

        drawInnerRing(box, corner, scale, if (self.is_focused)
            theme.border_inner_alpha
        else
            theme.border_inner_alpha_unfocused);

        return box;
    }
};

/// The light ring, stroked just inside the dark one.
fn drawInnerRing(box: *dvui.BoxWidget, corner: f32, scale: f32, alpha: u8) void {
    const rs = box.data().backgroundRectScale();
    if (rs.r.w < 2 or rs.r.h < 2) return;

    const thickness = @max(1, @round(scale));
    const inset = thickness / 2;
    const ring: dvui.Rect.Physical = .{
        .x = rs.r.x + inset,
        .y = rs.r.y + inset,
        .w = @max(0, rs.r.w - thickness),
        .h = @max(0, rs.r.h - thickness),
    };
    ring.stroke(.round(@max(0, corner * scale - thickness)), .{
        .thickness = thickness,
        .color = .{ .color = ds.alpha(.white, alpha) },
        .closed = true,
        .fade = 1,
    });
}

test {
    _ = @import("window_frame_tests.zig");
}
