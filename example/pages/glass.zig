const std = @import("std");
const dvui = @import("dvui");
const ds = @import("dvui_ds");
const chrome = @import("editor_chrome.zig");

/// 0–1 slider position; mapped to a 4–48 px blur radius below.
var blur_fraction: f32 = 0.45;
var reduced_transparency: bool = false;

pub fn draw() void {
    const theme = ds.tokens.current;

    ds.label(@src(), "Glass").style(.title).draw();
    ds.gap(@src(), theme.space_2xs);
    ds.label(@src(), "A translucent surface over a blurred copy of what is behind it.").style(.muted).draw();
    ds.gap(@src(), theme.space_md);

    const blur_radius = 4 + blur_fraction * 44;
    {
        var controls = ds.row(@src()).gap(theme.space_lg).draw();
        defer controls.deinit();
        ds.label(@src(), "Blur radius").style(.muted).gravityY(0.5).draw();
        _ = ds.slider(@src(), &blur_fraction).draw();
        _ = ds.checkbox(@src(), &reduced_transparency).label("Reduced transparency").draw();
    }
    ds.gap(@src(), theme.space_md);

    // The stage has to be a real rect in window coordinates: a glass overlay
    // floats in its own subwindow, so it is positioned, not laid out.
    var stage = dvui.box(@src(), .{}, .{
        .expand = .horizontal,
        .min_size_content = .{ .h = 260 },
    });
    const area = dvui.windowRectScale().rectFromPhysical(stage.data().contentRectScale().r);

    const scene = ds.glassScene(@src()).rect(area).blur(blur_radius).witness(@intFromFloat(blur_radius)).begin();
    chrome.picture(@src(), dvui.CornerRect.round(theme.preview_radius));

    const panel: dvui.Rect = .{
        .x = area.x + area.w * 0.08,
        .y = area.y + area.h * 0.30,
        .w = @max(120, area.w * 0.36),
        .h = @max(90, area.h * 0.46),
    };
    {
        var surface = ds.glass(@src())
            .rect(panel)
            .scene(scene)
            .solid(reduced_transparency)
            .gap(theme.space_2xs)
            .draw();
        defer surface.deinit();
        ds.label(@src(), "Inspect").style(.primary).font(.heading).draw();
        ds.label(@src(), "Text on glass uses .secondary or .primary.").style(.secondary).draw();
    }
    {
        const bar_width = @max(160.0, area.w * 0.34);
        var bar = ds.glass(@src())
            .rect(.{
                .x = area.x + area.w - bar_width - theme.space_lg,
                .y = area.y + theme.space_lg,
                .w = bar_width,
                .h = theme.chrome_toolbar_height,
            })
            .scene(scene)
            .solid(reduced_transparency)
            .horizontal()
            .gap(theme.space_2xs)
            .padding(theme.space_2xs)
            .radius(theme.radius_md)
            .draw();
        defer bar.deinit();
        _ = ds.chip(@src(), "play", ds.icons.play).idExtra(0).draw();
        _ = ds.chip(@src(), "pause", ds.icons.pause).idExtra(1).draw();
        _ = ds.chip(@src(), "move", ds.icons.move).state(.active).idExtra(2).draw();
        _ = ds.chip(@src(), "globe", ds.icons.globe).idExtra(3).draw();
    }
    scene.end();
    stage.deinit();

    ds.gap(@src(), theme.space_md);
    ds.label(@src(), "Inline (no rect, so no blur — just the glass tint, hairline and edge highlight)").style(.muted).draw();
    ds.gap(@src(), theme.space_sm);
    {
        var composer = ds.glass(@src()).horizontal().gap(theme.space_sm).expand(.horizontal).padding(theme.space_sm).radius(theme.radius_md).draw();
        defer composer.deinit();
        chrome.glyph(@src(), "paperclip", ds.icons.paperclip, .muted);
        ds.label(@src(), "@ / Ask for anything…").style(.weak).gravityY(0.5).draw();
        chrome.stretch(@src());
        _ = ds.button(@src(), "Send").variant(.filled).icon("send", ds.icons.send).draw();
    }
}
