const ds = @import("dvui_ds");

var focused: bool = true;

pub fn draw() void {
    const theme = ds.tokens.current;

    ds.label(@src(), "Window Frame").style(.title).draw();
    ds.gap(@src(), theme.space_2xs);
    ds.label(@src(), "The double border around a custom-chrome window: a near-black outer ring, a white inner hairline.").style(.muted).draw();
    ds.gap(@src(), theme.space_md);

    _ = ds.checkbox(@src(), &focused).label("Window has focus").draw();
    ds.gap(@src(), theme.space_md);

    {
        var frame = ds.windowFrame(@src()).focused(focused).draw();
        defer frame.deinit();

        var body = ds.column(@src()).padding(theme.space_xl).gap(theme.space_sm).expand(.both).draw();
        defer body.deinit();
        ds.label(@src(), if (focused) "Focused" else "Unfocused").style(.primary).font(.heading).draw();
        ds.label(@src(), "Both rings are snapped to whole physical pixels, so the edge stays crisp at 1.75 as well as 1.0 and 2.0.").style(.muted).draw();
        ds.gap(@src(), theme.space_sm);
        ds.label(@src(), "Toggle the checkbox above: the inner ring dims and the window recedes.").style(.weak).draw();
    }
}
