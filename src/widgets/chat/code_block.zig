/// Fenced code block: a mono listing with a language tag and a Copy button.
///
/// Draws on `surface_0` with a `border_subtle` border and round(radius_md)
/// corners. The header row shows the language (muted caption, hidden when empty)
/// on the left and a ghost `sm` copy icon button on the right. The body never
/// wraps: it is one label per line inside a horizontally scrolling area, so long
/// lines scroll instead of widening the block. Tabs are rendered as four-column
/// gaps. Zero allocations at draw; the text is borrowed.
///
/// `draw()` returns true on the frame Copy is clicked; the caller owns the
/// clipboard (`dvui.clipboardTextSet(code)`), so the block stays a pure view.
///
/// Usage:
///   if (ds.chat.codeBlock(@src(), "lua", source).draw()) dvui.clipboardTextSet(source);
///   _ = ds.chat.codeBlock(@src(), "", snippet).idExtra(index).draw();
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

    /// Draw the block. Returns true on the frame the Copy button is clicked.
    pub fn draw(self: CodeBlock) bool {
        var frame = dvui.box(self.src, .{ .dir = .vertical }, self.frameOpts());
        defer frame.deinit();

        const copied = self.drawHeader();
        self.drawBody();
        return copied;
    }

    fn drawHeader(self: CodeBlock) bool {
        var header = dvui.box(@src(), .{ .dir = .horizontal }, headerOpts());
        defer header.deinit();

        if (self.lang.len > 0) {
            dvui.labelNoFmt(@src(), self.lang, .{}, langOpts());
        }
        _ = dvui.spacer(@src(), .{ .expand = .horizontal });
        return ds.iconButton(@src(), "copy", ds.icons.copy).variant(.ghost).size(.sm).draw();
    }

    fn drawBody(self: CodeBlock) void {
        var scroll = dvui.scrollArea(@src(), .{
            .horizontal = .auto,
            .vertical = .none,
            .horizontal_bar = .auto_overlay,
        }, bodyScrollOpts());
        defer scroll.deinit();

        var lines_box = dvui.box(@src(), .{ .dir = .vertical }, bodyOpts());
        defer lines_box.deinit();

        const font = codeFont();
        var lines = std.mem.splitScalar(u8, self.code, '\n');
        var index: usize = 0;
        while (lines.next()) |raw| : (index += 1) {
            const line = std.mem.trimEnd(u8, raw, "\r");
            // A trailing newline terminates the last line; it does not add an empty one.
            if (line.len == 0 and index > 0 and lines.peek() == null) break;
            drawLine(line, font, index);
        }
    }

    /// Styling of the outer frame.
    pub fn frameOpts(self: CodeBlock) dvui.Options {
        const theme = tokens.current;
        return .{
            .id_extra = self.id_extra,
            .expand = .horizontal,
            .background = true,
            .color_fill = .{ .color = theme.surface_0 },
            .color_border = .{ .color = theme.border_subtle },
            .border = dvui.Rect.all(theme.border_width),
            .corners = dvui.CornerRect.round(theme.radius_md),
            .margin = dvui.Rect.all(0),
            .padding = dvui.Rect.all(0),
        };
    }
};

/// One code line: a single label, or tab-separated segments spaced by four
/// columns of the mono font (so leading tab indentation still reads as indentation).
fn drawLine(line: []const u8, font: dvui.Font, index: usize) void {
    if (std.mem.findScalar(u8, line, '\t') == null) {
        dvui.labelNoFmt(@src(), line, .{ .ellipsize = false }, lineOpts(font, index));
        return;
    }
    var row = dvui.box(@src(), .{ .dir = .horizontal, .gap = tabWidth(font) }, .{ .id_extra = index });
    defer row.deinit();
    var segments = std.mem.splitScalar(u8, line, '\t');
    var segment_index: usize = 0;
    while (segments.next()) |segment| : (segment_index += 1) {
        dvui.labelNoFmt(@src(), segment, .{ .ellipsize = false }, lineOpts(font, segment_index));
    }
}

/// Header row: caption padding on the left, the copy button flush right.
pub fn headerOpts() dvui.Options {
    const theme = tokens.current;
    return .{
        .expand = .horizontal,
        .padding = ds.paddingEach(theme.space_3xs, theme.space_3xs, 0, theme.space_md),
        .margin = dvui.Rect.all(0),
    };
}

/// The language tag: muted medium caption, vertically centred on the button.
pub fn langOpts() dvui.Options {
    const theme = tokens.current;
    return .{
        .font = ds.fontMedium(theme.font_size_sm),
        .color_text = .{ .color = theme.text_muted },
        .gravity_y = 0.5,
        .padding = dvui.Rect.all(0),
        .margin = dvui.Rect.all(0),
    };
}

/// The horizontal scroll area around the lines: transparent, overlay bar in muted text.
pub fn bodyScrollOpts() dvui.Options {
    const theme = tokens.current;
    return .{
        .expand = .horizontal,
        .background = false,
        .padding = dvui.Rect.all(0),
        .margin = dvui.Rect.all(0),
        .color_text = .{ .color = theme.text_muted },
    };
}

/// Padding around the lines (the header already provides the top inset).
pub fn bodyOpts() dvui.Options {
    const theme = tokens.current;
    return .{
        .padding = ds.paddingEach(0, theme.space_md, theme.space_sm, theme.space_md),
        .margin = dvui.Rect.all(0),
    };
}

/// One line of code, keyed by its line index.
pub fn lineOpts(font: dvui.Font, index: usize) dvui.Options {
    const theme = tokens.current;
    return .{
        .id_extra = index,
        .font = font,
        .color_text = .{ .color = theme.text_primary },
        .padding = dvui.Rect.all(0),
        .margin = dvui.Rect.all(0),
    };
}

/// The theme's mono face at the body size.
fn codeFont() dvui.Font {
    return dvui.Font.theme(.mono).withSize(@floatFromInt(tokens.current.font_size_md));
}

fn tabWidth(font: dvui.Font) f32 {
    return font.textSize("    ").w;
}

test {
    _ = @import("code_block_tests.zig");
}
