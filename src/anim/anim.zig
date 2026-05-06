/// dvui-ds — Animation utilities.
///
/// Provides simple, reusable animated value helpers built on dvui's
/// animation system. Any widget can smoothly transition colors or floats
/// without managing state manually.
///
/// Usage:
///   const fill = anim.color(widget_id, "fill", target_color, .{});
///   const opacity = anim.float(widget_id, "opacity", 1.0, .{});
pub const color = @import("color.zig").color;
pub const float = @import("float.zig").float;
pub const utils = @import("utils.zig");
pub const TransitionOptions = @import("options.zig").TransitionOptions;

test {
    _ = @import("anim_tests.zig");
}
