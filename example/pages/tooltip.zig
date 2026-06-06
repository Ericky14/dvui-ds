const ds = @import("dvui_ds");

pub fn draw() void {
    const theme = ds.tokens.current;

    ds.label(@src(), "Tooltip").style(.title).draw();
    ds.gap(@src(), theme.space_xs);
    ds.label(@src(), "Hover a trigger to reveal its tooltip.").style(.muted).draw();
    ds.gap(@src(), theme.space_md);

    ds.label(@src(), "Positions").style(.secondary).font(.heading).draw();
    ds.gap(@src(), theme.space_sm);

    {
        var trigger = ds.row(@src()).gap(theme.space_xs).padding(theme.space_sm).draw();
        defer trigger.deinit();
        ds.label(@src(), "Below (vertical)").style(.secondary).draw();
        ds.tooltip(@src(), trigger.data().rectScale().r)
            .text("Appears below the trigger.")
            .position(.vertical)
            .draw();
    }

    ds.gap(@src(), theme.space_sm);

    {
        var trigger = ds.row(@src()).gap(theme.space_xs).padding(theme.space_sm).draw();
        defer trigger.deinit();
        ds.label(@src(), "Right (horizontal)").style(.secondary).draw();
        ds.tooltip(@src(), trigger.data().rectScale().r)
            .text("Appears to the right of the trigger.")
            .position(.horizontal)
            .draw();
    }

    ds.gap(@src(), theme.space_md);

    ds.label(@src(), "On a button").style(.secondary).font(.heading).draw();
    ds.gap(@src(), theme.space_sm);

    {
        var trigger = ds.row(@src()).draw();
        defer trigger.deinit();
        _ = ds.button(@src(), "Save").variant(.filled).draw();
        ds.tooltip(@src(), trigger.data().rectScale().r)
            .text("Save your changes")
            .position(.vertical)
            .draw();
    }

    ds.gap(@src(), theme.space_md);

    ds.label(@src(), "Custom delay").style(.secondary).font(.heading).draw();
    ds.gap(@src(), theme.space_sm);

    {
        var trigger = ds.row(@src()).gap(theme.space_xs).padding(theme.space_sm).draw();
        defer trigger.deinit();
        ds.label(@src(), "Instant (no delay)").style(.secondary).draw();
        ds.tooltip(@src(), trigger.data().rectScale().r)
            .text("Shows right away.")
            .delay(0)
            .draw();
    }
}
