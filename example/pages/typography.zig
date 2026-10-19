const ds = @import("dvui_ds");
const dvui = @import("dvui");

pub fn draw() void {
    const theme = ds.tokens.current;

    ds.label(@src(), "Typography").style(.title).draw();
    ds.gap(@src(), theme.space_md);

    // ─── Type scale ──────────────────────────────────────────────────────────
    ds.label(@src(), "Type scale").style(.secondary).font(.heading).draw();
    ds.gap(@src(), theme.space_sm);

    ds.label(@src(), "Title — 18px Bold").style(.title).draw();
    ds.label(@src(), "Heading — 15px Bold").font(.heading).draw();
    ds.label(@src(), "Body — 13px Regular").draw();
    ds.label(@src(), "Secondary — 13px").style(.secondary).draw();
    dvui.labelNoFmt(@src(), "Muted caption — 12px", .{}, .{ .font = ds.font(theme.font_size_sm), .color_text = .{ .color = theme.text_muted } });

    ds.gap(@src(), theme.space_lg);

    // ─── Weights (Geist Regular / Medium / Bold are embedded) ────────────────
    ds.label(@src(), "Weights").style(.secondary).font(.heading).draw();
    ds.gap(@src(), theme.space_sm);
    {
        var row = ds.row(@src()).gap(theme.space_2xl).draw();
        defer row.deinit();
        dvui.labelNoFmt(@src(), "Regular", .{}, .{ .font = ds.font(theme.font_size_lg), .color_text = .{ .color = theme.text_primary } });
        dvui.labelNoFmt(@src(), "Medium", .{}, .{ .font = ds.fontMedium(theme.font_size_lg), .color_text = .{ .color = theme.text_primary } });
        dvui.labelNoFmt(@src(), "Bold", .{}, .{ .font = ds.fontBold(theme.font_size_lg), .color_text = .{ .color = theme.text_primary } });
    }

    ds.gap(@src(), theme.space_lg);

    // ─── Sizes ───────────────────────────────────────────────────────────────
    ds.label(@src(), "Sizes").style(.secondary).font(.heading).draw();
    ds.gap(@src(), theme.space_sm);
    {
        var row = ds.row(@src()).gap(theme.space_xl).draw();
        defer row.deinit();
        const steps = [_]struct { []const u8, u16 }{
            .{ "xs 11", theme.font_size_xs },
            .{ "sm 12", theme.font_size_sm },
            .{ "md 13", theme.font_size_md },
            .{ "lg 15", theme.font_size_lg },
            .{ "xl 18", theme.font_size_xl },
            .{ "2xl 22", theme.font_size_2xl },
        };
        for (steps, 0..) |step, index| {
            dvui.labelNoFmt(@src(), step[0], .{}, .{ .id_extra = index, .font = ds.font(step[1]), .color_text = .{ .color = theme.text_secondary }, .gravity_y = 1.0 });
        }
    }
}
