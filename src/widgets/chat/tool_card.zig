/// ToolCard — one tool call, collapsed to a single row. CONTRACT:
///   - Row: status dot (running = warn colour with a slow pulse, ok = success green,
///     failed = destructive, denied = muted), mono tool name, secondary summary
///     (single line, ellipsized), chevron on the right when `details` is non-empty.
///   - Click toggles `expanded_state.*` (when provided); expanded shows `details`
///     in a mono block on `surface_0` below the row.
///   - Container: `surface_1` fill, `border_subtle` border, corners round(radius_sm),
///     hover lifts to `surface_2`.
///   - Height stays constant while running (no layout jumps as text arrives): every
///     status draws the same row (dot + name + one ellipsized summary line), so a
///     summary that grows or a status that flips never changes the row height.
///
/// Usage:
///   ds.chat.toolCard(@src(), "set_component", "Ball / MeshRenderer.color", .ok).draw();
///   ds.chat.toolCard(@src(), "screenshot", "waiting for the frame", .running).idExtra(index).draw();
///   ds.chat.toolCard(@src(), "Read", "src/main.zig", .ok).details(file_text).expanded(&open).draw();
const std = @import("std");
const dvui = @import("dvui");
const ds = @import("../../ds.zig");
const tokens = @import("../../tokens.zig");
const anim = @import("../../anim/anim.zig");
const motion = @import("../../motion.zig");

const Color = dvui.Color;

/// Lifecycle of a tool call as the agent stream reports it.
pub const ToolStatus = enum { running, ok, failed, denied };

/// Status colours the theme does not carry (it has `accent` and `destructive` but no
/// warn / success tokens). These two are the chat status palette until the theme
/// grows semantic status colours; they sit at the same lightness as the Cosmic Teal
/// `accent` / `destructive` so the four dots read as one family.
const status_warn: Color = .fromHex("#E8B86D");
const status_ok: Color = .fromHex("#6FCF97");

/// The running dot breathes between full opacity and this floor.
const pulse_floor: f32 = 0.35;
/// One half-cycle (bright → dim or dim → bright) of the running pulse.
const pulse_half_period: i32 = motion.slower * 2;
/// Status dot diameter — matches the `badge` dot so the two line up in a list.
const dot_diameter: f32 = 8;

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

    /// Whether a click can expand / collapse this card: it needs both details to
    /// show and caller-owned state to flip.
    pub fn isToggleable(self: ToolCard) bool {
        return self.details_text.len > 0 and self.expanded_state != null;
    }

    /// Whether the details block is showing this frame.
    pub fn isExpanded(self: ToolCard) bool {
        const state = self.expanded_state orelse return false;
        return state.* and self.details_text.len > 0;
    }

    /// Draw the widget.
    pub fn draw(self: ToolCard) void {
        const theme = tokens.current;
        const toggleable = self.isToggleable();
        const is_expanded = self.isExpanded();

        var card = dvui.box(self.src, .{ .dir = .vertical }, containerOpts(theme, self.id_extra));
        defer card.deinit();

        // The whole card is the hover / click target. Its fill + border are drawn
        // by hand after the hover test so the lift lands on the same frame.
        var hovered = false;
        if (dvui.clicked(card.data(), .{ .hovered = &hovered, .hover_cursor = if (toggleable) .hand else .arrow })) {
            if (self.expanded_state) |state| {
                if (toggleable) state.* = !state.*;
            }
        }
        drawContainer(card.data(), hovered, theme);

        {
            var header = dvui.box(@src(), .{ .dir = .horizontal, .gap = theme.space_sm }, headerOpts(theme));
            defer header.deinit();

            drawStatusDot(header.data().id, self.status, theme);

            dvui.labelNoFmt(@src(), self.name, .{}, .{
                .color_text = .{ .color = theme.text_primary },
                .font = monoFont(theme.font_size_md).withWeight(.medium),
                .gravity_y = 0.5,
            });

            // The summary takes the leftover width and ellipsizes (single line).
            dvui.labelNoFmt(@src(), self.summary, .{}, .{
                .color_text = .{ .color = theme.text_secondary },
                .font = ds.font(theme.font_size_md),
                .expand = .horizontal,
                .gravity_y = 0.5,
            });

            if (self.details_text.len > 0) {
                if (is_expanded) {
                    ds.icon(@src(), ds.Source.namedIcon("chevron-down", ds.icons.chevron_down)).style(.muted).size(.sm).draw();
                } else {
                    ds.icon(@src(), ds.Source.namedIcon("chevron-right", ds.icons.chevron_right)).style(.muted).size(.sm).draw();
                }
            }
        }

        if (is_expanded) {
            var block = dvui.box(@src(), .{ .dir = .vertical }, detailsOpts(theme));
            defer block.deinit();
            dvui.labelNoFmt(@src(), self.details_text, .{}, .{
                .color_text = .{ .color = theme.text_secondary },
                .font = monoFont(theme.font_size_sm),
            });
        }
    }
};

