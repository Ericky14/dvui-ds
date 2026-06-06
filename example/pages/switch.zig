const ds = @import("dvui_ds");

var wifi: bool = true;
var bluetooth: bool = false;
var locked_on: bool = true;
var locked_off: bool = false;
var sw_sm: bool = true;
var sw_md: bool = true;
var sw_lg: bool = true;

pub fn draw() void {
    const theme = ds.tokens.current;

    ds.label(@src(), "Switch").style(.title).draw();
    ds.gap(@src(), theme.space_md);

    ds.label(@src(), "States").style(.secondary).font(.heading).draw();
    ds.gap(@src(), theme.space_sm);
    _ = ds.toggle(@src(), &wifi).label("Wi-Fi").draw();
    _ = ds.toggle(@src(), &bluetooth).label("Bluetooth").draw();
    _ = ds.toggle(@src(), &locked_on).label("Disabled (on)").disabled(true).draw();
    _ = ds.toggle(@src(), &locked_off).label("Disabled (off)").disabled(true).draw();

    ds.gap(@src(), theme.space_lg);

    ds.label(@src(), "Sizes").style(.secondary).font(.heading).draw();
    ds.gap(@src(), theme.space_sm);
    {
        var sizes = ds.row(@src()).gap(theme.space_lg).draw();
        defer sizes.deinit();
        _ = ds.toggle(@src(), &sw_sm).size(.sm).label("Small").draw();
        _ = ds.toggle(@src(), &sw_md).size(.md).label("Medium").draw();
        _ = ds.toggle(@src(), &sw_lg).size(.lg).label("Large").draw();
    }
}
