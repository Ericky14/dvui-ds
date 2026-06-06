const ds = @import("dvui_ds");

var fruit: usize = 0;
var difficulty: usize = 1;
var country: usize = 0;
var size_sm: usize = 0;
var size_md: usize = 1;
var size_lg: usize = 2;
var locked: usize = 0;

const fruits = [_][]const u8{ "Apple", "Banana", "Cherry", "Date", "Elderberry" };
const difficulties = [_][]const u8{ "Easy", "Normal", "Hard", "Nightmare" };
const countries = [_][]const u8{ "Brazil", "Canada", "Denmark", "Egypt", "France" };
const sizes = [_][]const u8{ "Small", "Medium", "Large" };

pub fn draw() void {
    const theme = ds.tokens.current;

    ds.label(@src(), "Dropdown").style(.title).draw();
    ds.gap(@src(), theme.space_md);

    ds.label(@src(), "Basic").style(.secondary).font(.heading).draw();
    ds.gap(@src(), theme.space_sm);
    {
        var r = ds.row(@src()).gap(theme.space_lg).draw();
        defer r.deinit();
        _ = ds.dropdown(@src(), &fruit, &fruits).draw();
        _ = ds.dropdown(@src(), &difficulty, &difficulties).draw();
    }

    ds.gap(@src(), theme.space_lg);

    ds.label(@src(), "Placeholder").style(.secondary).font(.heading).draw();
    ds.gap(@src(), theme.space_sm);
    _ = ds.dropdown(@src(), &country, &countries).placeholder("Pick a country").draw();

    ds.gap(@src(), theme.space_lg);

    ds.label(@src(), "Sizes").style(.secondary).font(.heading).draw();
    ds.gap(@src(), theme.space_sm);
    {
        var r = ds.row(@src()).gap(theme.space_lg).draw();
        defer r.deinit();
        _ = ds.dropdown(@src(), &size_sm, &sizes).size(.sm).draw();
        _ = ds.dropdown(@src(), &size_md, &sizes).size(.md).draw();
        _ = ds.dropdown(@src(), &size_lg, &sizes).size(.lg).draw();
    }

    ds.gap(@src(), theme.space_lg);

    ds.label(@src(), "Disabled").style(.secondary).font(.heading).draw();
    ds.gap(@src(), theme.space_sm);
    _ = ds.dropdown(@src(), &locked, &fruits).disabled(true).draw();
}
