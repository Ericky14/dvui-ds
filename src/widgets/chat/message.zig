/// A chat message. Who is speaking drives alignment and surface:
///   - `.user`: right-aligned bubble on `surface_2`, round(6) corners with a 2px
///     bottom-right "tail" corner, at most 88% of the available width, primary text.
///   - `.assistant`: left-aligned plain block (no bubble) rendered through
///     `markdown()` by default, at most 92% wide, secondary text.
///   - `.system`: a centred muted caption for status notes ("session resumed").
///   - `streaming(true)`: a blinking accent caret follows the text, and the block's
///     min height only ratchets up while text arrives so the list never jumps.
///   Zero allocations at draw; the text is borrowed.
///
/// Usage:
///   ds.chat.message(@src(), .user, "make the ball red").draw();
///   ds.chat.message(@src(), .assistant, reply).streaming(true).idExtra(index).draw();
///   ds.chat.message(@src(), .assistant, raw_text).markdown(false).draw();
///   ds.chat.message(@src(), .system, "session resumed").draw();
const std = @import("std");
const dvui = @import("dvui");
const ds = @import("../../ds.zig");
const tokens = @import("../../tokens.zig");
const motion = @import("../../motion.zig");
const markdown_mod = @import("markdown.zig");

/// Who is speaking. Drives alignment and surface.
pub const Role = enum { user, assistant, system };
pub fn message(src: std.builtin.SourceLocation, role: Role, text: []const u8) Message {
    return .{ .src = src, .role = role, .text = text };
}

pub const Message = struct {
    src: std.builtin.SourceLocation,
    role: Role,
    text: []const u8,
    is_streaming: bool = false,
    render_markdown: bool = true,
    id_extra: usize = 0,

    /// Show a caret and a subtle pulse while text is still arriving.
    pub fn streaming(self: Message, val: bool) Message {
        var copy = self;
        copy.is_streaming = val;
        return copy;
    }

    /// Render assistant text as markdown-lite (default true).
    pub fn markdown(self: Message, val: bool) Message {
        var copy = self;
        copy.render_markdown = val;
        return copy;
    }

    /// Disambiguate identity when used in a loop / list.
    pub fn idExtra(self: Message, val: usize) Message {
        var copy = self;
        copy.id_extra = val;
        return copy;
    }

    /// Draw the widget.
    pub fn draw(self: Message) void {
        var outer = dvui.box(self.src, .{ .dir = .horizontal }, self.outerOpts());
        defer outer.deinit();
        const available = outer.data().contentRect().w;

        switch (self.role) {
            .user, .assistant => self.drawBlock(available),
            .system => self.drawSystem(),
        }
    }

    /// The bubble (user) or plain block (assistant): a column holding the text and,
    /// while streaming, the caret.
    fn drawBlock(self: Message, available: f32) void {
        const theme = tokens.current;
        const block_src = @src();
        const block_id = dvui.parentGet().extendId(block_src, 0);
        const line_height = bodyFont().lineHeight();
        const min_height = self.streamingMinHeight(block_id, line_height);

        var block = dvui.box(block_src, .{ .dir = .vertical, .gap = theme.space_2xs }, blockOpts(self.role, maxWidth(available, self.role), min_height));
        defer block.deinit();

        switch (self.role) {
            .user => drawPlain(@src(), self.text, theme.text_primary),
            .assistant => if (self.render_markdown)
                markdown_mod.markdown(@src(), self.text).draw()
            else
                drawPlain(@src(), self.text, theme.text_secondary),
            .system => {},
        }

        if (self.is_streaming) drawCaret(block_id, line_height);
    }

    fn drawSystem(self: Message) void {
        dvui.labelNoFmt(@src(), self.text, .{ .align_x = 0.5 }, systemOpts());
    }

    /// While streaming, the block's content height never shrinks between frames
    /// (and is at least one line tall), so a re-flowing paragraph cannot make the
    /// list jump. The stored height resets when the available width changes.
    fn streamingMinHeight(self: Message, block_id: dvui.Id, line_height: f32) f32 {
        if (!self.is_streaming) {
            dvui.dataRemove(null, block_id, stream_key);
            return 0;
        }
        const options = blockOpts(self.role, dvui.max_float_safe, 0);
        const stored = dvui.dataGetPtrDefault(null, block_id, stream_key, StreamHeight, .{ .height = line_height });
        if (dvui.minSizeGet(block_id)) |previous| {
            stored.height = @max(stored.height, previous.h - verticalInsets(options));
        }
        stored.height = @max(stored.height, line_height);
        return stored.height;
    }

    /// The transparent full-width row that positions the block.
    pub fn outerOpts(self: Message) dvui.Options {
        return .{
            .id_extra = self.id_extra,
            .expand = .horizontal,
            .margin = dvui.Rect.all(0),
            .padding = dvui.Rect.all(0),
        };
    }
};

