const ds = @import("dvui_ds");

pub fn draw() void {
    ds.label(@src(), "Labels").style(.title).draw();
    ds.gap(@src(), ds.tokens.current.space_md);

    ds.label(@src(), "Primary label").draw();
    ds.label(@src(), "Secondary label").style(.secondary).draw();
    ds.label(@src(), "Muted label").style(.muted).draw();
    ds.label(@src(), "Weak label").style(.weak).draw();
    ds.label(@src(), "Accent label").style(.accent).draw();
    ds.label(@src(), "Danger label").style(.danger).draw();
}
