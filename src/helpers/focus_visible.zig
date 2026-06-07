/// Focus-visible detection (CSS `:focus-visible`).
///
/// Returns true only when the most recent input was a keyboard event, so focus
/// rings show during keyboard navigation but not after a mouse click. It derives
/// this automatically from the current frame's dvui events, so — unlike the
/// `ds_focus` notify-based path — it needs no cooperation from the host backend.
///
/// Living in the ds source tree means `@import("dvui")` resolves to whichever
/// dvui the consuming build uses (regular or the testing backend), keeping it
/// safe across both.
const dvui = @import("dvui");

/// Whether the last input was keyboard-driven. Persists across frames; only
/// flips when a key or a mouse press is seen.
var keyboard_active: bool = false;

/// True if focus rings should be drawn. Call during a widget's draw; it scans
/// the frame's events (idempotent within a frame) and returns the current state.
pub fn visible() bool {
    for (dvui.events()) |*e| {
        switch (e.evt) {
            .key => keyboard_active = true,
            .mouse => |m| {
                if (m.action == .press) keyboard_active = false;
            },
            else => {},
        }
    }
    return keyboard_active;
}
