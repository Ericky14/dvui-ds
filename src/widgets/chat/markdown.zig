/// Markdown-lite renderer for assistant text.
///
/// A deliberately small CommonMark subset, walked with no allocation: the text is
/// borrowed, blocks and inline runs are slices into it, and every dvui widget is
/// keyed by its block index via `id_extra`.
///
/// Grammar:
///   Blocks (line based; blank lines separate paragraphs):
///     `# ` / `## ` / `### `   headings in three sizes (`####` and `#tag` stay literal)
///     `- ` / `* `             bullet items; two spaces of indent nest one level
///     `1. `                   ordered items; the number is rendered as written
///     ``` lang … ```          fenced code delegated to `codeBlock()` with the info
///                             string as language; an unterminated fence runs to the end
///     anything else           a paragraph; single newlines soft-wrap
///   Inline (inside paragraphs, headings and list items):
///     **bold**, *italic*, `code` (mono on `surface_2`, wraps to a fresh line as a
///     whole chip rather than splitting mid-word — the break is spent from the blank
///     before the chip, so selecting and copying the text yields the source and never
///     a newline the source lacks), [text](url) (underlined, never navigated).
///     Unbalanced delimiters render literally; nothing panics.
///
/// Usage:
///   ds.chat.markdown(@src(), "## Done\nThe ball is **red** now.").draw();
///   ds.chat.markdown(@src(), reply_text).idExtra(index).draw();
const std = @import("std");
const dvui = @import("dvui");
const ds = @import("../../ds.zig");
const tokens = @import("../../tokens.zig");
const code_block = @import("code_block.zig");

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

    /// Draw the widget: one dvui widget per block, keyed by block index.
    pub fn draw(self: Markdown) void {
        const theme = tokens.current;
        var box = dvui.box(self.src, .{ .dir = .vertical, .gap = theme.space_sm }, .{
            .id_extra = self.id_extra,
            .expand = .horizontal,
        });
        defer box.deinit();

        var blocks = BlockIterator.init(self.text);
        var index: usize = 0;
        while (blocks.next()) |block| : (index += 1) {
            switch (block.kind) {
                .paragraph => drawRuns(@src(), index, block.text, bodyFont(), theme.text_secondary),
                .heading => drawRuns(@src(), index, block.text, headingFont(block.level), theme.text_primary),
                .bullet, .ordered => drawListItem(index, block),
                .code => {
                    // The markdown widget is the code block's caller, so it owns the
                    // clipboard side of the Copy contract: exactly the fenced body —
                    // its lines joined by '\n', with the newline that terminated the
                    // last line dropped by `fencedBlock` (a blank final line in the
                    // source is intentional and survives as one trailing newline).
                    if (code_block.codeBlock(@src(), block.lang, block.text).idExtra(index).draw()) {
                        dvui.clipboardTextSet(block.text);
                    }
                },
            }
        }
    }
};

// ─── Rendering ───────────────────────────────────────────────────────────────

/// One wrapped text layout holding the inline runs of a block.
fn drawRuns(src: std.builtin.SourceLocation, id_extra: usize, text: []const u8, base_font: dvui.Font, base_color: dvui.Color) void {
    var layout = dvui.textLayout(src, .{ .break_lines = true }, layoutOpts(id_extra, base_font, base_color));
    defer layout.deinit();

    var sink: LayoutSink = .{ .layout = layout, .base_font = base_font, .base_color = base_color };
    emitRuns(&sink, text);
}

/// The sink `emitRuns` draws into: each piece goes to the live text layout with
/// its run styling, and the wrap decision measures the chip — plus the blank that
/// would precede it — against what is left of the current line.
const LayoutSink = struct {
    layout: *dvui.TextLayoutWidget,
    base_font: dvui.Font,
    base_color: dvui.Color,

    fn add(self: *LayoutSink, text: []const u8, style: Style) void {
        self.layout.addText(text, runOpts(style, self.base_font, self.base_color));
    }

    fn breaksBefore(self: *LayoutSink, chip: Run, separator: Style) bool {
        const chip_font = runOpts(chip.style, self.base_font, self.base_color).fontGet();
        const separator_font = runOpts(separator, self.base_font, self.base_color).fontGet();
        const needed = separator_font.textSize(" ").w + chip_font.textSize(chip.text).w;
        return chipNeedsBreak(needed, self.layout.data().contentRect().w, self.layout.insert_pt.x);
    }
};

