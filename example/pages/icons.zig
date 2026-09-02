const ds = @import("dvui_ds");
const dvui = @import("dvui");
const sample_image = @import("sample_image.zig");

/// Draw one icon + its name in a fixed-width cell. `src` (passed from the call
/// site) keeps each cell's id unique.
fn cell(src: @import("std").builtin.SourceLocation, comptime name: [:0]const u8, svg: []const u8) void {
    const theme = ds.tokens.current;
    // Fixed-width vertical cell. NOTE: no gravity_x on this box — it's a child of
    // a horizontal row, and 0<gravity_x<1 there makes dvui treat it as a
    // positioned overlay (all cells stack at the same spot). Centering of the
    // icon/label happens via gravity_x on the col's own (vertical) children.
    var col = dvui.box(src, .{ .dir = .vertical, .gap = theme.space_2xs }, .{ .min_size_content = .{ .w = 80 } });
    defer col.deinit();
    {
        // Wrapper centers the icon horizontally within the cell (gravity_x here
        // is the cross axis of the vertical col, so it doesn't overlay).
        var ic = dvui.box(@src(), .{}, .{ .gravity_x = 0.5 });
        defer ic.deinit();
        if (ds.icons.resolve(name, svg)) |resolved| {
            ds.iconTvg(@src(), resolved.name, resolved.tvg_bytes).size(.lg).style(.secondary).draw();
        }
    }
    dvui.labelNoFmt(@src(), name, .{}, .{ .color_text = .{ .color = theme.text_ghost }, .font = ds.font(theme.font_size_sm), .gravity_x = 0.5 });
}

pub fn draw() void {
    const theme = ds.tokens.current;

    ds.label(@src(), "Icons").style(.title).draw();
    ds.gap(@src(), theme.space_xs);
    ds.label(@src(), "Lucide icon set (1700+). A sampling below.").style(.muted).draw();
    ds.gap(@src(), theme.space_md);

    {
        var r = ds.row(@src()).gap(theme.space_md).draw();
        defer r.deinit();
        cell(@src(), "house", ds.icons.house);
        cell(@src(), "search", ds.icons.search);
        cell(@src(), "settings", ds.icons.settings);
        cell(@src(), "bell", ds.icons.bell);
        cell(@src(), "user", ds.icons.user);
        cell(@src(), "heart", ds.icons.heart);
    }
    ds.gap(@src(), theme.space_md);
    {
        var r = ds.row(@src()).gap(theme.space_md).draw();
        defer r.deinit();
        cell(@src(), "star", ds.icons.star);
        cell(@src(), "save", ds.icons.save);
        cell(@src(), "copy", ds.icons.copy);
        cell(@src(), "pencil", ds.icons.pencil);
        cell(@src(), "trash_2", ds.icons.trash_2);
        cell(@src(), "download", ds.icons.download);
    }
    ds.gap(@src(), theme.space_md);
    {
        var r = ds.row(@src()).gap(theme.space_md).draw();
        defer r.deinit();
        cell(@src(), "check", ds.icons.check);
        cell(@src(), "x", ds.icons.x);
        cell(@src(), "plus", ds.icons.plus);
        cell(@src(), "lock", ds.icons.lock);
        cell(@src(), "sun", ds.icons.sun);
        cell(@src(), "moon", ds.icons.moon);
    }

    ds.gap(@src(), theme.space_lg);
    ds.label(@src(), "Raster image source").style(.secondary).font(.heading).draw();
    ds.gap(@src(), theme.space_sm);
    {
        // Labels carry a 6px text inset (dvui LabelWidget default padding), so a
        // bare widget would sit slightly left of the section heading. Indent the
        // image to match the heading's left edge.
        var wrap = dvui.box(@src(), .{}, .{ .padding = ds.paddingXY(theme.space_xs, 0) });
        defer wrap.deinit();
        ds.icon(@src(), sample_image.source()).size(.lg).draw();
    }
}
