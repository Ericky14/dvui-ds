const ds = @import("dvui_ds");
const dvui = @import("dvui");

pub fn draw() void {
    const theme = ds.tokens.current;

    ds.label(@src(), "Typography").style(.title).draw();
    ds.gap(@src(), theme.space_md);

    // ─── Type scale ──────────────────────────────────────────────────────────
    ds.label(@src(), "Type scale").style(.secondary).font(.heading).draw();
    ds.gap(@src(), theme.space_sm);

    ds.label(@src(), "Title — 20px Bold").style(.title).draw();
    ds.label(@src(), "Heading — 16px Bold").font(.heading).draw();
    ds.label(@src(), "Body — 13px Regular").draw();
    ds.label(@src(), "Secondary — 13px").style(.secondary).draw();
    ds.label(@src(), "Muted caption — 13px").style(.muted).draw();

    ds.gap(@src(), theme.space_lg);

    // ─── Weights (Geist Regular / Medium / Bold are embedded) ────────────────
    ds.label(@src(), "Weights").style(.secondary).font(.heading).draw();
    ds.gap(@src(), theme.space_sm);
    {
        var row = ds.row(@src()).gap(theme.space_2xl).draw();
        defer row.deinit();
        dvui.labelNoFmt(@src(), "Regular", .{}, .{ .font = ds.font(theme.font_size_lg), .color_text = theme.text_primary });
        dvui.labelNoFmt(@src(), "Medium", .{}, .{ .font = ds.fontMedium(theme.font_size_lg), .color_text = theme.text_primary });
        dvui.labelNoFmt(@src(), "Bold", .{}, .{ .font = ds.fontBold(theme.font_size_lg), .color_text = theme.text_primary });
    }

    ds.gap(@src(), theme.space_lg);

    // ─── Sizes ───────────────────────────────────────────────────────────────
    ds.label(@src(), "Sizes").style(.secondary).font(.heading).draw();
    ds.gap(@src(), theme.space_sm);
    {
        var row = ds.row(@src()).gap(theme.space_xl).draw();
        defer row.deinit();
        dvui.labelNoFmt(@src(), "sm 11", .{}, .{ .font = ds.font(theme.font_size_sm), .color_text = theme.text_secondary, .gravity_y = 1.0 });
        dvui.labelNoFmt(@src(), "md 13", .{}, .{ .font = ds.font(theme.font_size_md), .color_text = theme.text_secondary, .gravity_y = 1.0 });
        dvui.labelNoFmt(@src(), "lg 16", .{}, .{ .font = ds.font(theme.font_size_lg), .color_text = theme.text_secondary, .gravity_y = 1.0 });
        dvui.labelNoFmt(@src(), "xl 20", .{}, .{ .font = ds.font(theme.font_size_xl), .color_text = theme.text_secondary, .gravity_y = 1.0 });
    }
}
