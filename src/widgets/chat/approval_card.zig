/// A permission prompt from the agent. Returns the choice on the frame a button is
/// clicked, `.none` otherwise. CONTRACT:
///   - Container: accent border (1px), accent-tinted fill (ds.alpha accent at the
///     tonal-fill opacity), corners round(radius_md), padding space_sm.
///   - Title (primary, medium weight) then `detail` (secondary; mono when it looks
///     like a command or path).
///   - Buttons row: "Allow once" (filled), "Always allow" (outlined), "Deny" (danger
///     ghost), all sm.
///   - When `note` is given: a single-line text input below the buttons with a
///     placeholder "Tell it what you want instead"; the caller reads the buffer
///     alongside a `.deny`.
///
/// STATUS: scaffold. The body below is a placeholder that compiles and renders a
/// plain box so consumers can integrate against the API; the real widget replaces
/// `draw()` (and adds private `opts()` resolvers) without changing this surface.
const std = @import("std");
const dvui = @import("dvui");
const ds = @import("../../ds.zig");
const tokens = @import("../../tokens.zig");

/// The user's answer to an approval request.
pub const ApprovalChoice = enum { none, allow_once, allow_always, deny };
pub fn approvalCard(src: std.builtin.SourceLocation, title: []const u8, detail: []const u8) ApprovalCard {
    return .{ .src = src, .title = title, .detail = detail };
}

pub const ApprovalCard = struct {
    src: std.builtin.SourceLocation,
    title: []const u8,
    detail: []const u8,
    note_buffer: ?[]u8 = null,
    id_extra: usize = 0,

    /// Optional caller-owned buffer for "tell it what you want instead".
    pub fn note(self: ApprovalCard, val: []u8) ApprovalCard {
        var copy = self;
        copy.note_buffer = val;
        return copy;
    }

    /// Disambiguate identity when used in a loop / list.
    pub fn idExtra(self: ApprovalCard, val: usize) ApprovalCard {
        var copy = self;
        copy.id_extra = val;
        return copy;
    }

    /// Draw the widget.
    pub fn draw(self: ApprovalCard) ApprovalChoice {
        var box = dvui.box(self.src, .{ .dir = .vertical }, .{
            .id_extra = self.id_extra,
            .expand = .horizontal,
            .background = true,
            .color_fill = .{ .color = ds.alpha(tokens.current.accent, tokens.current.opacity_tonal_fill) },
            .padding = dvui.Rect.all(tokens.current.space_sm),
        });
        defer box.deinit();
        dvui.labelNoFmt(@src(), self.title, .{}, .{ .font = ds.fontMedium(tokens.current.font_size_md) });
        dvui.labelNoFmt(@src(), self.detail, .{}, .{ .color_text = .{ .color = tokens.current.text_secondary } });
        _ = self.note_buffer;
        return .none;
    }
};

test {
    _ = @import("approval_card_tests.zig");
}
