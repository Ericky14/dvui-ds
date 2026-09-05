//! The accent candidates, side by side — the picture the colour decision was
//! made from.
//!
//! Run: `zig build screenshots` → `ds-screenshots/colors_candidates.png`.
//!
//! Four columns of the same real widgets, one per candidate accent, at 1.75 over
//! the dark theme. What is being judged is not the accent swatch — it is what
//! the accent *surfaces* look like: a selected row, an active chip, an accent
//! pill, a filled button. Those are what read as "dark blue" in the editor, and
//! they are what a hex on its own tells you nothing about.
const std = @import("std");
const dvui = @import("dvui");
const ds = @import("dvui_ds");
const shots = @import("screenshots.zig");

const Candidate = struct { name: []const u8, accent: []const u8 };

const candidates = [_]Candidate{
    .{ .name = "was 6EB5FF", .accent = "#6EB5FF" },
    .{ .name = "A 3B9DFF", .accent = "#3B9DFF" },
    .{ .name = "B 4DA6FF", .accent = "#4DA6FF" },
    .{ .name = "C 5AB0FF", .accent = "#5AB0FF" },
    .{ .name = "PICK 7CC0FF", .accent = "#7CC0FF" },
    .{ .name = "S 38BDF8", .accent = "#38BDF8" },
};

var chip_state: bool = false;

/// One column: every widget that carries the accent, under one candidate.
fn column(src: std.builtin.SourceLocation, candidate: Candidate, index: usize) void {
    const base = ds.tokens.current;
    var theme = base;
    theme.accent = .fromHex(candidate.accent);
    // Every surface is derived, so a candidate is one hex.
    theme.accent_soft = null;
    theme.accent_soft_hover = null;
    theme.accent_on_soft = null;
    ds.init(theme);
    defer ds.init(base);

    const t = ds.tokens.current;
    var col = ds.column(src).gap(t.space_sm).draw();
    defer col.deinit();

    ds.label(@src(), candidate.name).style(.muted).draw();

    // The selected tree row — the shape the owner called dark blue.
    {
        var row = dvui.box(@src(), .{ .dir = .horizontal, .gap = t.space_sm }, .{
            .background = true,
            .color_fill = .{ .color = t.accentSoft() },
            .corners = dvui.CornerRect.round(t.radius_sm),
            .padding = ds.paddingXY(t.space_sm, t.space_xs),
            .min_size_content = .{ .w = 170, .h = 0 },
        });
        defer row.deinit();
        ds.label(@src(), "coin.wav").color(t.accentOnSoft()).gravityY(0.5).draw();
    }
    // …and an unselected one, for the jump between them.
    {
        var row = dvui.box(@src(), .{ .dir = .horizontal, .gap = t.space_sm }, .{
            .background = true,
            .color_fill = .{ .color = t.surface_2 },
            .corners = dvui.CornerRect.round(t.radius_sm),
            .padding = ds.paddingXY(t.space_sm, t.space_xs),
            .min_size_content = .{ .w = 170, .h = 0 },
        });
        defer row.deinit();
        ds.label(@src(), "emissive.json").style(.secondary).gravityY(0.5).draw();
    }

    {
        var strip = ds.row(@src()).gap(t.space_2xs).draw();
        defer strip.deinit();
        _ = ds.chip(@src(), "move", ds.icons.move).state(.active).idExtra(index * 8 + 0).draw();
        _ = ds.chip(@src(), "pencil", ds.icons.pencil).state(.current).idExtra(index * 8 + 1).draw();
        _ = ds.chip(@src(), "undo", ds.icons.undo).idExtra(index * 8 + 2).draw();
    }
    {
        var strip = ds.row(@src()).gap(t.space_sm).draw();
        defer strip.deinit();
        ds.pill(@src(), "Ground · 2").tone(.accent).icon("box", ds.icons.box).idExtra(index).draw();
        ds.pill(@src(), "MCP :4141").mono(true).idExtra(index * 8 + 3).draw();
    }
    {
        var strip = ds.row(@src()).gap(t.space_sm).draw();
        defer strip.deinit();
        _ = ds.button(@src(), "Send").variant(.filled).size(.sm).icon("send", ds.icons.send).idExtra(index).draw();
        _ = ds.button(@src(), "Edit").variant(.outlined).size(.sm).idExtra(index).draw();
    }
    _ = ds.checkbox(@src(), &chip_state).label("accent tick").idExtra(index).draw();
    ds.label(@src(), "accent text").color(t.accent).draw();
    ds.label(@src(), "on-soft text").color(t.accentOnSoft()).draw();
}

