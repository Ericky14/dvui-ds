const ds = @import("dvui_ds");

pub fn draw() void {
    ds.label(@src(), "Coming soon...").style(.muted).draw();
}
