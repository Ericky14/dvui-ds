/// The chat composer at the bottom of the chat pane.
///
///   - A multi-line entry over the caller's `buffer`, growing from one to eight
///     rows with its content and scrolling past that. The buffer is never resized.
///   - Enter submits when the buffer holds more than whitespace; Shift+Enter
///     inserts a newline; Esc reports `interrupted` while `busy`. Keys are read
///     while the entry has focus.
///   - Left: a ghost attach icon button. Right: Send (filled accent, disabled while
///     the buffer is blank) or, while busy, Stop (danger). Both `sm`, bottom-aligned
///     so they stay put as the entry grows.
///   - Below: a muted mono hint row — "enter send · shift+enter newline · esc stop".
///   - Container: `surface_1` fill, `border_strong` border that turns accent while
///     the entry has focus, round(radius_md) corners.
///
/// Usage:
///   const result = ds.chat.composer(@src(), &buffer).busy(agent_running).draw();
///   if (result.submitted) send(std.mem.sliceTo(&buffer, 0));
///   if (result.interrupted) stop();
///   _ = ds.chat.composer(@src(), &buffer).placeholder("Describe the change…").draw();
const std = @import("std");
const dvui = @import("dvui");
const ds = @import("../../ds.zig");
const tokens = @import("../../tokens.zig");

/// What the composer reported this frame.
pub const ComposerResult = struct {
    /// Enter was pressed with a non-empty buffer (or Send clicked). The caller reads
    /// the buffer, sends it, and clears it.
    submitted: bool = false,
    /// Esc was pressed or Stop clicked while `busy`.
    interrupted: bool = false,
    /// The attach (paperclip) button was clicked.
    attach_clicked: bool = false,
};
pub fn composer(src: std.builtin.SourceLocation, buffer: []u8) Composer {
    return .{ .src = src, .buffer = buffer };
}

pub const Composer = struct {
    src: std.builtin.SourceLocation,
    buffer: []u8,
    placeholder_text: []const u8 = "Ask for anything...",
    is_busy: bool = false,
    id_extra: usize = 0,

    /// Placeholder shown when the buffer is empty.
    pub fn placeholder(self: Composer, val: []const u8) Composer {
        var copy = self;
        copy.placeholder_text = val;
        return copy;
    }

    /// Agent is running: show Stop instead of Send; Esc interrupts.
    pub fn busy(self: Composer, val: bool) Composer {
        var copy = self;
        copy.is_busy = val;
        return copy;
    }

    /// Disambiguate identity when used in a loop / list.
    pub fn idExtra(self: Composer, val: usize) Composer {
        var copy = self;
        copy.id_extra = val;
        return copy;
    }

    /// Draw the widget and report what happened this frame.
    pub fn draw(self: Composer) ComposerResult {
        const theme = tokens.current;
        var result: ComposerResult = .{};

        // Focus is read from the previous frame (the border is painted before the
        // entry exists), keyed like the other DS inputs.
        const focus_key: dvui.Id = @fromBackingInt(@intCast(self.identity()));
        const was_focused = dvui.dataGetPtrDefault(null, focus_key, "_ds_focused", bool, false);

        var column = dvui.box(self.src, .{ .dir = .vertical, .gap = theme.space_2xs }, .{
            .id_extra = self.id_extra,
            .expand = .horizontal,
        });
        defer column.deinit();

        {
            var frame = dvui.box(@src(), .{ .dir = .vertical }, frameOpts(was_focused.*));
            defer frame.deinit();

            var row = dvui.box(@src(), .{ .dir = .horizontal, .gap = theme.space_xs }, .{ .expand = .horizontal });
            defer row.deinit();

            {
                var slot = buttonSlot(@src());
                defer slot.deinit();
                result.attach_clicked = ds.iconButton(@src(), "paperclip", ds.icons.paperclip).variant(.ghost).size(.sm).draw();
            }

            const entry = self.drawEntry();
            was_focused.* = entry.focused;
            if (entry.enter_pressed and !isBlank(entry.text)) result.submitted = true;
            if (entry.escape_pressed) result.interrupted = true;

            {
                var slot = buttonSlot(@src());
                defer slot.deinit();
                if (self.is_busy) {
                    if (ds.button(@src(), "Stop").variant(.danger).size(.sm).icon("square", ds.icons.square).iconFirst().draw()) {
                        result.interrupted = true;
                    }
                } else {
                    if (ds.button(@src(), "Send").variant(.filled).size(.sm).icon("send", ds.icons.send).disabled(isBlank(entry.text)).draw()) {
                        result.submitted = true;
                    }
                }
            }
        }

        dvui.labelNoFmt(@src(), hint_text, .{}, hintOpts(hintFont()));
        return result;
    }

    const EntryState = struct {
        text: []const u8,
        focused: bool,
        enter_pressed: bool,
        escape_pressed: bool,
    };

    /// The multi-line entry. Enter/Esc are intercepted before the entry sees them
    /// so a plain Enter never inserts a newline; everything else is forwarded.
    fn drawEntry(self: Composer) EntryState {
        const theme = tokens.current;
        const font = ds.font(theme.font_size_md);

        var wrap = dvui.box(@src(), .{ .dir = .vertical }, wrapOpts(font.sizeM(natural_width_m, 1).w));
        defer wrap.deinit();

        var entry: dvui.TextEntryWidget = undefined;
        entry.init(@src(), .{
            .text = .{ .buffer = self.buffer },
            .placeholder = self.placeholder_text,
            .placeholder_color = theme.text_ghost,
            .multiline = true,
            .break_lines = true,
            .scroll_horizontal = false,
            .focus_border = false,
        }, entryOpts(font, font.lineHeight()));

        var enter_pressed = false;
        var escape_pressed = false;
        for (dvui.events()) |*event| {
            if (!entry.matchEvent(event)) continue;
            if (event.evt == .key) {
                const key = event.evt.key;
                if (key.action == .down or key.action == .repeat) {
                    switch (keyIntent(key.code, key.mod, self.is_busy)) {
                        .submit => {
                            event.handle(@src(), entry.data());
                            if (key.action == .down) enter_pressed = true;
                            continue;
                        },
                        .interrupt => {
                            event.handle(@src(), entry.data());
                            if (key.action == .down) escape_pressed = true;
                            continue;
                        },
                        .newline, .none => {},
                    }
                }
            }
            entry.processEvent(event);
        }
        entry.draw();

        const focused = if (dvui.focusedWidgetId()) |focused_id| entry.data().id == focused_id else false;
        const text = entry.getText();
        entry.deinit();
        return .{ .text = text, .focused = focused, .enter_pressed = enter_pressed, .escape_pressed = escape_pressed };
    }

    /// Stable per-instance key for cross-frame state (focus), derived from the
    /// caller's `@src()` plus `idExtra`.
    fn identity(self: Composer) usize {
        return @as(usize, self.src.line) +% (@as(usize, self.src.column) *% 65599) +% self.id_extra;
    }
};

