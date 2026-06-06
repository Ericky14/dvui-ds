const ds = @import("dvui_ds");

var basic_open: bool = false;
var wide_open: bool = false;

pub fn draw() void {
    const theme = ds.tokens.current;

    ds.label(@src(), "Modal").style(.title).draw();
    ds.gap(@src(), theme.space_md);

    ds.label(@src(), "Dialog").style(.secondary).font(.heading).draw();
    ds.gap(@src(), theme.space_sm);
    ds.label(@src(), "A centered, modal dialog over a dimmed scrim.").style(.muted).draw();
    ds.gap(@src(), theme.space_md);

    {
        var row = ds.row(@src()).gap(theme.space_sm).draw();
        defer row.deinit();
        if (ds.button(@src(), "Open dialog").variant(.filled).draw()) basic_open = true;
        if (ds.button(@src(), "Open wide dialog").variant(.outlined).draw()) wide_open = true;
    }

    if (ds.modal(@src(), &basic_open).title("Delete file?").draw()) |dialog| {
        defer dialog.deinit();

        ds.label(@src(), "This action cannot be undone.").style(.muted).draw();
        ds.gap(@src(), theme.space_lg);

        var actions = ds.row(@src()).gap(theme.space_sm).draw();
        defer actions.deinit();
        if (ds.button(@src(), "Cancel").variant(.ghost).draw()) basic_open = false;
        if (ds.button(@src(), "Delete").variant(.danger).draw()) basic_open = false;
    }

    if (ds.modal(@src(), &wide_open).title("Welcome aboard").width(480).draw()) |dialog| {
        defer dialog.deinit();

        ds.label(@src(), "A wider dialog for longer content. Use the width setter to fit your message and actions comfortably.").style(.muted).draw();
        ds.gap(@src(), theme.space_lg);

        if (ds.button(@src(), "Close").variant(.filled).draw()) wide_open = false;
    }
}
