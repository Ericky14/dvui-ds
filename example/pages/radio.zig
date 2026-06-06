const ds = @import("dvui_ds");

var choice: usize = 0;
var size_choice: usize = 1;

pub fn draw() void {
    const theme = ds.tokens.current;

    ds.label(@src(), "Radio").style(.title).draw();
    ds.gap(@src(), theme.space_md);

    ds.label(@src(), "Group").style(.secondary).font(.heading).draw();
    ds.gap(@src(), theme.space_sm);
    if (ds.radio(@src(), choice == 0, "Option A").draw()) choice = 0;
    if (ds.radio(@src(), choice == 1, "Option B").draw()) choice = 1;
    if (ds.radio(@src(), choice == 2, "Option C").draw()) choice = 2;
    if (ds.radio(@src(), choice == 3, "Disabled").disabled(true).draw()) choice = 3;

    ds.gap(@src(), theme.space_lg);

    ds.label(@src(), "Sizes").style(.secondary).font(.heading).draw();
    ds.gap(@src(), theme.space_sm);
    {
        var row = ds.row(@src()).gap(theme.space_lg).draw();
        defer row.deinit();
        if (ds.radio(@src(), size_choice == 0, "Small").size(.sm).draw()) size_choice = 0;
        if (ds.radio(@src(), size_choice == 1, "Medium").size(.md).draw()) size_choice = 1;
        if (ds.radio(@src(), size_choice == 2, "Large").size(.lg).draw()) size_choice = 2;
    }
}
