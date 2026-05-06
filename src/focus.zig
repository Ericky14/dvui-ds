/// Focus-visible tracking — shows focus rings only on keyboard navigation.
///
/// Call `notifyKeyboard()` when a keyboard event occurs and `notifyMouse()`
/// when a mouse click occurs. Widgets check `visible()` to decide whether
/// to draw their focus ring.
///
/// This mirrors the CSS `:focus-visible` behavior used by modern UIs.
/// Whether the last interaction was keyboard-driven.
var keyboard_active: bool = false;

/// Call when any keyboard navigation event occurs (Tab, arrows, Enter).
pub fn notifyKeyboard() void {
    keyboard_active = true;
}

/// Call when a mouse button is pressed.
pub fn notifyMouse() void {
    keyboard_active = false;
}

/// Returns true if focus rings should be drawn (last input was keyboard).
pub fn visible() bool {
    return keyboard_active;
}
