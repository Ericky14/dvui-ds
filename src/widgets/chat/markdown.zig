/// Markdown-lite renderer for assistant text. CONTRACT for the real implementation:
///   - Paragraphs separated by blank lines; single newlines soft-wrap.
///   - Inline: `**bold**`, `*italic*`, `` `code` `` (mono on `surface_2`), links shown as
///     their text with an underline (no navigation).
///   - Blocks: `#`/`##`/`###` headings (heading font, three sizes), `- ` / `* ` bullet
///     lists, `1. ` ordered lists (nesting by two-space indent, one level is enough),
///     fenced ``` blocks delegated to `codeBlock()` with the info string as language.
///   - Unknown syntax is rendered literally; never panics on malformed input.
///   - Zero allocations at draw: walk the input slice; per-line `dvui` widgets keyed by
///     line index via `id_extra`.
///
/// STATUS: scaffold. The body below is a placeholder that compiles and renders a
/// plain box so consumers can integrate against the API; the real widget replaces
/// `draw()` (and adds private `opts()` resolvers) without changing this surface.
const std = @import("std");
const dvui = @import("dvui");
const ds = @import("../../ds.zig");
const tokens = @import("../../tokens.zig");

pub fn markdown(src: std.builtin.SourceLocation, text: []const u8) Markdown {
    return .{ .src = src, .text = text };
}

pub const Markdown = struct {
    src: std.builtin.SourceLocation,
    text: []const u8,
    id_extra: usize = 0,

    /// Disambiguate identity when used in a loop / list.
    pub fn idExtra(self: Markdown, val: usize) Markdown {
        var copy = self;
        copy.id_extra = val;
        return copy;
    }

    /// Draw the widget.
    pub fn draw(self: Markdown) void {
        var box = dvui.box(self.src, .{ .dir = .vertical }, .{ .id_extra = self.id_extra, .expand = .horizontal });
        defer box.deinit();
        dvui.labelNoFmt(@src(), self.text, .{}, .{ .color_text = .{ .color = tokens.current.text_secondary } });
    }
};

test {
    _ = @import("markdown_tests.zig");
}
