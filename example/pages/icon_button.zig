const ds = @import("dvui_ds");

pub fn draw() void {
    const theme = ds.tokens.current;

    ds.label(@src(), "Icon Button").style(.title).draw();
    ds.gap(@src(), theme.space_md);

    // Variants
    {
        var r = ds.row(@src()).gap(theme.space_sm).draw();
        defer r.deinit();

        _ = ds.iconButton(@src(), "cog", ds.icons.cog).variant(.filled).size(.md).draw();
        _ = ds.iconButton(@src(), "copy", ds.icons.copy).variant(.outlined).size(.md).draw();
        _ = ds.iconButton(@src(), "bell", ds.icons.bell).variant(.ghost).size(.md).draw();
        _ = ds.iconButton(@src(), "delete", ds.icons.delete).variant(.danger).size(.md).draw();
        _ = ds.iconButton(@src(), "bot", ds.icons.bot).variant(.accent_ghost).size(.md).draw();
    }

    ds.gap(@src(), theme.space_lg);

    // Sizes
    ds.label(@src(), "Sizes").style(.secondary).font(.heading).draw();
    ds.gap(@src(), theme.space_sm);
    {
        var r = ds.row(@src()).gap(theme.space_sm).draw();
        defer r.deinit();

        _ = ds.iconButton(@src(), "download", ds.icons.download).variant(.outlined).size(.sm).draw();
        _ = ds.iconButton(@src(), "download", ds.icons.download).variant(.outlined).size(.md).draw();
        _ = ds.iconButton(@src(), "download", ds.icons.download).variant(.outlined).size(.lg).draw();
    }

    ds.gap(@src(), theme.space_lg);

    // States
    ds.label(@src(), "States").style(.secondary).font(.heading).draw();
    ds.gap(@src(), theme.space_sm);
    {
        var r = ds.row(@src()).gap(theme.space_sm).draw();
        defer r.deinit();

        _ = ds.iconButton(@src(), "check", ds.icons.check).variant(.filled).size(.md).draw();
        _ = ds.iconButton(@src(), "check", ds.icons.check).variant(.filled).size(.md).disabled(true).draw();
        _ = ds.iconButton(@src(), "save", ds.icons.save).variant(.filled).size(.md).loading(true).draw();
    }
}
