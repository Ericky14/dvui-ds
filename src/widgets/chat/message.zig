/// A chat message. CONTRACT for the real implementation:
///   - `.user`: right-aligned bubble on `surface_2`, corners round(6) except a 2px
///     bottom-right corner, max 88% of the available width, primary text.
///   - `.assistant`: no bubble; left-aligned block, rendered through `markdown()` when
///     `render_markdown` (default), max 92% width, secondary text colour.
///   - `.system`: muted small caption, centred (status notes like "session resumed").
///   - `streaming(true)`: append a blinking caret and keep the block's min height
///     stable while text arrives, so the list does not jump.
///   - Zero allocations at draw; text is borrowed.
///
/// STATUS: scaffold. The body below is a placeholder that compiles and renders a
/// plain box so consumers can integrate against the API; the real widget replaces
/// `draw()` (and adds private `opts()` resolvers) without changing this surface.
const std = @import("std");
const dvui = @import("dvui");
const ds = @import("../../ds.zig");
const tokens = @import("../../tokens.zig");

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
        var box = dvui.box(self.src, .{ .dir = .vertical }, .{
            .id_extra = self.id_extra,
            .expand = .horizontal,
            .padding = dvui.Rect.all(tokens.current.space_xs),
        });
        defer box.deinit();
        dvui.labelNoFmt(@src(), self.text, .{}, .{ .color_text = .{ .color = tokens.current.text_secondary } });
        _ = self.role;
    }
};

test {
    _ = @import("message_tests.zig");
}