const StreamHeight = struct { height: f32 };
const stream_key = "_ds_stream_h";

/// Width fractions from the widget contract: the bubble hugs its text up to this
/// share of the row, then wraps.
const user_max_fraction: f32 = 0.88;
const assistant_max_fraction: f32 = 0.92;
/// Contract pixel value: the user bubble's bottom-right "tail" corner.
const user_tail_radius: f32 = 2;
/// Caret geometry: a thin accent bar one line tall.
const caret_width: f32 = 2;

/// Largest content width the block may take for `role`; unbounded until the row
/// has a width (the first frame).
pub fn maxWidth(available: f32, role: Role) f32 {
    if (available <= 0) return dvui.max_float_safe;
    const fraction: f32 = switch (role) {
        .user => user_max_fraction,
        .assistant => assistant_max_fraction,
        .system => 1.0,
    };
    return @floor(available * fraction);
}

/// The user bubble's corners: round(radius_sm) with a 2px bottom-right tail.
pub fn userCorners() dvui.CornerRect {
    const radius = tokens.current.radius_sm;
    return .{
        .tl = .round(radius),
        .tr = .round(radius),
        .bl = .round(radius),
        .br = .round(user_tail_radius),
    };
}

/// Styling of the message block: a bubble for `.user`, a bare block for `.assistant`.
/// `max_width` caps the block's outer width (see `maxWidth`) — the bubble padding
/// is taken out of the content cap; `min_height` is the streaming ratchet (0 when idle).
pub fn blockOpts(role: Role, max_width: f32, min_height: f32) dvui.Options {
    const theme = tokens.current;
    return switch (role) {
        .user => .{
            .gravity_x = 1.0,
            .background = true,
            .color_fill = .{ .color = theme.surface_2 },
            .corners = userCorners(),
            .padding = ds.paddingXY(theme.space_md, theme.space_sm),
            .margin = dvui.Rect.all(0),
            .min_size_content = .{ .w = 0, .h = min_height },
            .max_size_content = .{ .w = @max(0, max_width - 2 * theme.space_md), .h = dvui.max_float_safe },
        },
        .assistant, .system => .{
            .gravity_x = 0.0,
            .background = false,
            .padding = ds.paddingXY(0, theme.space_2xs),
            .margin = dvui.Rect.all(0),
            .min_size_content = .{ .w = 0, .h = min_height },
            .max_size_content = .{ .w = max_width, .h = dvui.max_float_safe },
        },
    };
}

/// The centred muted caption used for `.system` notes.
pub fn systemOpts() dvui.Options {
    const theme = tokens.current;
    return .{
        .gravity_x = 0.5,
        .font = ds.font(theme.font_size_sm),
        .color_text = .{ .color = theme.text_muted },
        .padding = ds.paddingXY(theme.space_md, theme.space_2xs),
        .margin = dvui.Rect.all(0),
    };
}

/// Wrapped plain text in the body font.
fn drawPlain(src: std.builtin.SourceLocation, text: []const u8, color: dvui.Color) void {
    var layout = dvui.textLayout(src, .{ .break_lines = true }, .{
        .expand = .horizontal,
        .background = false,
        .padding = dvui.Rect.all(0),
        .margin = dvui.Rect.all(0),
        .font = bodyFont(),
        .color_text = .{ .color = color },
    });
    defer layout.deinit();
    layout.addText(text, .{});
}

/// A blinking accent bar after the text. The blink runs on a dvui timer keyed by
/// the block, so it only costs a frame per half period.
fn drawCaret(block_id: dvui.Id, line_height: f32) void {
    const theme = tokens.current;
    const blink_id = block_id.update("caret");
    const visible = dvui.dataGetPtrDefault(null, blink_id, "_on", bool, true);
    if (dvui.timerDoneOrNone(blink_id)) {
        if (dvui.timerGet(blink_id) != null) visible.* = !visible.*;
        dvui.timer(blink_id, motion.slower);
    }
    var caret = dvui.box(@src(), .{}, .{
        .background = visible.*,
        .color_fill = .{ .color = theme.accent },
        .corners = dvui.CornerRect.round(caret_width / 2),
        .margin = dvui.Rect.all(0),
        .padding = dvui.Rect.all(0),
        .min_size_content = .{ .w = caret_width, .h = line_height },
    });
    caret.deinit();
}

fn bodyFont() dvui.Font {
    return ds.font(tokens.current.font_size_md);
}

/// Margin + border + padding above and below the content, so a padded min size
/// can be converted back into a content height.
fn verticalInsets(options: dvui.Options) f32 {
    const margin = options.marginGet();
    const border = options.borderGet();
    const padding = options.paddingGet();
    return margin.y + margin.h + border.y + border.h + padding.y + padding.h;
}

test {
    _ = @import("message_tests.zig");
}
