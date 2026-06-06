const ds = @import("dvui_ds");

var accept: bool = true;
var newsletter: bool = false;
var locked: bool = true;
var s_sm: bool = true;
var s_md: bool = true;
var s_lg: bool = true;

pub fn draw() void {
    const theme = ds.tokens.current;

    ds.label(@src(), "Checkbox").style(.title).draw();
    ds.gap(@src(), theme.space_md);

    ds.label(@src(), "States").style(.secondary).font(.heading).draw();
    ds.gap(@src(), theme.space_sm);
    _ = ds.checkbox(@src(), &accept).label("I accept the terms").draw();
    _ = ds.checkbox(@src(), &newsletter).label("Subscribe to the newsletter").draw();
    _ = ds.checkbox(@src(), &locked).label("Disabled").disabled(true).draw();

    ds.gap(@src(), theme.space_lg);

    ds.label(@src(), "Sizes").style(.secondary).font(.heading).draw();
    ds.gap(@src(), theme.space_sm);
    {
        var r = ds.row(@src()).gap(theme.space_lg).draw();
        defer r.deinit();
        _ = ds.checkbox(@src(), &s_sm).size(.sm).label("Small").draw();
        _ = ds.checkbox(@src(), &s_md).size(.md).label("Medium").draw();
        _ = ds.checkbox(@src(), &s_lg).size(.lg).label("Large").draw();
    }
}