/// Hand the inline runs of `text` to `sink` piece by piece, in draw order.
///
/// `sink` is duck-typed so the same walk runs headless in the tests:
///   - `fn add(self, text: []const u8, style: Style) void` — draw or record a piece.
///   - `fn breaksBefore(self, chip: Run, separator: Style) bool` — must this chip
///     start a fresh line instead of following `separator`, the blank held for it?
///
/// **Every piece is a slice of the source, or the single space a soft newline
/// renders as — the walk never invents a byte.** `TextLayoutWidget` puts exactly
/// the bytes it was handed on the clipboard when text is selected and copied, so a
/// synthetic '\n' added to keep a chip whole would be copied along with the code.
/// The break is therefore *spent* from the blank separating the chip from the run
/// before it: that space becomes the break rather than gaining one, so the copied
/// chip is exactly its code. A chip glued to the previous word (``foo`bar` ``) has
/// no blank to spend and none to gain — it wraps like any other long word.
///
/// Usage: `markdown.emitRuns(&sink, "run `zig build test` now");`
pub fn emitRuns(sink: anytype, text: []const u8) void {
    var runs = InlineIterator.init(text);
    // The style of a blank held back from the previous run, still to be spent.
    var held: ?Style = null;
    while (runs.next()) |run| {
        if (isChip(run)) {
            const breaks = if (held) |separator| sink.breaksBefore(run, separator) else false;
            if (held) |separator| sink.add(if (breaks) "\n" else " ", separator);
            held = null;
            sink.add(run.text, run.style);
            continue;
        }
        if (held) |separator| sink.add(" ", separator);
        held = emitSoftWrapped(sink, run.text, run.style);
    }
    if (held) |separator| sink.add(" ", separator);
}

/// A code run that can be placed as a single visual unit, never split mid-word.
///
/// `TextLayoutWidget` wraps at word (space) boundaries, but a code span is exactly
/// one "word" with no spaces in it. Its own line-breaking only drops a whole word
/// to the next line when that word doesn't fit anywhere on the current line width
/// at all; when a shorter prefix of the word DOES fit in the space left on the
/// line (just not the whole thing), it renders that prefix and continues the rest
/// on the next line — i.e. it silently splits the chip wherever it happens to
/// land. Measuring the chip and spending the blank before it as a break keeps it
/// whole. A chip wider than the entire line still wraps at its own character
/// boundaries once it is alone on a fresh line — nothing else competes for that
/// space, so the break stays inside the chip. A code span carrying a soft newline
/// is not a chip: it takes the normal per-line path instead of being measured.
fn isChip(run: Run) bool {
    return run.style.code and run.text.len > 0 and std.mem.findScalar(u8, run.text, '\n') == null;
}

/// Whether a chip of `chip_width` must be pushed to a fresh line: it doesn't
/// fit in what's left of the current line (`container_width - current_x`),
/// but the line already holds other content, so a fresh line offers more
/// room. Never forces a break at the very start of a line (`current_x == 0`,
/// nowhere better to put it) or before the widget has a settled width
/// (`container_width <= 0`, e.g. the first layout frame).
///
/// Usage: `markdown.chipNeedsBreak(chip_width, container_width, current_x)`.
pub fn chipNeedsBreak(chip_width: f32, container_width: f32, current_x: f32) bool {
    return container_width > 0 and current_x > 0 and current_x + chip_width > container_width;
}

/// Emit a run whose newlines are soft wraps: each newline (plus the indentation of
/// the following line) becomes a single space. The run's trailing blank, if it has
/// one, is not emitted but returned: the caller either flushes it as that space or
/// spends it as the line break before a code chip.
fn emitSoftWrapped(sink: anytype, text: []const u8, style: Style) ?Style {
    var rest = text;
    var first = true;
    var held = false;
    while (true) {
        const newline = std.mem.findScalar(u8, rest, '\n');
        var piece = if (newline) |at| rest[0..at] else rest;
        if (!first) piece = std.mem.trimStart(u8, piece, " \t");
        if (newline != null) piece = std.mem.trimEnd(u8, piece, " \t\r");
        if (!first) {
            if (held) sink.add(" ", style);
            held = true;
        }
        if (piece.len > 0) {
            if (held) sink.add(" ", style);
            held = piece[piece.len - 1] == ' ';
            const body = if (held) piece[0 .. piece.len - 1] else piece;
            if (body.len > 0) sink.add(body, style);
        }
        first = false;
        if (newline) |at| {
            rest = rest[at + 1 ..];
        } else break;
    }
    return if (held) style else null;
}

