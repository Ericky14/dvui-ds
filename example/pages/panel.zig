const ds = @import("dvui_ds");

pub fn draw() void {
    ds.label(@src(), "Panel").style(.title).draw();
    ds.gap(@src(), ds.tokens.current.space_md);

    {
        var panel_widget = ds.panel(@src()).draw();
        defer panel_widget.deinit();

        {
            var header = ds.panelHeader(@src()).draw();
            defer header.deinit();
            ds.label(@src(), "Panel Header").style(.secondary).draw();
        }

        ds.label(@src(), "Panel body content goes here.").style(.muted).draw();
    }
}
