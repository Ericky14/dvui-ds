const ds = @import("dvui_ds");
const sample_image = @import("sample_image.zig");

pub fn draw() void {
    const theme = ds.tokens.current;

    ds.label(@src(), "Buttons").style(.title).draw();
    ds.gap(@src(), theme.space_md);

    // Row of button variants
    {
        var r = ds.row(@src()).gap(theme.space_sm).draw();
        defer r.deinit();

        _ = ds.button(@src(), "Primary").variant(.filled).size(.md).draw();
        _ = ds.button(@src(), "Secondary").variant(.outlined).size(.md).draw();
        _ = ds.button(@src(), "Ghost").variant(.ghost).size(.md).draw();
        _ = ds.button(@src(), "Delete").variant(.danger).size(.md).draw();
        _ = ds.button(@src(), "AI").variant(.accent_ghost).size(.md).draw();
    }

    ds.gap(@src(), theme.space_lg);

    // Row of button sizes
    {
        var r = ds.row(@src()).gap(theme.space_sm).draw();
        defer r.deinit();

        _ = ds.button(@src(), "Small").variant(.filled).size(.sm).draw();
        _ = ds.button(@src(), "Medium").variant(.filled).size(.md).draw();
        _ = ds.button(@src(), "Large").variant(.filled).size(.lg).draw();
    }

    ds.gap(@src(), theme.space_lg);

    // States
    ds.label(@src(), "States").style(.secondary).font(.heading).draw();
    ds.gap(@src(), theme.space_sm);

    {
        var r = ds.row(@src()).gap(theme.space_sm).draw();
        defer r.deinit();

        _ = ds.button(@src(), "Save").variant(.filled).size(.md).draw();
        _ = ds.button(@src(), "Save").variant(.filled).size(.md).icon("save", ds.icons.save).iconFirst().draw();
        _ = ds.button(@src(), "Save").variant(.filled).size(.md).disabled(true).draw();
        _ = ds.button(@src(), "Saving").variant(.filled).size(.md).loading(true).draw();
    }

    ds.gap(@src(), theme.space_lg);

    // Raster-image source (image-only and image + label)
    ds.label(@src(), "Image source").style(.secondary).font(.heading).draw();
    ds.gap(@src(), theme.space_sm);
    {
        var r = ds.row(@src()).gap(theme.space_sm).draw();
        defer r.deinit();
        _ = ds.button(@src(), "").source(sample_image.source()).variant(.outlined).size(.md).draw();
        _ = ds.button(@src(), "Photo").source(sample_image.source()).iconFirst().variant(.filled).size(.md).draw();
    }
}
