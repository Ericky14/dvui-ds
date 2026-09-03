/// Tests for the markdown-lite builder, block walker and inline tokenizer.
const std = @import("std");
const md = @import("markdown.zig");

const Run = md.Run;
const Block = md.Block;

fn collectRuns(text: []const u8, storage: []Run) []Run {
    var iter = md.InlineIterator.init(text);
    var count: usize = 0;
    while (iter.next()) |run| {
        if (count == storage.len) break;
        storage[count] = run;
        count += 1;
    }
    return storage[0..count];
}

fn collectBlocks(text: []const u8, storage: []Block) []Block {
    var iter = md.BlockIterator.init(text);
    var count: usize = 0;
    while (iter.next()) |block| {
        if (count == storage.len) break;
        storage[count] = block;
        count += 1;
    }
    return storage[0..count];
}

fn expectRun(run: Run, text: []const u8, style: md.Style) !void {
    try std.testing.expectEqualStrings(text, run.text);
    try std.testing.expectEqual(style, run.style);
}

const plain: md.Style = .{};
const bold: md.Style = .{ .bold = true };
const italic: md.Style = .{ .italic = true };
const bold_italic: md.Style = .{ .bold = true, .italic = true };
const code: md.Style = .{ .code = true };
const link: md.Style = .{ .link = true };

// ─── Builder ─────────────────────────────────────────────────────────────────

test "markdown builder defaults and copy-on-set idExtra" {
    const base = md.markdown(@src(), "hello");
    const keyed = base.idExtra(4);
    try std.testing.expectEqualStrings("hello", base.text);
    try std.testing.expectEqual(@as(usize, 0), base.id_extra);
    try std.testing.expectEqual(@as(usize, 4), keyed.id_extra);
}

// ─── Inline code chip wrap decision ─────────────────────────────────────────

test "chipNeedsBreak: fits in what's left of the line" {
    try std.testing.expect(!md.chipNeedsBreak(80, 200, 100));
}

test "chipNeedsBreak: exactly fills what's left of the line" {
    try std.testing.expect(!md.chipNeedsBreak(100, 200, 100));
}

test "chipNeedsBreak: too wide for the remainder, but nothing precedes it on the line" {
    // Already at the left edge: dropping to a fresh line would not help
    // (this chip is wider than the container itself), so it stays put and
    // wraps at its own boundaries.
    try std.testing.expect(!md.chipNeedsBreak(250, 200, 0));
}

test "chipNeedsBreak: too wide for the remainder, other content already on the line" {
    try std.testing.expect(md.chipNeedsBreak(120, 200, 100));
}

test "chipNeedsBreak: too wide even for a fresh line still forces the break" {
    // The whole-line fallback (breaking at the chip's own boundaries) applies
    // only once it lands on a fresh line; a chip that can never fit still
    // moves off content it would otherwise split.
    try std.testing.expect(md.chipNeedsBreak(500, 200, 50));
}

test "chipNeedsBreak: an unsettled (zero) container width never forces a break" {
    try std.testing.expect(!md.chipNeedsBreak(50, 0, 10));
}

// ─── Blocks ──────────────────────────────────────────────────────────────────

test "blocks: empty and whitespace-only input yield nothing" {
    var storage: [4]Block = undefined;
    try std.testing.expectEqual(@as(usize, 0), collectBlocks("", &storage).len);
    try std.testing.expectEqual(@as(usize, 0), collectBlocks("\n\n  \n\t\n", &storage).len);
}

test "blocks: a single paragraph" {
    var storage: [4]Block = undefined;
    const blocks = collectBlocks("hello world", &storage);
    try std.testing.expectEqual(@as(usize, 1), blocks.len);
    try std.testing.expectEqual(md.BlockKind.paragraph, blocks[0].kind);
    try std.testing.expectEqualStrings("hello world", blocks[0].text);
}

