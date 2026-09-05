const ds = @import("dvui_ds");

var current_index: usize = 3;

const Entry = struct { name: [:0]const u8, bytes: []const u8, label: []const u8 };

const strip = [_]Entry{
    .{ .name = "undo", .bytes = ds.icons.undo, .label = "Undo" },
    .{ .name = "redo", .bytes = ds.icons.redo, .label = "Redo" },
    .{ .name = "square-pen", .bytes = ds.icons.square_pen, .label = "Renamed Ground" },
    .{ .name = "pencil", .bytes = ds.icons.pencil, .label = "Your edit · 22 min ago" },
    .{ .name = "history", .bytes = ds.icons.history, .label = "Restore checkpoint" },
    .{ .name = "camera", .bytes = ds.icons.camera, .label = "Snapshot" },
};

pub fn draw() void {
    const theme = ds.tokens.current;

    ds.label(@src(), "Chip").style(.title).draw();
    ds.gap(@src(), theme.space_2xs);
    ds.label(@src(), "A square icon chip for dense strips: it carries its place in a sequence, not just a mouse state.").style(.muted).draw();
    ds.gap(@src(), theme.space_lg);

    ds.label(@src(), "States").style(.secondary).font(.heading).draw();
    ds.gap(@src(), theme.space_sm);
    {
        var row = ds.row(@src()).gap(theme.space_lg).draw();
        defer row.deinit();
        state(@src(), "rest", .rest, 0);
        state(@src(), "active", .active, 1);
        state(@src(), "current", .current, 2);
        state(@src(), "faded", .faded, 3);
    }

    ds.gap(@src(), theme.space_xl);
    ds.label(@src(), "A history strip — click a chip to move the marker").style(.secondary).font(.heading).draw();
    ds.gap(@src(), theme.space_sm);
    {
        var row = ds.row(@src()).gap(theme.space_2xs).draw();
        defer row.deinit();
        inline for (strip, 0..) |entry, index| {
            const chip_state: ds.ChipState = if (index == current_index)
                .current
            else if (index > current_index)
                .faded
            else
                .rest;
            if (ds.chip(@src(), entry.name, entry.bytes)
                .state(chip_state)
                .tooltip(entry.label)
                .idExtra(index)
                .draw()) current_index = index;
        }
    }
    ds.gap(@src(), theme.space_sm);
    ds.label(@src(), "Everything after the marker is faded — present, dimmed, still clickable.").style(.weak).draw();
}

fn state(src: @import("std").builtin.SourceLocation, name: []const u8, value: ds.ChipState, index: usize) void {
    var column = ds.column(src).gap(ds.tokens.current.space_2xs).draw();
    defer column.deinit();
    _ = ds.chip(@src(), "pencil", ds.icons.pencil).state(value).idExtra(index).draw();
    ds.label(@src(), name).style(.weak).draw();
}
