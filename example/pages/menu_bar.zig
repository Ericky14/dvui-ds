const ds = @import("dvui_ds");

pub fn draw() void {
    const theme = ds.tokens.current;

    ds.label(@src(), "Menu Bar").style(.title).draw();
    ds.gap(@src(), theme.space_xs);
    ds.label(@src(), "Click a top-level item to open its menu.").style(.muted).draw();
    ds.gap(@src(), theme.space_md);

    var bar = ds.menuBar(@src()).draw();
    defer bar.deinit();

    if (ds.menuItem(@src(), "File").submenu().draw()) |r| {
        var fw = ds.floatingMenu(@src(), r);
        defer fw.deinit();
        if (ds.menuItem(@src(), "New").draw() != null) fw.close();
        if (ds.menuItem(@src(), "Open").draw() != null) fw.close();
        if (ds.menuItem(@src(), "Save").draw() != null) fw.close();
        if (ds.menuItem(@src(), "Quit").draw() != null) fw.close();
    }

    if (ds.menuItem(@src(), "Edit").submenu().draw()) |r| {
        var fw = ds.floatingMenu(@src(), r);
        defer fw.deinit();
        if (ds.menuItem(@src(), "Undo").draw() != null) fw.close();
        if (ds.menuItem(@src(), "Redo").draw() != null) fw.close();
        if (ds.menuItem(@src(), "Cut").draw() != null) fw.close();
        if (ds.menuItem(@src(), "Copy").draw() != null) fw.close();
        if (ds.menuItem(@src(), "Paste").draw() != null) fw.close();
    }

    if (ds.menuItem(@src(), "View").submenu().draw()) |r| {
        var fw = ds.floatingMenu(@src(), r);
        defer fw.deinit();
        if (ds.menuItem(@src(), "Zoom In").draw() != null) fw.close();
        if (ds.menuItem(@src(), "Zoom Out").draw() != null) fw.close();
        if (ds.menuItem(@src(), "Reset Zoom").draw() != null) fw.close();
    }
}