/// The dot colour for a status (before the running pulse is applied).
pub fn statusColor(status: ToolStatus, theme: tokens.Theme) Color {
    return switch (status) {
        .running => status_warn,
        .ok => status_ok,
        .failed => theme.destructive,
        .denied => theme.text_muted,
    };
}

/// Root card options: rounded corners and horizontal expansion. Fill and border
/// are drawn by `drawContainer` so they can follow the current frame's hover.
fn containerOpts(theme: tokens.Theme, id_extra: usize) dvui.Options {
    return .{
        .id_extra = id_extra,
        .expand = .horizontal,
        .corners = dvui.CornerRect.round(theme.radius_sm),
    };
}

/// The header row: padded, expands to the card width.
fn headerOpts(theme: tokens.Theme) dvui.Options {
    return .{
        .expand = .horizontal,
        .padding = ds.paddingXY(theme.space_sm, theme.space_xs),
    };
}

/// The expanded details block: an inset mono block on `surface_0`.
fn detailsOpts(theme: tokens.Theme) dvui.Options {
    return .{
        .expand = .horizontal,
        .background = true,
        .color_fill = .{ .color = theme.surface_0 },
        .corners = dvui.CornerRect.round(theme.radius_sm),
        .margin = ds.paddingEach(0, theme.space_sm, theme.space_sm, theme.space_sm),
        .padding = ds.padding(theme.space_sm),
    };
}

/// Fill (animated between `surface_1` and `surface_2` on hover) plus the
/// `border_subtle` outline, drawn the way dvui draws a uniform border: a stroke
/// centred half a border-width inside the rect.
fn drawContainer(data: *const dvui.WidgetData, hovered: bool, theme: tokens.Theme) void {
    if (!data.visible()) return;
    const rect_scale = data.borderRectScale();
    const scale = rect_scale.s;
    const corners = dvui.CornerRect.Physical.round(theme.radius_sm * scale);

    const fill_target = if (hovered) theme.surface_2 else theme.surface_1;
    const fill = anim.color(data.id, "fill", fill_target, .{});
    rect_scale.r.fill(corners, .{ .color = .{ .color = fill }, .fade = 1.0 });

    const thickness = theme.border_width * scale;
    rect_scale.r.insetAll(thickness * 0.5).stroke(corners, .{
        .thickness = thickness,
        .color = .{ .color = theme.border_subtle },
    });
}

/// The status dot: a small filled circle, vertically centred in the row. The
/// running dot breathes (see `pulseOpacity`).
fn drawStatusDot(row_id: dvui.Id, status: ToolStatus, theme: tokens.Theme) void {
    var color = statusColor(status, theme);
    if (status == .running) color = color.opacity(pulseOpacity(row_id));
    var dot = dvui.box(@src(), .{}, .{
        .background = true,
        .corners = dvui.CornerRect.round(1000),
        .color_fill = .{ .color = color },
        .min_size_content = dvui.Size.all(dot_diameter),
        .gravity_y = 0.5,
    });
    dot.deinit();
}

/// Slow opacity pulse for the running dot: eases between 1.0 and `pulse_floor`,
/// reversing direction each time a half-cycle settles. Built on `anim.float`, so it
/// requests frames only while a transition is in flight. Under
/// `dvui.reduce_motion` the dot holds full opacity instead (decorative motion
/// off — which also lets headless captures settle).
fn pulseOpacity(id: dvui.Id) f32 {
    if (dvui.reduce_motion) return 1.0;
    const rising = dvui.dataGetPtrDefault(null, id, "_pulse_up", bool, true);
    const target: f32 = if (rising.*) 1.0 else pulse_floor;
    const value = anim.float(id, "pulse", target, .{ .duration = pulse_half_period, .easing = motion.inOut });
    if (@abs(value - target) < 0.001) rising.* = !rising.*;
    return value;
}

/// The theme's mono font at a pixel size (the DS maps `.mono` onto its font family
/// until a mono face is embedded).
fn monoFont(size_px: u16) dvui.Font {
    return dvui.Font.theme(.mono).withSize(@floatFromInt(size_px));
}

test {
    _ = @import("tool_card_tests.zig");
}