test "blocks: blank lines split paragraphs, single newlines stay inside" {
    var storage: [4]Block = undefined;
    const blocks = collectBlocks("a\nb\n\n\nc", &storage);
    try std.testing.expectEqual(@as(usize, 2), blocks.len);
    try std.testing.expectEqualStrings("a\nb", blocks[0].text);
    try std.testing.expectEqualStrings("c", blocks[1].text);
}

test "blocks: headings carry their level and stripped text" {
    var storage: [4]Block = undefined;
    const blocks = collectBlocks("# One\n##   Two\n### Three", &storage);
    try std.testing.expectEqual(@as(usize, 3), blocks.len);
    for (blocks, 1..) |block, level| {
        try std.testing.expectEqual(md.BlockKind.heading, block.kind);
        try std.testing.expectEqual(@as(u8, @intCast(level)), block.level);
    }
    try std.testing.expectEqualStrings("One", blocks[0].text);
    try std.testing.expectEqualStrings("Two", blocks[1].text);
    try std.testing.expectEqualStrings("Three", blocks[2].text);
}

test "blocks: four hashes and a hashtag stay literal paragraphs" {
    var storage: [4]Block = undefined;
    const blocks = collectBlocks("#### Four\n\n#tag", &storage);
    try std.testing.expectEqual(@as(usize, 2), blocks.len);
    try std.testing.expectEqual(md.BlockKind.paragraph, blocks[0].kind);
    try std.testing.expectEqualStrings("#### Four", blocks[0].text);
    try std.testing.expectEqual(md.BlockKind.paragraph, blocks[1].kind);
    try std.testing.expectEqualStrings("#tag", blocks[1].text);
}

test "blocks: a bare heading marker is an empty heading" {
    var storage: [4]Block = undefined;
    const blocks = collectBlocks("##", &storage);
    try std.testing.expectEqual(@as(usize, 1), blocks.len);
    try std.testing.expectEqual(md.BlockKind.heading, blocks[0].kind);
    try std.testing.expectEqual(@as(u8, 2), blocks[0].level);
    try std.testing.expectEqualStrings("", blocks[0].text);
}

test "blocks: dash and star bullets share the bullet marker" {
    var storage: [4]Block = undefined;
    const blocks = collectBlocks("- a\n* b", &storage);
    try std.testing.expectEqual(@as(usize, 2), blocks.len);
    for (blocks) |block| {
        try std.testing.expectEqual(md.BlockKind.bullet, block.kind);
        try std.testing.expectEqualStrings("•", block.marker);
        try std.testing.expectEqual(@as(u8, 0), block.level);
    }
    try std.testing.expectEqualStrings("a", blocks[0].text);
    try std.testing.expectEqualStrings("b", blocks[1].text);
}

test "blocks: two spaces of indent nest a list level" {
    var storage: [4]Block = undefined;
    const blocks = collectBlocks("- a\n  - b\n    - c", &storage);
    try std.testing.expectEqual(@as(usize, 3), blocks.len);
    try std.testing.expectEqual(@as(u8, 0), blocks[0].level);
    try std.testing.expectEqual(@as(u8, 1), blocks[1].level);
    try std.testing.expectEqual(@as(u8, 2), blocks[2].level);
    try std.testing.expectEqualStrings("c", blocks[2].text);
}

test "blocks: ordered items keep their number as the marker" {
    var storage: [4]Block = undefined;
    const blocks = collectBlocks("1. one\n2. two\n10. ten", &storage);
    try std.testing.expectEqual(@as(usize, 3), blocks.len);
    for (blocks) |block| try std.testing.expectEqual(md.BlockKind.ordered, block.kind);
    try std.testing.expectEqualStrings("1.", blocks[0].marker);
    try std.testing.expectEqualStrings("2.", blocks[1].marker);
    try std.testing.expectEqualStrings("10.", blocks[2].marker);
    try std.testing.expectEqualStrings("ten", blocks[2].text);
}

