const ds = @import("dvui_ds");
const dvui = @import("dvui");

/// A color swatch + token name. `idx` disambiguates the (shared) call site.
fn swatch(idx: usize, name: []const u8, color: dvui.Color) void {
    const theme = ds.tokens.current;
    var col = dvui.box(@src(), .{ .dir = .vertical, .gap = theme.space_3xs }, .{ .id_extra = idx });
    defer col.deinit();
    {
        var sw = dvui.box(@src(), .{}, .{
            .id_extra = idx,
            .min_size_content = .{ .w = 84, .h = 44 },
            .background = true,
            .color_fill = color,
            .corner_radius = dvui.Rect.all(theme.radius_md),
            .border = dvui.Rect.all(theme.border_width),
            .color_border = theme.border,
        });
        sw.deinit();
    }
    dvui.labelNoFmt(@src(), name, .{}, .{
        .id_extra = idx,
        .color_text = theme.text_muted,
        .font = ds.font(theme.font_size_sm),
    });
}

pub fn draw() void {
    const theme = ds.tokens.current;

    ds.label(@src(), "Colors").style(.title).draw();
    ds.gap(@src(), theme.space_md);

    ds.label(@src(), "Surfaces").style(.secondary).font(.heading).draw();
    ds.gap(@src(), theme.space_sm);
    {
        var row = ds.row(@src()).gap(theme.space_sm).draw();
        defer row.deinit();
        swatch(0, "surface_0", theme.surface_0);
        swatch(1, "surface_1", theme.surface_1);
        swatch(2, "surface_2", theme.surface_2);
        swatch(3, "surface_3", theme.surface_3);
        swatch(4, "surface_4", theme.surface_4);
    }

    ds.gap(@src(), theme.space_lg);
    ds.label(@src(), "Text").style(.secondary).font(.heading).draw();
    ds.gap(@src(), theme.space_sm);
    {
        var row = ds.row(@src()).gap(theme.space_sm).draw();
        defer row.deinit();
        swatch(10, "text_primary", theme.text_primary);
        swatch(11, "text_secondary", theme.text_secondary);
        swatch(12, "text_muted", theme.text_muted);
        swatch(13, "text_ghost", theme.text_ghost);
    }

    ds.gap(@src(), theme.space_lg);
    ds.label(@src(), "Accent & destructive").style(.secondary).font(.heading).draw();
    ds.gap(@src(), theme.space_sm);
    {
        var row = ds.row(@src()).gap(theme.space_sm).draw();
        defer row.deinit();
        swatch(20, "accent", theme.accent);
        swatch(21, "accent_muted", theme.accent_muted);
        swatch(22, "destructive", theme.destructive);
        swatch(23, "destructive_muted", theme.destructive_muted);
    }

    ds.gap(@src(), theme.space_lg);
    ds.label(@src(), "Borders").style(.secondary).font(.heading).draw();
    ds.gap(@src(), theme.space_sm);
    {
        var row = ds.row(@src()).gap(theme.space_sm).draw();
        defer row.deinit();
        swatch(30, "border", theme.border);
        swatch(31, "border_subtle", theme.border_subtle);
        swatch(32, "border_input", theme.border_input);
        swatch(33, "border_strong", theme.border_strong);
    }
}