fn drawListItem(index: usize, block: Block) void {
    const theme = tokens.current;
    const font = bodyFont();
    var row = dvui.box(@src(), .{ .dir = .horizontal, .gap = theme.space_sm }, .{
        .id_extra = index,
        .expand = .horizontal,
        .margin = .{ .x = indentPx(block.level) },
    });
    defer row.deinit();

    dvui.labelNoFmt(@src(), block.marker, .{}, markerOpts(font));
    drawRuns(@src(), 0, block.text, font, theme.text_secondary);
}

fn layoutOpts(id_extra: usize, base_font: dvui.Font, base_color: dvui.Color) dvui.Options {
    return .{
        .id_extra = id_extra,
        .expand = .horizontal,
        .background = false,
        .padding = dvui.Rect.all(0),
        .margin = dvui.Rect.all(0),
        .font = base_font,
        .color_text = .{ .color = base_color },
    };
}

/// Per-run font and colour. Geist ships Regular/Medium/Bold and no italic face, so
/// italic emphasis reads as medium weight in the primary colour.
fn runOpts(style: Style, base_font: dvui.Font, base_color: dvui.Color) dvui.Options {
    const theme = tokens.current;
    if (style.code) {
        return .{
            .font = monoFont(base_font),
            .color_text = .{ .color = theme.text_primary },
            .color_fill = .{ .color = theme.surface_2 },
        };
    }
    var font = base_font;
    var color = base_color;
    if (style.italic) {
        font = font.withWeight(.medium);
        color = theme.text_primary;
    }
    if (style.bold) {
        font = font.withWeight(.bold);
        color = theme.text_primary;
    }
    if (style.link) {
        font = font.withUnderline(.{});
        color = theme.accent;
    }
    return .{ .font = font, .color_text = .{ .color = color } };
}

fn markerOpts(font: dvui.Font) dvui.Options {
    const theme = tokens.current;
    return .{
        .font = font,
        .color_text = .{ .color = theme.text_muted },
        .padding = dvui.Rect.all(0),
        .margin = dvui.Rect.all(0),
        // Wide enough for a two-digit ordered marker so wrapped item text aligns.
        .min_size_content = .{ .w = font.textSize("00.").w },
    };
}

fn bodyFont() dvui.Font {
    return ds.font(tokens.current.font_size_md);
}

fn headingFont(level: u8) dvui.Font {
    const theme = tokens.current;
    return switch (level) {
        1 => ds.fontBold(theme.font_size_xl),
        2 => ds.fontBold(theme.font_size_lg),
        else => ds.fontBold(theme.font_size_md),
    };
}

/// The theme's mono face at the size of the surrounding text.
fn monoFont(base_font: dvui.Font) dvui.Font {
    return dvui.Font.theme(.mono).withSize(base_font.size);
}

fn indentPx(level: u8) f32 {
    return tokens.current.space_lg * @as(f32, @floatFromInt(level));
}

// ─── Block walker ────────────────────────────────────────────────────────────

pub const BlockKind = enum { paragraph, heading, bullet, ordered, code };

pub const Block = struct {
    kind: BlockKind,
    /// Heading level (1–3) for headings; nesting depth (0 = top) for list items.
    level: u8 = 0,
    /// The block's text: paragraph / heading / item text (may hold soft newlines),
    /// or the code body for fenced blocks.
    text: []const u8,
    /// Fence info string (language) for code blocks; empty otherwise.
    lang: []const u8 = "",
    /// The marker to draw before a list item: "•" or the ordered number as written.
    marker: []const u8 = "",
};

