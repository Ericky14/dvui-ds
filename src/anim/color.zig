/// Animated color — smoothly transitions between target colors.
///
/// Call every frame with the same `id` + `key` pair. When the target color
/// changes, a new transition starts from the current interpolated position.
///
/// Example:
///   const bg = anim.color(widget_id, "bg", if (hovered) hover_color else rest_color, .{});
///   widget.borderAndBackground(.{ .fill_color = bg });
const dvui = @import("dvui");
const utils = @import("utils.zig");
const TransitionOptions = @import("options.zig").TransitionOptions;

const Color = dvui.Color;

const ColorState = struct {
    from: Color = .transparent,
    target: Color = .transparent,
};

pub fn color(id: dvui.Id, key: []const u8, target: Color, opts: TransitionOptions) Color {
    const state_key = id.update(key).update("_st");
    const anim_key_hash = id.update(key).update("_an");

    var state = dvui.dataGetDefault(null, state_key, "_c", ColorState, .{
        .from = target,
        .target = target,
    });

    if (!target.eql(state.target)) {
        // Target changed — start new transition from current position
        if (dvui.animationGet(anim_key_hash, "_c")) |anim| {
            state.from = utils.lerpColor(state.from, state.target, anim.value());
        } else {
            state.from = state.target;
        }
        state.target = target;
        dvui.animation(anim_key_hash, "_c", .{
            .easing = opts.easing,
            .start_val = 0,
            .end_val = 1,
            .end_time = opts.duration,
        });
    }

    dvui.dataSet(null, state_key, "_c", state);

    if (dvui.animationGet(anim_key_hash, "_c")) |anim| {
        dvui.refresh(null, @src(), id);
        return utils.lerpColor(state.from, state.target, anim.value());
    }
    return target;
}
