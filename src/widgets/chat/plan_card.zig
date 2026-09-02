/// The agent's plan (plan mode) awaiting a verdict. Returns the choice on the frame
/// a button is clicked, `.none` otherwise. CONTRACT:
///   - Container: `surface_1` fill, `border` border, corners round(radius_md), a 2px
///     accent bar on the left edge.
///   - "PLAN" eyebrow (mono, muted, letter-spaced) then the title (heading font),
///     then the body rendered through `markdown()`.
///   - Buttons: "Approve" (filled), "Edit" (outlined), "Reject" (danger ghost), sm.
///
/// STATUS: scaffold. The body below is a placeholder that compiles and renders a
/// plain box so consumers can integrate against the API; the real widget replaces
/// `draw()` (and adds private `opts()` resolvers) without changing this surface.
const std = @import("std");
const dvui = @import("dvui");
const ds = @import("../../ds.zig");
const tokens = @import("../../tokens.zig");

/// The user's verdict on a plan.
pub const PlanChoice = enum { none, approve, edit, reject };
pub fn planCard(src: std.builtin.SourceLocation, title: []const u8, body_markdown: []const u8) PlanCard {
    return .{ .src = src, .title = title, .body_markdown = body_markdown };
}

pub const PlanCard = struct {
    src: std.builtin.SourceLocation,
    title: []const u8,
    body_markdown: []const u8,
    id_extra: usize = 0,

    /// Disambiguate identity when used in a loop / list.
    pub fn idExtra(self: PlanCard, val: usize) PlanCard {
        var copy = self;
        copy.id_extra = val;
        return copy;
    }

    /// Draw the widget.
    pub fn draw(self: PlanCard) PlanChoice {
        var box = dvui.box(self.src, .{ .dir = .vertical }, .{
            .id_extra = self.id_extra,
            .expand = .horizontal,
            .background = true,
            .color_fill = .{ .color = tokens.current.surface_1 },
            .padding = dvui.Rect.all(tokens.current.space_sm),
        });
        defer box.deinit();
        dvui.labelNoFmt(@src(), self.title, .{}, .{ .font = ds.fontMedium(tokens.current.font_size_md) });
        dvui.labelNoFmt(@src(), self.body_markdown, .{}, .{ .color_text = .{ .color = tokens.current.text_secondary } });
        return .none;
    }
};

test {
    _ = @import("plan_card_tests.zig");
}
