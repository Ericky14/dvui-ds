const ds = @import("dvui_ds");

pub fn draw() void {
    const theme = ds.tokens.current;

    ds.label(@src(), "Toolbar").style(.title).draw();
    ds.gap(@src(), theme.space_xs);
    ds.label(@src(), "A horizontal bar of icon-button tools.").style(.muted).draw();
    ds.gap(@src(), theme.space_md);

    var tb = ds.toolbar(@src()).draw();
    defer tb.deinit();

    _ = ds.iconButton(@src(), "save", ds.icons.save).variant(.ghost).draw();
    _ = ds.iconButton(@src(), "copy", ds.icons.copy).variant(.ghost).draw();
    _ = ds.iconButton(@src(), "pencil", ds.icons.pencil).variant(.ghost).draw();
    _ = ds.iconButton(@src(), "search", ds.icons.search).variant(.ghost).draw();

    ds.gapH(@src(), theme.space_md);

    _ = ds.iconButton(@src(), "settings", ds.icons.settings).variant(.ghost).draw();
    _ = ds.iconButton(@src(), "trash", ds.icons.trash_2).variant(.danger).draw();
}
