/// ApprovalCard — a permission prompt from the agent. Returns the choice on the
/// frame a button is clicked, `.none` otherwise. CONTRACT:
///   - Container: accent border (1px), accent-tinted fill (ds.alpha accent at the
///     tonal-fill opacity), corners round(radius_md), padding space_sm.
///   - Title (primary, medium weight) then `detail` (secondary; mono when it looks
///     like a command or path — see `looksLikeCommandOrPath`).
///   - Buttons row: "Allow once" (filled), "Always allow" (outlined), "Deny" (danger
///     ghost), all sm.
///   - When `note` is given: a single-line text input below the buttons with a
///     placeholder "Tell it what you want instead"; the caller reads the buffer
///     alongside a `.deny`.
///
/// Usage:
///   switch (ds.chat.approvalCard(@src(), "Run `zig build check`?", "zig build check").draw()) {
///       .allow_once => run(), .allow_always => remember(), .deny => refuse(), .none => {},
///   }
///   _ = ds.chat.approvalCard(@src(), title, detail).note(&note_buffer).idExtra(index).draw();
const std = @import("std");
const dvui = @import("dvui");
const ds = @import("../../ds.zig");
const tokens = @import("../../tokens.zig");

/// The user's answer to an approval request.
pub const ApprovalChoice = enum { none, allow_once, allow_always, deny };

/// Placeholder for the optional note input.
const note_placeholder = "Tell it what you want instead";

/// A detail with at most this many space-separated tokens (and no sentence
/// punctuation) reads as a command line rather than prose.
const max_command_tokens: usize = 4;

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
        const theme = tokens.current;
        var choice: ApprovalChoice = .none;

        var card = dvui.box(self.src, .{ .dir = .vertical, .gap = theme.space_sm }, containerOpts(theme, self.id_extra));
        defer card.deinit();

        dvui.labelNoFmt(@src(), self.title, .{}, titleOpts(theme));
        if (self.detail.len > 0) {
            dvui.labelNoFmt(@src(), self.detail, .{}, detailOpts(theme, looksLikeCommandOrPath(self.detail)));
        }

        {
            var actions = dvui.box(@src(), .{ .dir = .horizontal, .gap = theme.space_sm }, actionsOpts(theme));
            defer actions.deinit();
            if (ds.button(@src(), "Allow once").variant(.filled).size(.sm).draw()) choice = .allow_once;
            if (ds.button(@src(), "Always allow").variant(.outlined).size(.sm).draw()) choice = .allow_always;
            // Danger ghost: the danger variant's text + hover wash on a transparent rest.
            if (ds.button(@src(), "Deny").variant(.danger).size(.sm).fillColor(.transparent).draw()) choice = .deny;
        }

        if (self.note_buffer) |buffer| {
            ds.textInput(@src(), buffer).size(.sm).placeholder(note_placeholder).expand(.horizontal).draw();
        }

        return choice;
    }
};

/// Whether `detail` reads as a shell command or a file path (rendered mono) rather
/// than prose. A path separator anywhere is a path; otherwise a command is a short
/// line (≤ `max_command_tokens` tokens, or any `-flag` token) whose first word is
/// executable-shaped (lowercase, digits, `-`, `_`, `.`) and that does not end in
/// sentence punctuation.
pub fn looksLikeCommandOrPath(text: []const u8) bool {
    const trimmed = std.mem.trim(u8, text, " \t\r\n");
    if (trimmed.len == 0) return false;
    if (std.mem.indexOfAny(u8, trimmed, "/\\") != null) return true;

    const last = trimmed[trimmed.len - 1];
    if (last == '.' or last == '?' or last == '!') return false;

    var words = std.mem.tokenizeScalar(u8, trimmed, ' ');
    const first_word = words.next() orelse return false;
    for (first_word) |char| {
        const executable_shaped = std.ascii.isLower(char) or std.ascii.isDigit(char) or char == '-' or char == '_' or char == '.';
        if (!executable_shaped) return false;
    }

    var token_count: usize = 1;
    var has_flag = false;
    while (words.next()) |word| {
        token_count += 1;
        if (word[0] == '-') has_flag = true;
    }
    if (token_count < 2) return false;
    return has_flag or token_count <= max_command_tokens;
}

/// Accent-tinted container with a 1px accent border.
fn containerOpts(theme: tokens.Theme, id_extra: usize) dvui.Options {
    return .{
        .id_extra = id_extra,
        .expand = .horizontal,
        .background = true,
        .color_fill = .{ .color = ds.alpha(theme.accent, theme.opacity_tonal_fill) },
        .color_border = .{ .color = theme.accent },
        .border = ds.border(theme.border_width),
        .corners = dvui.CornerRect.round(theme.radius_md),
        .padding = ds.padding(theme.space_sm),
    };
}

fn titleOpts(theme: tokens.Theme) dvui.Options {
    return .{
        .color_text = .{ .color = theme.text_primary },
        .font = ds.fontMedium(theme.font_size_md),
    };
}

fn detailOpts(theme: tokens.Theme, mono: bool) dvui.Options {
    return .{
        .color_text = .{ .color = theme.text_secondary },
        .font = if (mono) monoFont(theme.font_size_md) else ds.font(theme.font_size_md),
    };
}

/// The button row sits a little apart from the text above it.
fn actionsOpts(theme: tokens.Theme) dvui.Options {
    return .{ .margin = ds.paddingEach(theme.space_2xs, 0, 0, 0) };
}

/// The theme's mono font at a pixel size (the DS maps `.mono` onto its font family
/// until a mono face is embedded).
fn monoFont(size_px: u16) dvui.Font {
    return dvui.Font.theme(.mono).withSize(@floatFromInt(size_px));
}

test {
    _ = @import("approval_card_tests.zig");
}