fn frame() !dvui.App.Result {
    const t = ds.tokens.current;
    var page = dvui.box(@src(), .{}, .{
        .expand = .both,
        .background = true,
        .color_fill = .{ .color = t.surface_0 },
        .padding = ds.padding(t.space_lg),
    });
    defer page.deinit();

    ds.label(@src(), "accent candidates — the surfaces, not the swatch").style(.primary).font(.heading).draw();
    ds.gap(@src(), t.space_md);

    var row = ds.row(@src()).gap(t.space_lg).draw();
    defer row.deinit();
    inline for (candidates, 0..) |candidate, index| {
        // A wrapper per column so the ids inside differ: dvui extends a widget's
        // id from its parent, and every column is drawn from one `@src()`.
        var slot = dvui.box(@src(), .{}, .{ .id_extra = index });
        column(@src(), candidate, index);
        slot.deinit();
    }
    return .ok;
}

test "accent candidates" {
    chip_state = true;
    try shots.captureAt("colors_candidates.png", 1330, 320, 1.75, frame);
}

// ---------------------------------------------------------------------------
// The second decision: how far the tonal surface sits from the background.
//
// The candidate hexes above barely move the selected row, because the row is
// not the accent — it is the accent mixed most of the way to a near-black
// background. `soft_mix` is that distance, and it is the knob that decides
// whether a selected row reads as "blue" or as "dark blue".

const chosen_accent = "#7CC0FF";
const tokens_soft_mix: f32 = ds.tokens.soft_mix;
const sweep = [_]f32{ 0.64, 0.60, 0.56, 0.52 };

/// One column of the sweep: the same row at one `soft_mix`.
fn sweepColumn(src: std.builtin.SourceLocation, soft_mix: f32, index: usize) void {
    const base = ds.tokens.current;
    var theme = base;
    theme.accent = .fromHex(chosen_accent);
    theme.accent_soft = ds.mix(theme.accent, theme.surface_0, soft_mix);
    theme.accent_soft_hover = ds.mix(theme.accent, theme.surface_0, soft_mix - 0.10);
    theme.accent_on_soft = null;
    ds.init(theme);
    defer ds.init(base);

    const t = ds.tokens.current;
    var col = ds.column(src).gap(t.space_sm).draw();
    defer col.deinit();

    var name_buf: [32]u8 = undefined;
    const mark = if (soft_mix == tokens_soft_mix) " PICK" else "";
    const name = std.fmt.bufPrint(&name_buf, "soft_mix {d:.2}{s}", .{ soft_mix, mark }) catch "soft_mix";
    ds.label(@src(), name).style(.muted).draw();

    {
        var row = dvui.box(@src(), .{ .dir = .horizontal, .gap = t.space_sm }, .{
            .background = true,
            .color_fill = .{ .color = t.accentSoft() },
            .corners = dvui.CornerRect.round(t.radius_sm),
            .padding = ds.paddingXY(t.space_sm, t.space_xs),
            .min_size_content = .{ .w = 170, .h = 0 },
        });
        defer row.deinit();
        ds.label(@src(), "coin.wav").color(t.accentOnSoft()).gravityY(0.5).draw();
    }
    {
        var row = dvui.box(@src(), .{ .dir = .horizontal, .gap = t.space_sm }, .{
            .background = true,
            .color_fill = .{ .color = t.surface_2 },
            .corners = dvui.CornerRect.round(t.radius_sm),
            .padding = ds.paddingXY(t.space_sm, t.space_xs),
            .min_size_content = .{ .w = 170, .h = 0 },
        });
        defer row.deinit();
        ds.label(@src(), "emissive.json").style(.secondary).gravityY(0.5).draw();
    }
    // Only widgets that actually read the tonal surface belong here: the
    // controls moved to the solid accent and no longer vary with `soft_mix`.
    {
        var strip = ds.row(@src()).gap(t.space_sm).draw();
        defer strip.deinit();
        ds.badge(@src(), "Beta").variant(.accent).idExtra(index).draw();
        var card = dvui.box(@src(), .{ .dir = .horizontal }, .{
            .id_extra = index,
            .background = true,
            .color_fill = .{ .color = ds.mix(t.accentSoft(), t.surface_1, 0.55) },
            .corners = dvui.CornerRect.round(t.radius_sm),
            .border = dvui.Rect.all(t.border_width),
            .color_border = .{ .color = t.accent },
            .padding = ds.paddingXY(t.space_sm, t.space_xs),
        });
        defer card.deinit();
        ds.label(@src(), "approval").style(.secondary).gravityY(0.5).draw();
    }
}

