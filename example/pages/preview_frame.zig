const std = @import("std");
const dvui = @import("dvui");
const ds = @import("dvui_ds");
const chrome = @import("editor_chrome.zig");

var show_vignette: bool = true;

pub fn draw() void {
    const theme = ds.tokens.current;

    ds.label(@src(), "Preview Frame").style(.title).draw();
    ds.gap(@src(), theme.space_2xs);
    ds.label(@src(), "A gutter, a rounded corner, an inner vignette and a hairline over the picture's own edge.").style(.muted).draw();
    ds.gap(@src(), theme.space_md);

    _ = ds.checkbox(@src(), &show_vignette).label("Vignette").draw();
    ds.gap(@src(), theme.space_md);

    var stage = dvui.box(@src(), .{}, .{ .expand = .horizontal, .min_size_content = .{ .h = 300 } });
    {
        var preview = ds.previewFrame(@src())
            .vignette(if (show_vignette) theme.preview_vignette_alpha else 0)
            .draw();
        chrome.picture(@src(), preview.corners());

        // `toolbarRect` / `statusRect` hand out the slots along the picture's
        // edges; they are what a floating glass bar is positioned with.
        const bar = preview.toolbarRect(200, theme.chrome_toolbar_height);
        const pills = preview.statusRect(200, theme.chrome_toolbar_height);
        preview.deinit();

        {
            var toolbar = ds.glass(@src()).rect(bar).solid(true).horizontal().gap(theme.space_2xs).padding(theme.space_2xs).radius(theme.radius_md).draw();
            defer toolbar.deinit();
            _ = ds.chip(@src(), "play", ds.icons.play).idExtra(0).draw();
            _ = ds.chip(@src(), "pause", ds.icons.pause).idExtra(1).draw();
            _ = ds.chip(@src(), "move", ds.icons.move).state(.active).idExtra(2).draw();
        }
        {
            var status = ds.glass(@src()).rect(pills).solid(true).horizontal().gap(theme.space_sm).padding(theme.space_xs).radius(theme.radius_md).draw();
            defer status.deinit();
            ds.pill(@src(), "Ground · 2").tone(.accent).icon("box", ds.icons.box).draw();
            ds.pill(@src(), "60 fps").mono(true).draw();
        }
    }
    stage.deinit();
}
