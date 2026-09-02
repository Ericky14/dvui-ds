/// Checkpoint — a turn boundary ("turn 7 / 2 files") with an Undo action. Returns
/// true on the frame Undo is clicked. CONTRACT:
///   - Full-width row: hairline (`border_subtle`, 1px), label (mono, muted caption),
///     "Undo" (accent-coloured ghost button, sm), hairline.
///   - Vertical margin space_xs; never taller than one caption line plus margins
///     (the Undo button drops its vertical padding so it matches the caption line).
///
/// Usage:
///   if (ds.chat.checkpoint(@src(), "turn 7 / 2 files").draw()) undoTurn(7);
///   _ = ds.chat.checkpoint(@src(), label).idExtra(turn_index).draw();
const std = @import("std");
const dvui = @import("dvui");
const ds = @import("../../ds.zig");
const tokens = @import("../../tokens.zig");

pub fn checkpoint(src: std.builtin.SourceLocation, label_text: []const u8) Checkpoint {
    return .{ .src = src, .label_text = label_text };
}

pub const Checkpoint = struct {
    src: std.builtin.SourceLocation,
    label_text: []const u8,
    id_extra: usize = 0,

    /// Disambiguate identity when used in a loop / list.
    pub fn idExtra(self: Checkpoint, val: usize) Checkpoint {
        var copy = self;
        copy.id_extra = val;
        return copy;
    }

    /// Draw the widget.
    pub fn draw(self: Checkpoint) bool {
        const theme = tokens.current;

        var row = dvui.box(self.src, .{ .dir = .horizontal, .gap = theme.space_sm }, rowOpts(theme, self.id_extra));
        defer row.deinit();

        drawHairline(@src(), theme);
        dvui.labelNoFmt(@src(), self.label_text, .{}, labelOpts(theme));
        const clicked = ds.button(@src(), "Undo")
            .variant(.accent_ghost)
            .size(.sm)
            .padding(ds.paddingXY(theme.space_sm, 0))
            .draw();
        drawHairline(@src(), theme);

        return clicked;
    }
};

/// A 1px `border_subtle` line that takes the leftover width, centred on the row.
fn drawHairline(src: std.builtin.SourceLocation, theme: tokens.Theme) void {
    var line = dvui.box(src, .{}, .{
        .expand = .horizontal,
        .background = true,
        .color_fill = .{ .color = theme.border_subtle },
        .min_size_content = .{ .w = 0, .h = theme.border_width },
        .gravity_y = 0.5,
    });
    line.deinit();
}

fn rowOpts(theme: tokens.Theme, id_extra: usize) dvui.Options {
    return .{
        .id_extra = id_extra,
        .expand = .horizontal,
        .margin = ds.paddingXY(0, theme.space_xs),
    };
}

/// Mono muted caption with no vertical padding, so the row is one caption line.
fn labelOpts(theme: tokens.Theme) dvui.Options {
    return .{
        .color_text = .{ .color = theme.text_muted },
        .font = monoFont(theme.font_size_sm),
        .padding = ds.paddingXY(theme.space_2xs, 0),
        .gravity_y = 0.5,
    };
}

/// The theme's mono font at a pixel size (the DS maps `.mono` onto its font family
/// until a mono face is embedded).
fn monoFont(size_px: u16) dvui.Font {
    return dvui.Font.theme(.mono).withSize(@floatFromInt(size_px));
}

test {
    _ = @import("checkpoint_tests.zig");
}