/// Splits borrowed text into blocks without allocating. Each `next()` returns
/// slices into the original text.
pub const BlockIterator = struct {
    text: []const u8,
    pos: usize = 0,

    pub fn init(text: []const u8) BlockIterator {
        return .{ .text = text };
    }

    pub fn next(self: *BlockIterator) ?Block {
        var line = lineAt(self.text, self.pos);
        while (self.pos < self.text.len and line.kind == .blank) {
            self.pos = line.next;
            line = lineAt(self.text, self.pos);
        }
        if (self.pos >= self.text.len) return null;

        switch (line.kind) {
            .fence => return self.fencedBlock(line),
            .heading => {
                self.pos = line.next;
                return .{
                    .kind = .heading,
                    .level = line.level,
                    .text = trimBlock(self.text[line.content_start..line.end]),
                };
            },
            .bullet, .ordered => {
                // Lazy continuation: following plain lines indented past the marker.
                var end = line.end;
                var scan = line.next;
                while (scan < self.text.len) {
                    const continuation = lineAt(self.text, scan);
                    if (continuation.kind != .text or continuation.indent <= line.indent) break;
                    end = continuation.end;
                    scan = continuation.next;
                }
                self.pos = scan;
                return .{
                    .kind = if (line.kind == .bullet) .bullet else .ordered,
                    .level = @intCast(@min(line.indent / 2, max_list_depth)),
                    .text = trimBlock(self.text[line.content_start..end]),
                    .marker = if (line.kind == .bullet) bullet_marker else line.marker,
                };
            },
            .text => {
                var end = line.end;
                var scan = line.next;
                while (scan < self.text.len) {
                    const continuation = lineAt(self.text, scan);
                    if (continuation.kind != .text) break;
                    end = continuation.end;
                    scan = continuation.next;
                }
                self.pos = scan;
                return .{ .kind = .paragraph, .text = trimBlock(self.text[line.content_start..end]) };
            },
            .blank => return null,
        }
    }

    fn fencedBlock(self: *BlockIterator, opening: Line) Block {
        const body_start = opening.next;
        var body_end = self.text.len;
        self.pos = self.text.len;
        var scan = body_start;
        while (scan < self.text.len) {
            const candidate = lineAt(self.text, scan);
            if (candidate.kind == .fence) {
                body_end = candidate.start;
                self.pos = candidate.next;
                break;
            }
            scan = candidate.next;
        }
        var body = self.text[@min(body_start, body_end)..body_end];
        // Drop the newline that terminated the last body line, keeping any
        // intentional blank lines inside the block.
        if (std.mem.endsWith(u8, body, "\n")) body = body[0 .. body.len - 1];
        if (std.mem.endsWith(u8, body, "\r")) body = body[0 .. body.len - 1];
        return .{ .kind = .code, .text = body, .lang = opening.lang };
    }
};

const bullet_marker = "•";
const max_list_depth: usize = 3;

const LineKind = enum { blank, heading, bullet, ordered, fence, text };

const Line = struct {
    kind: LineKind,
    /// Absolute byte range of the line (a trailing '\r' is excluded from `end`).
    start: usize,
    end: usize,
    /// Absolute start of the following line.
    next: usize,
    /// Leading whitespace characters.
    indent: usize,
    /// Heading level (1–3) for headings.
    level: u8 = 0,
    /// Absolute offset where the content after the marker / hashes begins.
    content_start: usize,
    /// Fence info string (language) for fence lines.
    lang: []const u8 = "",
    /// The marker as written for ordered items ("12.").
    marker: []const u8 = "",
};

fn lineAt(text: []const u8, start: usize) Line {
    const newline_at = std.mem.findScalarPos(u8, text, start, '\n') orelse text.len;
    const line = std.mem.trimEnd(u8, text[start..newline_at], "\r");
    const end = start + line.len;
    const next = @min(newline_at + 1, text.len);

    var indent: usize = 0;
    while (indent < line.len and (line[indent] == ' ' or line[indent] == '\t')) : (indent += 1) {}
    const rest = line[indent..];
    const rest_start = start + indent;

    var info: Line = .{ .kind = .text, .start = start, .end = end, .next = next, .indent = indent, .content_start = rest_start };
    if (rest.len == 0) {
        info.kind = .blank;
        return info;
    }

    if (std.mem.startsWith(u8, rest, "```")) {
        info.kind = .fence;
        info.lang = std.mem.trim(u8, rest[3..], " \t`");
        return info;
    }

    if (rest[0] == '#') {
        var hashes: usize = 0;
        while (hashes < rest.len and rest[hashes] == '#') : (hashes += 1) {}
        if (hashes <= 3 and (hashes == rest.len or rest[hashes] == ' ' or rest[hashes] == '\t')) {
            info.kind = .heading;
            info.level = @intCast(hashes);
            info.content_start = rest_start + skipSpaces(rest, hashes);
        }
        return info;
    }

    if ((rest[0] == '-' or rest[0] == '*') and (rest.len == 1 or rest[1] == ' ' or rest[1] == '\t')) {
        info.kind = .bullet;
        info.content_start = rest_start + skipSpaces(rest, 1);
        return info;
    }

    var digits: usize = 0;
    while (digits < rest.len and digits < 9 and std.ascii.isDigit(rest[digits])) : (digits += 1) {}
    if (digits > 0 and digits < rest.len and rest[digits] == '.' and
        (digits + 1 == rest.len or rest[digits + 1] == ' ' or rest[digits + 1] == '\t'))
    {
        info.kind = .ordered;
        info.marker = rest[0 .. digits + 1];
        info.content_start = rest_start + skipSpaces(rest, digits + 1);
        return info;
    }

    return info;
}

