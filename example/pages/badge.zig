const ds = @import("dvui_ds");

pub fn draw() void {
    const theme = ds.tokens.current;

    ds.label(@src(), "Badge").style(.title).draw();
    ds.gap(@src(), theme.space_md);

    ds.label(@src(), "Variants").style(.secondary).font(.heading).draw();
    ds.gap(@src(), theme.space_sm);
    {
        var r = ds.row(@src()).gap(theme.space_sm).draw();
        defer r.deinit();
        ds.badge(@src(), "New").variant(.neutral).draw();
        ds.badge(@src(), "Beta").variant(.accent).draw();
        ds.badge(@src(), "Error").variant(.danger).draw();
    }

    ds.gap(@src(), theme.space_lg);

    ds.label(@src(), "Counts").style(.secondary).font(.heading).draw();
    ds.gap(@src(), theme.space_sm);
    {
        var r = ds.row(@src()).gap(theme.space_sm).draw();
        defer r.deinit();
        ds.badge(@src(), "3").variant(.accent).draw();
        ds.badge(@src(), "12").variant(.neutral).draw();
        ds.badge(@src(), "99+").variant(.danger).draw();
    }

    ds.gap(@src(), theme.space_lg);

    ds.label(@src(), "Dots").style(.secondary).font(.heading).draw();
    ds.gap(@src(), theme.space_sm);
    {
        var r = ds.row(@src()).gap(theme.space_md).draw();
        defer r.deinit();
        ds.badge(@src(), "").dot(true).variant(.neutral).draw();
        ds.badge(@src(), "").dot(true).variant(.accent).draw();
        ds.badge(@src(), "").dot(true).variant(.danger).draw();
    }
}
