/// Transition options shared by all animated value helpers.
const motion = @import("../motion.zig");
const dvui = @import("dvui");

pub const TransitionOptions = struct {
    /// Duration in microseconds (default: motion.fast = 100ms).
    duration: i32 = motion.fast,
    /// Easing function (default: DS default curve).
    easing: *const dvui.easing.EasingFn = motion.default,
};