test "blocks: indented plain lines continue a list item, unindented ones do not" {
    var storage: [4]Block = undefined;
    const blocks = collectBlocks("- first line\n  second line\nafter", &storage);
    try std.testing.expectEqual(@as(usize, 2), blocks.len);
    try std.testing.expectEqual(md.BlockKind.bullet, blocks[0].kind);
    try std.testing.expectEqualStrings("first line\n  second line", blocks[0].text);
    try std.testing.expectEqual(md.BlockKind.paragraph, blocks[1].kind);
    try std.testing.expectEqualStrings("after", blocks[1].text);
}

test "blocks: a fenced block carries its language and body" {
    var storage: [4]Block = undefined;
    const blocks = collectBlocks("```lua\nprint(1)\nprint(2)\n```\nafter", &storage);
    try std.testing.expectEqual(@as(usize, 2), blocks.len);
    try std.testing.expectEqual(md.BlockKind.code, blocks[0].kind);
    try std.testing.expectEqualStrings("lua", blocks[0].lang);
    try std.testing.expectEqualStrings("print(1)\nprint(2)", blocks[0].text);
    try std.testing.expectEqual(md.BlockKind.paragraph, blocks[1].kind);
    try std.testing.expectEqualStrings("after", blocks[1].text);
}

test "blocks: a fence without an info string has an empty language" {
    var storage: [4]Block = undefined;
    const blocks = collectBlocks("```\nx\n```", &storage);
    try std.testing.expectEqual(@as(usize, 1), blocks.len);
    try std.testing.expectEqualStrings("", blocks[0].lang);
    try std.testing.expectEqualStrings("x", blocks[0].text);
}

test "blocks: an unterminated fence runs to the end of the text" {
    var storage: [4]Block = undefined;
    const blocks = collectBlocks("```zig\nconst a = 1;\nconst b = 2;", &storage);
    try std.testing.expectEqual(@as(usize, 1), blocks.len);
    try std.testing.expectEqual(md.BlockKind.code, blocks[0].kind);
    try std.testing.expectEqualStrings("zig", blocks[0].lang);
    try std.testing.expectEqualStrings("const a = 1;\nconst b = 2;", blocks[0].text);
}

test "blocks: empty and blank-line-preserving fences" {
    var storage: [4]Block = undefined;
    const empty = collectBlocks("```\n```", &storage);
    try std.testing.expectEqual(@as(usize, 1), empty.len);
    try std.testing.expectEqualStrings("", empty[0].text);

    const gapped = collectBlocks("```\na\n\nb\n```", &storage);
    try std.testing.expectEqual(@as(usize, 1), gapped.len);
    try std.testing.expectEqualStrings("a\n\nb", gapped[0].text);
}

test "blocks: a lone fence line is an empty code block, never a panic" {
    var storage: [4]Block = undefined;
    const blocks = collectBlocks("```", &storage);
    try std.testing.expectEqual(@as(usize, 1), blocks.len);
    try std.testing.expectEqual(md.BlockKind.code, blocks[0].kind);
    try std.testing.expectEqualStrings("", blocks[0].text);
}

test "blocks: CRLF input is handled like LF" {
    var storage: [4]Block = undefined;
    const blocks = collectBlocks("# Title\r\n\r\nbody\r\n```\r\nc\r\n```\r\n", &storage);
    try std.testing.expectEqual(@as(usize, 3), blocks.len);
    try std.testing.expectEqualStrings("Title", blocks[0].text);
    try std.testing.expectEqualStrings("body", blocks[1].text);
    try std.testing.expectEqualStrings("c", blocks[2].text);
}

test "blocks: lists and fences interrupt a paragraph" {
    var storage: [6]Block = undefined;
    const blocks = collectBlocks("text\n- item\npara\n```\nc\n```", &storage);
    try std.testing.expectEqual(@as(usize, 4), blocks.len);
    try std.testing.expectEqual(md.BlockKind.paragraph, blocks[0].kind);
    try std.testing.expectEqual(md.BlockKind.bullet, blocks[1].kind);
    try std.testing.expectEqual(md.BlockKind.paragraph, blocks[2].kind);
    try std.testing.expectEqual(md.BlockKind.code, blocks[3].kind);
}

