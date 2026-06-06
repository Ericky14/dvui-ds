const ds = @import("dvui_ds");

var vol: f32 = 0.6;
var brightness: f32 = 0.3;
var locked: f32 = 0.5;
var s_sm: f32 = 0.25;
var s_md: f32 = 0.5;
var s_lg: f32 = 0.75;
var wide: f32 = 0.4;

pub fn draw() void {
    const theme = ds.tokens.current;

    ds.label(@src(), "Slider").style(.title).draw();
    ds.gap(@src(), theme.space_md);

    ds.label(@src(), "States").style(.secondary).font(.heading).draw();
    ds.gap(@src(), theme.space_sm);
    _ = ds.slider(@src(), &vol).draw();
    ds.gap(@src(), theme.space_sm);
    _ = ds.slider(@src(), &brightness).draw();
    ds.gap(@src(), theme.space_sm);
    _ = ds.slider(@src(), &locked).disabled(true).draw();

    ds.gap(@src(), theme.space_lg);

    ds.label(@src(), "Sizes").style(.secondary).font(.heading).draw();
    ds.gap(@src(), theme.space_sm);
    {
        var r = ds.row(@src()).gap(theme.space_lg).draw();
        defer r.deinit();
        _ = ds.slider(@src(), &s_sm).size(.sm).draw();
        _ = ds.slider(@src(), &s_md).size(.md).draw();
        _ = ds.slider(@src(), &s_lg).size(.lg).draw();
    }

    ds.gap(@src(), theme.space_lg);

    ds.label(@src(), "Expanding").style(.secondary).font(.heading).draw();
    ds.gap(@src(), theme.space_sm);
    _ = ds.slider(@src(), &wide).expand(.horizontal).draw();
}
