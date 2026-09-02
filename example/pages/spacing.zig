const ds = @import("dvui_ds");
const dvui = @import("dvui");

/// One spacing token: name, a bar of that width, and the px value.
fn row(idx: usize, name: []const u8, value: f32) void {
    const theme = ds.tokens.current;
    var r = dvui.box(@src(), .{ .dir = .horizontal, .gap = theme.space_md }, .{ .id_extra = idx });
    defer r.deinit();

    dvui.labelNoFmt(@src(), name, .{}, .{
        .id_extra = idx,
        .min_size_content = .{ .w = 64 },
        .color_text = .{ .color = theme.text_muted },
        .font = ds.font(theme.font_size_sm),
        .gravity_y = 0.5,
    });
    {
        var bar = dvui.box(@src(), .{}, .{
            .id_extra = idx,
            .min_size_content = .{ .w = value, .h = 14 },
            .background = true,
            .color_fill = .{ .color = theme.accent },
            .corners = dvui.CornerRect.round(theme.radius_sm),
            .gravity_y = 0.5,
        });
        bar.deinit();
    }
    var buf: [16]u8 = undefined;
    const px = std.fmt.bufPrint(&buf, "{d:.0}px", .{value}) catch "";
    dvui.labelNoFmt(@src(), px, .{}, .{
        .id_extra = idx,
        .color_text = .{ .color = theme.text_ghost },
        .font = ds.font(theme.font_size_sm),
        .gravity_y = 0.5,
    });
}

pub fn draw() void {
    const theme = ds.tokens.current;

    ds.label(@src(), "Spacing").style(.title).draw();
    ds.gap(@src(), theme.space_md);

    ds.label(@src(), "Scale").style(.secondary).font(.heading).draw();
    ds.gap(@src(), theme.space_sm);

    var col = ds.column(@src()).gap(theme.space_sm).draw();
    defer col.deinit();
    row(0, "space_3xs", theme.space_3xs);
    row(1, "space_2xs", theme.space_2xs);
    row(2, "space_xs", theme.space_xs);
    row(3, "space_sm", theme.space_sm);
    row(4, "space_md", theme.space_md);
    row(5, "space_lg", theme.space_lg);
    row(6, "space_xl", theme.space_xl);
    row(7, "space_2xl", theme.space_2xl);
}

const std = @import("std");