/// Index of the first non-space character at or after `from`.
fn skipSpaces(text: []const u8, from: usize) usize {
    var index = from;
    while (index < text.len and (text[index] == ' ' or text[index] == '\t')) : (index += 1) {}
    return index;
}

fn trimBlock(text: []const u8) []const u8 {
    return std.mem.trim(u8, text, " \t\r\n");
}

// ─── Inline tokenizer ────────────────────────────────────────────────────────

pub const Style = struct {
    bold: bool = false,
    italic: bool = false,
    code: bool = false,
    link: bool = false,
};

pub const Run = struct {
    text: []const u8,
    style: Style = .{},
    /// Link target for link runs (shown as the text, never navigated to).
    url: []const u8 = "",
};

/// Splits one block's text into styled runs without allocating. Emphasis toggles
/// track open state; a delimiter only opens when a matching closer exists later,
/// so unbalanced markers fall through as literal text.
pub const InlineIterator = struct {
    text: []const u8,
    pos: usize = 0,
    bold: bool = false,
    italic: bool = false,
    last_opened: Emphasis = .bold,

    const Emphasis = enum { bold, italic };

    const Action = union(enum) {
        /// An emphasis delimiter: flips a style, consumes `len` bytes, emits nothing.
        toggle: struct { which: Emphasis, on: bool, len: usize },
        /// A complete code span or link: emits `run` and continues at `end`.
        emit: struct { run: Run, end: usize },
    };

    pub fn init(text: []const u8) InlineIterator {
        return .{ .text = text };
    }

    pub fn next(self: *InlineIterator) ?Run {
        while (self.pos < self.text.len) {
            const run_start = self.pos;
            var scan = run_start;
            while (scan < self.text.len) {
                if (self.actionAt(scan)) |action| {
                    if (scan > run_start) {
                        // Flush the literal text first; the delimiter is handled next call.
                        self.pos = scan;
                        return self.textRun(run_start, scan);
                    }
                    switch (action) {
                        .toggle => |flip| {
                            self.setEmphasis(flip.which, flip.on);
                            self.pos = scan + flip.len;
                            break;
                        },
                        .emit => |emit| {
                            self.pos = emit.end;
                            var run = emit.run;
                            if (run.style.link) {
                                // Links inherit the surrounding emphasis; code spans do not.
                                run.style.bold = self.bold;
                                run.style.italic = self.italic;
                            }
                            return run;
                        },
                    }
                } else {
                    scan += literalLength(self.text, scan);
                }
            } else {
                self.pos = self.text.len;
                return self.textRun(run_start, self.text.len);
            }
        }
        return null;
    }

    fn textRun(self: *const InlineIterator, start: usize, end: usize) Run {
        return .{ .text = self.text[start..end], .style = .{ .bold = self.bold, .italic = self.italic } };
    }

    fn setEmphasis(self: *InlineIterator, which: Emphasis, on: bool) void {
        switch (which) {
            .bold => self.bold = on,
            .italic => self.italic = on,
        }
        if (on) self.last_opened = which;
    }

    fn actionAt(self: *const InlineIterator, index: usize) ?Action {
        return switch (self.text[index]) {
            '*' => self.emphasisAt(index),
            '`' => codeAt(self.text, index),
            '[' => linkAt(self.text, index),
            else => null,
        };
    }

    fn emphasisAt(self: *const InlineIterator, index: usize) ?Action {
        const text = self.text;
        const run_len = runLength(text, index, '*');

        if (self.bold and self.italic) {
            if (!canClose(text, index)) return null;
            if (run_len >= 3) {
                return if (self.last_opened == .italic) toggle(.italic, false, 1) else toggle(.bold, false, 2);
            }
            return if (run_len == 2) toggle(.bold, false, 2) else toggle(.italic, false, 1);
        }
        if (self.bold) {
            if (run_len >= 2) return if (canClose(text, index)) toggle(.bold, false, 2) else null;
            return if (canOpen(text, index, run_len) and hasItalicCloser(text, index + run_len)) toggle(.italic, true, 1) else null;
        }
        if (self.italic) {
            if (run_len == 1) return if (canClose(text, index)) toggle(.italic, false, 1) else null;
            return if (canOpen(text, index, run_len) and hasBoldCloser(text, index + run_len)) toggle(.bold, true, 2) else null;
        }
        if (run_len >= 2) {
            return if (canOpen(text, index, run_len) and hasBoldCloser(text, index + run_len)) toggle(.bold, true, 2) else null;
        }
        return if (canOpen(text, index, run_len) and hasItalicCloser(text, index + run_len)) toggle(.italic, true, 1) else null;
    }

    fn toggle(which: Emphasis, on: bool, len: usize) Action {
        return .{ .toggle = .{ .which = which, .on = on, .len = len } };
    }
};