/// What a key press means to the composer.
pub const KeyIntent = enum { none, submit, newline, interrupt };

/// Enter submits, Shift+Enter is a newline, Esc interrupts only while busy.
pub fn keyIntent(code: dvui.enums.Key, mod: dvui.enums.Mod, is_busy: bool) KeyIntent {
    return switch (code) {
        .enter, .kp_enter => if (mod.shift()) .newline else .submit,
        .escape => if (is_busy) .interrupt else .none,
        else => .none,
    };
}

/// True when the text holds nothing but whitespace (a blank message is never sent).
pub fn isBlank(text: []const u8) bool {
    return std.mem.trim(u8, std.mem.sliceTo(text, 0), " \t\r\n").len == 0;
}

/// Row bounds of the auto-growing entry.
pub const min_rows: f32 = 1;
pub const max_rows: f32 = 8;
/// Natural entry width in "M"s, matching the DS text inputs; `expand` fills wider rows.
const natural_width_m: f32 = 14;
pub const hint_text = "enter send · shift+enter newline · esc stop";

/// The container: `surface_1`, a strong border that turns accent while focused.
pub fn frameOpts(focused: bool) dvui.Options {
    const theme = tokens.current;
    return .{
        .expand = .horizontal,
        .background = true,
        .color_fill = .{ .color = theme.surface_1 },
        .color_border = .{ .color = if (focused) theme.accent.opacity(0.6) else theme.border_strong },
        .border = dvui.Rect.all(theme.border_width),
        .corners = dvui.CornerRect.round(theme.radius_md),
        .padding = dvui.Rect.all(theme.space_sm),
        .margin = dvui.Rect.all(0),
    };
}

/// The box around the entry: pins the entry's min width (a wrapped entry reports
/// its unwrapped width otherwise) while `expand` fills the row; height is free.
pub fn wrapOpts(natural_width: f32) dvui.Options {
    return .{
        .expand = .horizontal,
        .min_size_content = .{ .w = natural_width, .h = 0 },
        .max_size_content = .{ .w = natural_width, .h = dvui.max_float_safe },
        .padding = dvui.Rect.all(0),
        .margin = dvui.Rect.all(0),
    };
}

/// The bare multi-line entry: no chrome of its own, one to eight rows tall.
pub fn entryOpts(font: dvui.Font, row_height: f32) dvui.Options {
    const theme = tokens.current;
    return .{
        .expand = .horizontal,
        .background = false,
        .border = dvui.Rect.all(0),
        .margin = dvui.Rect.all(0),
        .padding = ds.paddingXY(theme.space_2xs, theme.space_xs),
        .color_text = .{ .color = theme.text_primary },
        .font = font,
        .min_size_content = .{ .w = 0, .h = row_height * min_rows },
        .max_size_content = .{ .w = dvui.max_float_safe, .h = row_height * max_rows },
    };
}

/// The key hint under the box: muted mono caption.
pub fn hintOpts(font: dvui.Font) dvui.Options {
    const theme = tokens.current;
    return .{
        .font = font,
        .color_text = .{ .color = theme.text_muted },
        .padding = ds.paddingXY(theme.space_xs, 0),
        .margin = dvui.Rect.all(0),
    };
}

fn hintFont() dvui.Font {
    return dvui.Font.theme(.mono).withSize(@floatFromInt(tokens.current.font_size_sm));
}

/// A column that fills the row's height with a spacer on top, so the button it
/// holds sits on the bottom edge next to the entry's last line.
fn buttonSlot(src: std.builtin.SourceLocation) *dvui.BoxWidget {
    const slot = dvui.box(src, .{ .dir = .vertical }, .{ .expand = .vertical, .padding = dvui.Rect.all(0), .margin = dvui.Rect.all(0) });
    _ = dvui.spacer(@src(), .{ .expand = .vertical });
    return slot;
}

test {
    _ = @import("composer_tests.zig");
}
