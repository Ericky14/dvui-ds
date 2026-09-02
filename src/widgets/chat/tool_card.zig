/// One tool call, collapsed to a single row. CONTRACT:
///   - Row: status dot (running = warn colour with a slow pulse, ok = success green,
///     failed = destructive, denied = muted), mono tool name, secondary summary
///     (single line, ellipsized), chevron on the right when `details` is non-empty.
///   - Click toggles `expanded_state.*` (when provided); expanded shows `details`
///     in a mono block on `surface_0` below the row.
///   - Container: `surface_1` fill, `border_subtle` border, corners round(radius_sm),
///     hover lifts to `surface_2`.
///   - Height stays constant while running (no layout jumps as text arrives).
///
/// STATUS: scaffold. The body below is a placeholder that compiles and renders a
/// plain box so consumers can integrate against the API; the real widget replaces
/// `draw()` (and adds private `opts()` resolvers) without changing this surface.
const std = @import("std");
const dvui = @import("dvui");
const ds = @import("../../ds.zig");
const tokens = @import("../../tokens.zig");

/// Lifecycle of a tool call as the agent stream reports it.
pub const ToolStatus = enum { running, ok, failed, denied };
pub fn toolCard(src: std.builtin.SourceLocation, name: []const u8, summary: []const u8, status: ToolStatus) ToolCard {
    return .{ .src = src, .name = name, .summary = summary, .status = status };
}

pub const ToolCard = struct {
    src: std.builtin.SourceLocation,
    name: []const u8,
    summary: []const u8,
    status: ToolStatus,
    details_text: []const u8 = "",
    expanded_state: ?*bool = null,
    id_extra: usize = 0,

    /// Arguments / result text shown when expanded (mono).
    pub fn details(self: ToolCard, val: []const u8) ToolCard {
        var copy = self;
        copy.details_text = val;
        return copy;
    }

    /// Caller-owned expansion state (immediate mode).
    pub fn expanded(self: ToolCard, val: *bool) ToolCard {
        var copy = self;
        copy.expanded_state = val;
        return copy;
    }

    /// Disambiguate identity when used in a loop / list.
    pub fn idExtra(self: ToolCard, val: usize) ToolCard {
        var copy = self;
        copy.id_extra = val;
        return copy;
    }

    /// Draw the widget.
    pub fn draw(self: ToolCard) void {
        var box = dvui.box(self.src, .{ .dir = .horizontal }, .{
            .id_extra = self.id_extra,
            .expand = .horizontal,
            .background = true,
            .color_fill = .{ .color = tokens.current.surface_1 },
            .padding = dvui.Rect.all(tokens.current.space_xs),
        });
        defer box.deinit();
        dvui.labelNoFmt(@src(), self.name, .{}, .{ .font = ds.fontMedium(tokens.current.font_size_sm) });
        dvui.labelNoFmt(@src(), self.summary, .{}, .{ .color_text = .{ .color = tokens.current.text_muted } });
        _ = self.status;
        _ = self.details_text;
        _ = self.expanded_state;
    }
};

test {
    _ = @import("tool_card_tests.zig");
}
