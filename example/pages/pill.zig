const ds = @import("dvui_ds");

pub fn draw() void {
    const theme = ds.tokens.current;

    ds.label(@src(), "Pill").style(.title).draw();
    ds.gap(@src(), theme.space_2xs);
    ds.label(@src(), "A fully rounded readout: state you are told, never state you press.").style(.muted).draw();
    ds.gap(@src(), theme.space_lg);

    ds.label(@src(), "Tones").style(.secondary).font(.heading).draw();
    ds.gap(@src(), theme.space_sm);
    {
        var row = ds.row(@src()).gap(theme.space_sm).draw();
        defer row.deinit();
        ds.pill(@src(), "neutral").draw();
        ds.pill(@src(), "accent").tone(.accent).draw();
        ds.pill(@src(), "danger").tone(.danger).draw();
    }

    ds.gap(@src(), theme.space_xl);
    ds.label(@src(), "With a leading icon").style(.secondary).font(.heading).draw();
    ds.gap(@src(), theme.space_sm);
    {
        var row = ds.row(@src()).gap(theme.space_sm).draw();
        defer row.deinit();
        ds.pill(@src(), "Ground · 2").tone(.accent).icon("box", ds.icons.box).draw();
        ds.pill(@src(), "7 entities").icon("layers", ds.icons.layers).draw();
        ds.pill(@src(), "3 errors").tone(.danger).icon("triangle-alert", ds.icons.triangle_alert).draw();
    }

    ds.gap(@src(), theme.space_xl);
    ds.label(@src(), "Mono, for numbers that change every frame").style(.secondary).font(.heading).draw();
    ds.gap(@src(), theme.space_sm);
    {
        var row = ds.row(@src()).gap(theme.space_sm).draw();
        defer row.deinit();
        ds.pill(@src(), "60 fps").mono(true).draw();
        ds.pill(@src(), "16.7 ms").mono(true).draw();
        ds.pill(@src(), "MCP :4141").mono(true).draw();
    }
    ds.gap(@src(), theme.space_sm);
    ds.label(@src(), "Mono keeps the digits the same width, so the pill stops twitching as they change.").style(.weak).draw();
}
