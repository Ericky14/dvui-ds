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

        // Left-anchored, not centred between two rules. Centring puts the label
        // and the button at `(row - group) / 2`, which is a half physical pixel
        // whenever that leftover is odd — every other window width — and a
        // button on a half pixel renders soft. It also reads better: everything
        // else in a chat transcript starts at the same left edge.
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

/// A `border_subtle` rule that takes the leftover width, centred on the row.
///
/// The box only claims the space; the line itself is painted into a rect that
/// has been rounded to whole physical pixels. Letting a 1 px box be *laid out*
/// puts its height at 1.75 physical px at 175 % and its centred top edge on a
/// half pixel, which renders the rule as two rows of grey instead of one row of
/// line. Taking the pixel by hand is the only way to be sure of it.
fn drawHairline(src: std.builtin.SourceLocation, theme: tokens.Theme) void {
    var line = dvui.box(src, .{}, .{
        .expand = .both,
        .min_size_content = .{ .w = 0, .h = ds.hairline(ds.pixelScale()) },
    });
    const area = line.data().borderRectScale().r;
    line.deinit();
    if (area.w < 1 or area.h < 1) return;

    const thickness = @max(1, @round(ds.pixelScale()));
    const rule: dvui.Rect.Physical = .{
        .x = @round(area.x),
        .y = @round(area.y + (area.h - thickness) / 2),
        .w = @round(area.w),
        .h = thickness,
    };
    rule.fill(.{}, .{ .color = .{ .color = theme.border_subtle } });
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
