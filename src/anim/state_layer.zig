/// Material 3 state layers — animated translucent overlays for interactive
/// controls (hover / focus / press). Draw the returned color as a filled shape
/// over the control to get the M3 "state layer" feedback, smoothly faded.
///
/// Example (inside a widget's draw, called every frame with a stable id+key):
///   const sl = anim.stateLayer(id, "sl", theme.accent, .{
///       .hovered = hovered, .pressed = pressed, .focused = focused,
///   });
///   rs.r.fill(corner_rad, .{ .color = sl, .fade = 1.0 });
const dvui = @import("dvui");
const tokens = @import("../tokens.zig");
const animColor = @import("color.zig").color;

/// Interaction flags for a control this frame.
pub const InteractionState = struct {
    hovered: bool = false,
    pressed: bool = false,
    focused: bool = false,
};

/// The M3 state-layer overlay color, animated. `ink` is the layer color (the
/// control's "on" color — e.g. `theme.accent` for a selected control or
/// `theme.text_primary` for an unselected one). Returns `ink` at the opacity for
/// the current interaction state, transparent at rest. Composite it over the
/// control with a fill.
pub fn overlay(id: dvui.Id, key: []const u8, ink: dvui.Color, state: InteractionState) dvui.Color {
    const theme = tokens.current;
    const a: u8 = if (state.pressed)
        theme.state_press
    else if (state.hovered and state.focused)
        // Hover and focus layers stack in M3.
        saturatingAdd(theme.state_focus, theme.state_hover)
    else if (state.focused)
        theme.state_focus
    else if (state.hovered)
        theme.state_hover
    else
        0;

    const target: dvui.Color = .{ .r = ink.r, .g = ink.g, .b = ink.b, .a = a };
    return animColor(id, key, target, .{});
}

fn saturatingAdd(lhs: u8, rhs: u8) u8 {
    const sum = @as(u16, lhs) + @as(u16, rhs);
    return if (sum > 255) 255 else @intCast(sum);
}

test {
    _ = @import("state_layer_tests.zig");
}
