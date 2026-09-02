/// Fenced code block. Returns true on the frame the Copy button is clicked (the
/// caller puts `code` on the clipboard with `dvui.clipboardTextSet`). CONTRACT:
///   - Mono font, `surface_0` fill, `border_subtle` border, corners round(radius_md).
///   - Header row: language tag (muted caption, hidden when empty) left, copy icon
///     button (ghost, sm) right.
///   - Body: no wrapping; horizontal scroll area when wider than the container; the
///     text is one `dvui.labelNoFmt` per line (or a TextLayout) with tabular spacing.
///   - Selectable text is a plus, not required.
///
/// STATUS: scaffold. The body below is a placeholder that compiles and renders a
/// plain box so consumers can integrate against the API; the real widget replaces
/// `draw()` (and adds private `opts()` resolvers) without changing this surface.
const std = @import("std");
const dvui = @import("dvui");
const ds = @import("../../ds.zig");
const tokens = @import("../../tokens.zig");

pub fn codeBlock(src: std.builtin.SourceLocation, lang: []const u8, code: []const u8) CodeBlock {
    return .{ .src = src, .lang = lang, .code = code };
}

pub const CodeBlock = struct {
    src: std.builtin.SourceLocation,
    lang: []const u8,
    code: []const u8,
    id_extra: usize = 0,

    /// Disambiguate identity when used in a loop / list.
    pub fn idExtra(self: CodeBlock, val: usize) CodeBlock {
        var copy = self;
        copy.id_extra = val;
        return copy;
    }

    /// Draw the widget.
    pub fn draw(self: CodeBlock) bool {
        var box = dvui.box(self.src, .{ .dir = .vertical }, .{
            .id_extra = self.id_extra,
            .expand = .horizontal,
            .background = true,
            .color_fill = .{ .color = tokens.current.surface_0 },
            .padding = dvui.Rect.all(tokens.current.space_xs),
        });
        defer box.deinit();
        dvui.labelNoFmt(@src(), self.code, .{}, .{ .font = ds.font(tokens.current.font_size_sm), .color_text = .{ .color = tokens.current.text_secondary } });
        _ = self.lang;
        return false;
    }
};

test {
    _ = @import("code_block_tests.zig");
}
