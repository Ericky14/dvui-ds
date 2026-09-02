/// A turn boundary ("turn 7 / 2 files") with an Undo action. Returns true on the frame
/// Undo is clicked. CONTRACT:
///   - Full-width row: hairline (`border_subtle`, 1px), label (mono, muted caption),
///     "Undo" (accent-coloured ghost button, sm), hairline.
///   - Vertical margin space_xs; never taller than one caption line plus margins.
///
/// STATUS: scaffold. The body below is a placeholder that compiles and renders a
/// plain box so consumers can integrate against the API; the real widget replaces
/// `draw()` (and adds private `opts()` resolvers) without changing this surface.
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
        var box = dvui.box(self.src, .{ .dir = .horizontal }, .{ .id_extra = self.id_extra, .expand = .horizontal, .padding = dvui.Rect.all(tokens.current.space_xs) });
        defer box.deinit();
        dvui.labelNoFmt(@src(), self.label_text, .{}, .{ .color_text = .{ .color = tokens.current.text_muted }, .font = ds.font(tokens.current.font_size_sm) });
        return false;
    }
};

test {
    _ = @import("checkpoint_tests.zig");
}