test "blocks: decimals and star emphasis are not list markers" {
    var storage: [4]Block = undefined;
    const blocks = collectBlocks("1.5 kg of coral\n\n*italic* words\n\n-", &storage);
    try std.testing.expectEqual(@as(usize, 3), blocks.len);
    try std.testing.expectEqual(md.BlockKind.paragraph, blocks[0].kind);
    try std.testing.expectEqual(md.BlockKind.paragraph, blocks[1].kind);
    try std.testing.expectEqualStrings("*italic* words", blocks[1].text);
    // A bare dash is an empty bullet item.
    try std.testing.expectEqual(md.BlockKind.bullet, blocks[2].kind);
    try std.testing.expectEqualStrings("", blocks[2].text);
}

// ─── Inline runs ─────────────────────────────────────────────────────────────

test "inline: empty text yields no runs" {
    var storage: [4]Run = undefined;
    try std.testing.expectEqual(@as(usize, 0), collectRuns("", &storage).len);
}

test "inline: plain text is one unstyled run" {
    var storage: [4]Run = undefined;
    const runs = collectRuns("just words", &storage);
    try std.testing.expectEqual(@as(usize, 1), runs.len);
    try expectRun(runs[0], "just words", plain);
}

test "inline: bold, italic and code split the text into runs" {
    var storage: [8]Run = undefined;
    const runs = collectRuns("a **b** c *d* e `f` g", &storage);
    try std.testing.expectEqual(@as(usize, 7), runs.len);
    try expectRun(runs[0], "a ", plain);
    try expectRun(runs[1], "b", bold);
    try expectRun(runs[2], " c ", plain);
    try expectRun(runs[3], "d", italic);
    try expectRun(runs[4], " e ", plain);
    try expectRun(runs[5], "f", code);
    try expectRun(runs[6], " g", plain);
}

test "inline: a code span keeps emphasis markers literal" {
    var storage: [4]Run = undefined;
    const runs = collectRuns("`**x** [y](z)`", &storage);
    try std.testing.expectEqual(@as(usize, 1), runs.len);
    try expectRun(runs[0], "**x** [y](z)", code);
}

test "inline: double-backtick spans may contain a backtick" {
    var storage: [4]Run = undefined;
    const runs = collectRuns("``a`b``", &storage);
    try std.testing.expectEqual(@as(usize, 1), runs.len);
    try expectRun(runs[0], "a`b", code);
}

test "inline: a link renders its text and carries the url" {
    var storage: [4]Run = undefined;
    const runs = collectRuns("see [docs](https://example.test/x) now", &storage);
    try std.testing.expectEqual(@as(usize, 3), runs.len);
    try expectRun(runs[0], "see ", plain);
    try expectRun(runs[1], "docs", link);
    try std.testing.expectEqualStrings("https://example.test/x", runs[1].url);
    try expectRun(runs[2], " now", plain);
}

test "inline: a link inherits surrounding emphasis" {
    var storage: [4]Run = undefined;
    const runs = collectRuns("**see [x](u)**", &storage);
    try std.testing.expectEqual(@as(usize, 2), runs.len);
    try expectRun(runs[0], "see ", bold);
    try expectRun(runs[1], "x", .{ .bold = true, .link = true });
}

test "inline: bold containing italic" {
    var storage: [4]Run = undefined;
    const runs = collectRuns("**a *b* c**", &storage);
    try std.testing.expectEqual(@as(usize, 3), runs.len);
    try expectRun(runs[0], "a ", bold);
    try expectRun(runs[1], "b", bold_italic);
    try expectRun(runs[2], " c", bold);
}

