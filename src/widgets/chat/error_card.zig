/// ErrorCard — an engine / build / script error surfaced into the chat. Returns true
/// on the frame "Fix it" is clicked (the caller sends the error to the agent). CONTRACT:
///   - Container: destructive-tinted fill (ds.alpha destructive at tonal-fill opacity),
///     destructive border, corners round(radius_md).
///   - Row: error icon (destructive) + message (primary; mono when multi-line or
///     compiler-shaped — see `looksCompilerShaped`), then `location` (muted mono,
///     e.g. "scripts/ball.lua:12").
///   - "Fix it" button: outlined danger (the outlined chip with destructive text — the
///     nearest composition the button offers), sm, right-aligned.
///
/// Usage:
///   if (ds.chat.errorCard(@src(), "attempt to index a nil value (global 'ball')", "scripts/ball.lua:12").draw()) sendToAgent();
///   _ = ds.chat.errorCard(@src(), compiler_output, null).idExtra(index).draw();
const std = @import("std");
const dvui = @import("dvui");
const ds = @import("../../ds.zig");
const tokens = @import("../../tokens.zig");

/// Diagnostic markers that mark a message as compiler output.
const compiler_markers = [_][]const u8{ ": error:", ": warning:", ": note:" };

pub fn errorCard(src: std.builtin.SourceLocation, message_text: []const u8, location: ?[]const u8) ErrorCard {
    return .{ .src = src, .message_text = message_text, .location = location };
}

pub const ErrorCard = struct {
    src: std.builtin.SourceLocation,
    message_text: []const u8,
    location: ?[]const u8,
    id_extra: usize = 0,

    /// Disambiguate identity when used in a loop / list.
    pub fn idExtra(self: ErrorCard, val: usize) ErrorCard {
        var copy = self;
        copy.id_extra = val;
        return copy;
    }

    /// Draw the widget.
    pub fn draw(self: ErrorCard) bool {
        const theme = tokens.current;

        var card = dvui.box(self.src, .{ .dir = .vertical, .gap = theme.space_2xs }, containerOpts(theme, self.id_extra));
        defer card.deinit();

        {
            var row = dvui.box(@src(), .{ .dir = .horizontal, .gap = theme.space_sm }, .{ .expand = .horizontal });
            defer row.deinit();
            ds.icon(@src(), ds.Source.namedIcon("circle-alert", ds.icons.circle_alert)).style(.danger).size(.md).gravityY(0).draw();

            var text = dvui.box(@src(), .{ .dir = .vertical }, .{ .expand = .horizontal });
            defer text.deinit();
            dvui.labelNoFmt(@src(), self.message_text, .{}, messageOpts(theme, looksCompilerShaped(self.message_text)));
            if (self.location) |location| {
                dvui.labelNoFmt(@src(), location, .{}, locationOpts(theme));
            }
        }

        var footer = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal });
        defer footer.deinit();
        ds.spacer(@src());
        return ds.button(@src(), "Fix it").variant(.outlined).size(.sm).textColor(theme.destructive).draw();
    }
};

/// Whether a message reads as compiler / tool output (rendered mono): it spans
/// several lines, carries a diagnostic marker (": error:", ": warning:", ": note:"),
/// or contains a `:<line>:` position marker.
pub fn looksCompilerShaped(text: []const u8) bool {
    if (std.mem.indexOfScalar(u8, text, '\n') != null) return true;
    for (compiler_markers) |marker| {
        if (std.mem.indexOf(u8, text, marker) != null) return true;
    }
    return hasLineMarker(text);
}

/// True when the text contains a colon, one or more digits, then a colon
/// ("main.zig:12:5:").
fn hasLineMarker(text: []const u8) bool {
    var index: usize = 0;
    while (std.mem.indexOfScalarPos(u8, text, index, ':')) |colon| {
        var cursor = colon + 1;
        while (cursor < text.len and std.ascii.isDigit(text[cursor])) cursor += 1;
        if (cursor > colon + 1 and cursor < text.len and text[cursor] == ':') return true;
        index = colon + 1;
    }
    return false;
}

/// Destructive-tinted container with a destructive border.
fn containerOpts(theme: tokens.Theme, id_extra: usize) dvui.Options {
    return .{
        .id_extra = id_extra,
        .expand = .horizontal,
        .background = true,
        .color_fill = .{ .color = ds.alpha(theme.destructive, theme.opacity_tonal_fill) },
        .color_border = .{ .color = theme.destructive },
        .border = dvui.Rect.all(theme.border_width),
        .corners = dvui.CornerRect.round(theme.radius_md),
        .padding = ds.padding(theme.space_sm),
    };
}

fn messageOpts(theme: tokens.Theme, mono: bool) dvui.Options {
    return .{
        .color_text = .{ .color = theme.text_primary },
        .font = if (mono) monoFont(theme.font_size_md) else ds.font(theme.font_size_md),
        .padding = ds.paddingEach(0, theme.space_xs, theme.space_3xs, 0),
    };
}

fn locationOpts(theme: tokens.Theme) dvui.Options {
    return .{
        .color_text = .{ .color = theme.text_muted },
        .font = monoFont(theme.font_size_sm),
        .padding = ds.paddingEach(0, theme.space_xs, theme.space_3xs, 0),
    };
}

/// The theme's mono font at a pixel size (the DS maps `.mono` onto its font family
/// until a mono face is embedded).
fn monoFont(size_px: u16) dvui.Font {
    return dvui.Font.theme(.mono).withSize(@floatFromInt(size_px));
}

test {
    _ = @import("error_card_tests.zig");
}