/// Bytes to treat as literal text at `index`: a whole delimiter run for `*` and
/// `` ` `` (so a rejected `**` is never re-evaluated as `*` + `*`), else one byte.
fn literalLength(text: []const u8, index: usize) usize {
    return switch (text[index]) {
        '*', '`' => runLength(text, index, text[index]),
        else => 1,
    };
}

fn runLength(text: []const u8, index: usize, char: u8) usize {
    var end = index;
    while (end < text.len and text[end] == char) : (end += 1) {}
    return end - index;
}

/// An opener must be followed by something other than whitespace.
fn canOpen(text: []const u8, index: usize, run_len: usize) bool {
    const after = index + run_len;
    return after < text.len and !std.ascii.isWhitespace(text[after]);
}

/// A closer must be preceded by something other than whitespace.
fn canClose(text: []const u8, index: usize) bool {
    return index > 0 and !std.ascii.isWhitespace(text[index - 1]);
}

fn hasBoldCloser(text: []const u8, from: usize) bool {
    var index = from;
    while (index + 1 < text.len) : (index += 1) {
        if (text[index] == '*' and text[index + 1] == '*' and canClose(text, index)) return true;
    }
    return false;
}

/// A single `*` (not the start of a bare `**`) preceded by a non-space, non-star byte.
fn hasItalicCloser(text: []const u8, from: usize) bool {
    var index = from;
    while (index < text.len) {
        if (text[index] != '*') {
            index += 1;
            continue;
        }
        const run_len = runLength(text, index, '*');
        if (canClose(text, index) and text[index - 1] != '*' and run_len != 2) return true;
        index += run_len;
    }
    return false;
}

fn codeAt(text: []const u8, index: usize) ?InlineIterator.Action {
    const ticks = runLength(text, index, '`');
    var scan = index + ticks;
    while (scan < text.len) {
        if (text[scan] != '`') {
            scan += 1;
            continue;
        }
        const closing = runLength(text, scan, '`');
        if (closing == ticks) {
            const inner = text[index + ticks .. scan];
            if (inner.len == 0) return null;
            return .{ .emit = .{ .run = .{ .text = inner, .style = .{ .code = true } }, .end = scan + closing } };
        }
        scan += closing;
    }
    return null;
}

fn linkAt(text: []const u8, index: usize) ?InlineIterator.Action {
    const close = std.mem.findScalarPos(u8, text, index + 1, ']') orelse return null;
    if (close + 1 >= text.len or text[close + 1] != '(') return null;
    const url_end = std.mem.findScalarPos(u8, text, close + 2, ')') orelse return null;
    const label = text[index + 1 .. close];
    if (label.len == 0) return null;
    return .{ .emit = .{
        .run = .{ .text = label, .style = .{ .link = true }, .url = text[close + 2 .. url_end] },
        .end = url_end + 1,
    } };
}

test {
    _ = @import("markdown_tests.zig");
}