test "inline: italic containing bold" {
    var storage: [4]Run = undefined;
    const runs = collectRuns("*a **b** c*", &storage);
    try std.testing.expectEqual(@as(usize, 3), runs.len);
    try expectRun(runs[0], "a ", italic);
    try expectRun(runs[1], "b", bold_italic);
    try expectRun(runs[2], " c", italic);
}

test "inline: triple stars open and close both styles" {
    var storage: [4]Run = undefined;
    const runs = collectRuns("***x*** y", &storage);
    try std.testing.expectEqual(@as(usize, 2), runs.len);
    try expectRun(runs[0], "x", bold_italic);
    try expectRun(runs[1], " y", plain);
}

test "inline: italic opened inside bold closes before bold" {
    var storage: [4]Run = undefined;
    const runs = collectRuns("**a *b***", &storage);
    try std.testing.expectEqual(@as(usize, 2), runs.len);
    try expectRun(runs[0], "a ", bold);
    try expectRun(runs[1], "b", bold_italic);
}

test "inline: unclosed bold is literal" {
    var storage: [4]Run = undefined;
    const runs = collectRuns("**oops", &storage);
    try std.testing.expectEqual(@as(usize, 1), runs.len);
    try expectRun(runs[0], "**oops", plain);
}

test "inline: an unclosed italic star is literal while later bold still works" {
    var storage: [4]Run = undefined;
    const runs = collectRuns("*oops and **fine**", &storage);
    try std.testing.expectEqual(@as(usize, 2), runs.len);
    try expectRun(runs[0], "*oops and ", plain);
    try expectRun(runs[1], "fine", bold);
}

test "inline: stars surrounded by spaces are literal" {
    var storage: [4]Run = undefined;
    const runs = collectRuns("2 * 3 * 6", &storage);
    try std.testing.expectEqual(@as(usize, 1), runs.len);
    try expectRun(runs[0], "2 * 3 * 6", plain);
}

test "inline: a bold closer preceded by a space does not close" {
    var storage: [4]Run = undefined;
    const runs = collectRuns("**a **", &storage);
    try std.testing.expectEqual(@as(usize, 1), runs.len);
    try expectRun(runs[0], "**a **", plain);
}

test "inline: unterminated and empty code spans are literal" {
    var storage: [4]Run = undefined;
    const open = collectRuns("a `b", &storage);
    try std.testing.expectEqual(@as(usize, 1), open.len);
    try expectRun(open[0], "a `b", plain);

    const empty = collectRuns("``", &storage);
    try std.testing.expectEqual(@as(usize, 1), empty.len);
    try expectRun(empty[0], "``", plain);
}

test "inline: brackets without a url or without text are literal" {
    var storage: [4]Run = undefined;
    const no_url = collectRuns("[x] done", &storage);
    try std.testing.expectEqual(@as(usize, 1), no_url.len);
    try expectRun(no_url[0], "[x] done", plain);

    const no_text = collectRuns("[](u)", &storage);
    try std.testing.expectEqual(@as(usize, 1), no_text.len);
    try expectRun(no_text[0], "[](u)", plain);
}

test "inline: adjacent styled runs with no plain text between them" {
    var storage: [4]Run = undefined;
    const runs = collectRuns("**a**`b`*c*", &storage);
    try std.testing.expectEqual(@as(usize, 3), runs.len);
    try expectRun(runs[0], "a", bold);
    try expectRun(runs[1], "b", code);
    try expectRun(runs[2], "c", italic);
}

test "inline: every run is a slice of the input, so nothing is dropped" {
    var storage: [16]Run = undefined;
    const text = "x **y** `z` [w](v) *q* ** ` [ end";
    const runs = collectRuns(text, &storage);
    var covered: usize = 0;
    for (runs) |run| covered += run.text.len;
    // Delimiters consumed: ** ** ` ` [ ]( ) * * = 12 bytes, plus the url "v".
    try std.testing.expectEqual(text.len - 12 - "v".len, covered);
    try expectRun(runs[runs.len - 1], " ** ` [ end", plain);
}
