const dvui = @import("dvui");

const Color = dvui.Color;

/// Set a color's alpha to a raw u8 value (0–255).
/// `ds.alpha(theme.accent, theme.opacity_fill_rest)` → accent at 12% opacity
pub fn alpha(c: Color, a: u8) Color {
    return .{ .r = c.r, .g = c.g, .b = c.b, .a = a };
}

/// Apply an opacity multiplier to all subsequent draws until restored.
/// Returns a handle — call `.restore()` when done (typically via `defer`).
///
/// ```
/// const opacity = ds.withOpacity(0.4);
/// defer opacity.restore();
/// ds.label(@src(), "dimmed").draw();
/// ```
pub fn withOpacity(mult: f32) Opacity {
    return .{ .previous = dvui.alpha(mult) };
}

pub const Opacity = struct {
    previous: f32,

    pub fn restore(self: Opacity) void {
        dvui.alphaSet(self.previous);
    }
};
