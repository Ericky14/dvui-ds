/// Animated float — smoothly transitions between target values.
///
/// Call every frame with the same `id` + `key` pair. When the target value
/// changes, a new transition starts from the current interpolated position.
///
/// Example:
///   const scale = anim.float(widget_id, "scale", if (pressed) 0.95 else 1.0, .{});
const std = @import("std");
const dvui = @import("dvui");
const TransitionOptions = @import("options.zig").TransitionOptions;

const FloatState = struct {
    from: f32 = 0,
    target: f32 = 0,
};

pub fn float(id: dvui.Id, key: []const u8, target: f32, opts: TransitionOptions) f32 {
    const state_key = id.update(key).update("_st");
    const anim_key_hash = id.update(key).update("_an");

    var state = dvui.dataGetDefault(null, state_key, "_f", FloatState, .{
        .from = target,
        .target = target,
    });

    if (@abs(target - state.target) > 0.001) {
        if (dvui.animationGet(anim_key_hash, "_f")) |anim| {
            state.from = std.math.lerp(state.from, state.target, anim.value());
        } else {
            state.from = state.target;
        }
        state.target = target;
        dvui.animation(anim_key_hash, "_f", .{
            .easing = opts.easing,
            .start_val = 0,
            .end_val = 1,
            .end_time = opts.duration,
        });
    }

    dvui.dataSet(null, state_key, "_f", state);

    if (dvui.animationGet(anim_key_hash, "_f")) |anim| {
        dvui.refresh(null, @src(), id);
        return std.math.lerp(state.from, state.target, anim.value());
    }
    return target;
}