fn sweepFrame() !dvui.App.Result {
    const t = ds.tokens.current;
    var page = dvui.box(@src(), .{}, .{
        .expand = .both,
        .background = true,
        .color_fill = .{ .color = t.surface_0 },
        .padding = ds.padding(t.space_lg),
    });
    defer page.deinit();

    ds.label(@src(), "how far the tonal surface sits from the background").style(.primary).font(.heading).draw();
    ds.gap(@src(), t.space_md);

    var row = ds.row(@src()).gap(t.space_lg).draw();
    defer row.deinit();
    inline for (sweep, 0..) |soft_mix, index| {
        var slot = dvui.box(@src(), .{}, .{ .id_extra = index });
        sweepColumn(@src(), soft_mix, index);
        slot.deinit();
    }
    return .ok;
}

test "accent soft-mix sweep" {
    chip_state = true;
    try shots.captureAt("colors_soft_mix.png", 830, 270, 1.75, sweepFrame);
}

// ---------------------------------------------------------------------------
// The palette itself, as a fixture: the five derived accent surfaces with their
// hexes, so a future change to a mix constant shows up as a picture diff and
// not only as a number in a test.

/// One labelled swatch: the colour, its token name, its hex.
fn paletteSwatch(name: []const u8, value: dvui.Color, index: usize) void {
    const t = ds.tokens.current;
    var col = dvui.box(@src(), .{ .dir = .vertical, .gap = t.space_3xs }, .{ .id_extra = index });
    defer col.deinit();
    {
        var chip_box = dvui.box(@src(), .{}, .{
            .id_extra = index,
            .min_size_content = .{ .w = 132, .h = 52 },
            .background = true,
            .color_fill = .{ .color = value },
            .corners = dvui.CornerRect.round(t.radius_md),
            .border = dvui.Rect.all(t.border_width),
            .color_border = .{ .color = t.border },
        });
        chip_box.deinit();
    }
    dvui.labelNoFmt(@src(), name, .{}, .{
        .id_extra = index,
        .color_text = .{ .color = t.text_secondary },
        .font = ds.font(t.font_size_sm),
    });
    var hex_buf: [8]u8 = undefined;
    const hex = std.fmt.bufPrint(&hex_buf, "#{X:0>2}{X:0>2}{X:0>2}", .{ value.r, value.g, value.b }) catch "#??????";
    dvui.labelNoFmt(@src(), hex, .{}, .{
        .id_extra = index,
        .color_text = .{ .color = t.text_muted },
        .font = ds.fontMono(t.font_size_sm),
    });
}

fn paletteFrame() !dvui.App.Result {
    const t = ds.tokens.current;
    var page = dvui.box(@src(), .{}, .{
        .expand = .both,
        .background = true,
        .color_fill = .{ .color = t.surface_0 },
        .padding = ds.padding(t.space_lg),
    });
    defer page.deinit();

    ds.label(@src(), "accent surfaces — derived from one hex").style(.primary).font(.heading).draw();
    ds.gap(@src(), t.space_md);
    {
        var strip = ds.row(@src()).gap(t.space_md).draw();
        defer strip.deinit();
        paletteSwatch("accent", t.accent, 0);
        paletteSwatch("accentSoft", t.accentSoft(), 1);
        paletteSwatch("accentSoftHover", t.accentSoftHover(), 2);
        paletteSwatch("accentOnSoft", t.accentOnSoft(), 3);
        paletteSwatch("accentHover", t.accentHover(), 4);
        paletteSwatch("accentPressed", t.accentPressed(), 5);
    }
    return .ok;
}

test "accent palette" {
    try shots.captureAt("colors_accent.png", 900, 200, 1.75, paletteFrame);
}
