const ds = @import("dvui_ds");

pub fn draw() void {
    const theme = ds.tokens.current;

    ds.label(@src(), "Card").style(.title).draw();
    ds.gap(@src(), theme.space_md);

    ds.label(@src(), "Variants").style(.secondary).font(.heading).draw();
    ds.gap(@src(), theme.space_sm);

    {
        var r = ds.row(@src()).gap(theme.space_md).draw();
        defer r.deinit();

        {
            var c = ds.card(@src()).variant(.elevated).draw();
            defer c.deinit();
            ds.label(@src(), "Elevated").style(.secondary).font(.heading).draw();
            ds.gap(@src(), theme.space_xs);
            ds.label(@src(), "Lifted with a soft shadow.").style(.muted).draw();
        }
        {
            var c = ds.card(@src()).variant(.filled).draw();
            defer c.deinit();
            ds.label(@src(), "Filled").style(.secondary).font(.heading).draw();
            ds.gap(@src(), theme.space_xs);
            ds.label(@src(), "Tonal surface, flat.").style(.muted).draw();
        }
        {
            var c = ds.card(@src()).variant(.outlined).draw();
            defer c.deinit();
            ds.label(@src(), "Outlined").style(.secondary).font(.heading).draw();
            ds.gap(@src(), theme.space_xs);
            ds.label(@src(), "Bordered, no shadow.").style(.muted).draw();
        }
    }
}
