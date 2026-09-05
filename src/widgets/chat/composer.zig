/// The chat composer at the bottom of the chat pane.
///
///   - A multi-line entry over the caller's `buffer`, growing from one to eight
///     rows with its content and scrolling past that. The buffer is never resized.
///   - Enter submits when the buffer holds more than whitespace; Shift+Enter
///     inserts a newline; Esc reports `interrupted` while `busy`. Keys are read
///     while the entry has focus.
///   - Left: a ghost attach icon button. Right: Send (filled accent, disabled while
///     the buffer is blank) or, while busy, Stop (danger). Both `sm`, and on one
///     line all three controls are the same height (`chrome_control_height`) and
///     share a top and a bottom edge; once the entry grows the two buttons stay
///     on the bottom edge beside the entry's last line.
///   - Below: a muted mono hint row — "enter send · shift+enter newline · esc stop".
///   - Container: `surface_1` fill, `border_strong` border that turns accent while
///     the entry has focus, round(radius_md) corners. Border plus padding is one
///     `space_sm` on every side, so a single-line composer is exactly
///     `chrome_control_height + 2·space_sm` — 44 logical px, a whole number of
///     physical pixels at 1.0, 1.75 and 2.0. See `composerMetrics`.
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
    tag_val: ?[]const u8 = null,
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

    /// Name the composer's *text entry* for tests and UI automation
    /// (`dvui.tagGet`). The entry rather than the frame, because the entry is
    /// the thing a driver clicks to focus and the thing a test measures.
    pub fn tag(self: Composer, name: []const u8) Composer {
        var copy = self;
        copy.tag_val = name;
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
        const focus_key = self.identity();
        const was_focused = dvui.dataGetPtrDefault(null, focus_key, "_ds_focused", bool, false);

        var column = dvui.box(self.src, .{ .dir = .vertical, .gap = theme.space_2xs }, .{
            .id_extra = self.id_extra,
            .expand = .horizontal,
        });
        defer column.deinit();

        {
            var frame = dvui.box(@src(), .{ .dir = .vertical }, frameOpts(was_focused.*));
            defer frame.deinit();

            var row = dvui.box(@src(), .{ .dir = .horizontal, .gap = theme.space_sm }, .{ .expand = .horizontal });
            defer row.deinit();

            // `gravity_y = 1` instead of a spacer above each button: on one line
            // the row is exactly one control tall, so gravity is a no-op and the
            // three controls share a top *and* a bottom edge; once the entry
            // grows, the same gravity keeps the buttons beside its last line.
            // The spacers this replaces are what made the tops ragged — each
            // control fell to the bottom from a different height.
            result.attach_clicked = ds.iconButton(@src(), "paperclip", ds.icons.paperclip)
                .variant(.ghost)
                .size(.sm)
                .gravityY(1.0)
                .draw();

            const entry = self.drawEntry();
            was_focused.* = entry.focused;
            if (entry.enter_pressed and !isBlank(entry.text)) result.submitted = true;
            if (entry.escape_pressed) result.interrupted = true;

            if (self.is_busy) {
                if (ds.button(@src(), "Stop").variant(.danger).size(.sm).icon("square", ds.icons.square).iconFirst().gravityY(1.0).draw()) {
                    result.interrupted = true;
                }
            } else {
                if (ds.button(@src(), "Send").variant(.filled).size(.sm).icon("send", ds.icons.send).disabled(isBlank(entry.text)).gravityY(1.0).draw()) {
                    result.submitted = true;
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
        const font = composerFont();
        const metrics = composerMetrics(ds.pixelScale());

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
        }, entryOpts(font, metrics).override(.{ .tag = self.tag_val }));

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

    /// Stable per-instance key for cross-frame state (focus).
    ///
    /// Extended from the *parent* as well as the caller's `@src()`, the way dvui
    /// derives every other widget id. Hashing the source line and column alone
    /// looks stable and is not: two composers drawn from one helper function
    /// share a source location, so they shared a focus flag — click the last one
    /// and the first one lit up. `idExtra` was the only way out, and needing it
    /// for correctness rather than for a loop is a trap.
    fn identity(self: Composer) dvui.Id {
        return dvui.parentGet().extendId(self.src, self.id_extra);
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

/// Everything the composer's height is made of, in logical px, each already
/// rounded to a whole number of physical pixels at `scale`.
///
/// It is a function rather than a pile of constants because the answer depends
/// on the display: `(control - line) / 2` is 3.75 logical px, which is 6.5625
/// physical at 175 % — and an entry padded by a half pixel is an entry whose
/// text sits half a pixel off centre and whose box is half a pixel off the grid.
pub const Metrics = struct {
    /// Every control in the row is this tall.
    control_height: f32,
    /// The frame's padding inside its border.
    frame_padding: f32,
    /// The frame's border.
    border: f32,
    /// Padding above and below the entry's text, centring one line in
    /// `control_height`.
    entry_padding_y: f32,
    /// The entry's content height for one row — what each further line adds.
    entry_row: f32,
    /// A composer holding one line, outer height.
    single_line_height: f32,
};

/// The font the entry and its placeholder are set in: the same one
/// `ds.chat.message` and `ds.chat.markdown` set body text in, because the
/// composer is where that body text is written.
pub fn composerFont() dvui.Font {
    return ds.font(tokens.current.font_size_md);
}

pub fn composerMetrics(scale: f32) Metrics {
    const theme = tokens.current;
    const control = ds.snapPx(theme.chrome_control_height, scale);
    const border = ds.borderPx(theme.border_width, scale);
    // `space_sm` is the *outer* inset — border plus padding — so the frame comes
    // out at control + 2·space_sm however thick the border is at this scale.
    const inset = ds.snapPx(theme.space_sm, scale);
    const padding = @max(0, inset - border);
    const line = lineBox(scale);
    const padding_y = ds.snapPx(@max(0, (control - line) / 2), scale);
    return .{
        .control_height = control,
        .frame_padding = padding,
        .border = border,
        .entry_padding_y = padding_y,
        // Derived from the remainder, not from the line: `control - 2·padding_y`
        // leaves nothing over, so the entry's outer height is *exactly* the
        // control height rather than a rounding away from it.
        .entry_row = @max(0, control - 2 * padding_y),
        .single_line_height = control + 2 * (padding + border),
    };
}

/// One line of `font`, or a nominal line with no window to measure against.
fn lineBoxOf(font: dvui.Font) f32 {
    if (dvui.current_window == null) {
        return @as(f32, @floatFromInt(tokens.current.font_size_md)) * 1.55;
    }
    return font.lineHeight();
}

/// One line of the entry's font, snapped. Falls back to a nominal 1.55 × the
/// font size with no window to ask (`opts` resolvers are unit-tested with no
/// font cache); the value only feeds `entry_padding_y`, which is asserted for
/// snapping rather than for a particular number.
fn lineBox(scale: f32) f32 {
    if (dvui.current_window == null) {
        return ds.snapPx(@as(f32, @floatFromInt(tokens.current.font_size_md)) * 1.55, scale);
    }
    return ds.snapPx(composerFont().lineHeight(), scale);
}

/// The container: `surface_1`, a strong border that turns accent while focused.
pub fn frameOpts(focused: bool) dvui.Options {
    const theme = tokens.current;
    const metrics = composerMetrics(ds.pixelScale());
    return .{
        .expand = .horizontal,
        .background = true,
        .color_fill = .{ .color = theme.surface_1 },
        .color_border = .{ .color = if (focused) theme.accent.opacity(0.6) else theme.border_strong },
        .border = dvui.Rect.all(metrics.border),
        .corners = dvui.CornerRect.round(theme.radius_md),
        .padding = dvui.Rect.all(metrics.frame_padding),
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

/// The bare multi-line entry: no chrome of its own, one to eight rows tall, and
/// on one row exactly `chrome_control_height` from top to bottom so it matches
/// the buttons either side of it instead of towering over them.
pub fn entryOpts(font: dvui.Font, metrics: Metrics) dvui.Options {
    const theme = tokens.current;
    return .{
        .expand = .horizontal,
        .background = false,
        .border = dvui.Rect.all(0),
        .margin = dvui.Rect.all(0),
        .padding = ds.paddingXY(theme.space_2xs, metrics.entry_padding_y),
        .color_text = .{ .color = theme.text_primary },
        .font = font,
        .min_size_content = .{ .w = 0, .h = metrics.entry_row * min_rows },
        .max_size_content = .{
            .w = dvui.max_float_safe,
            .h = metrics.entry_row + (max_rows - 1) * lineBoxOf(font),
        },
    };
}

/// The key hint under the box: muted mono caption, its own line box pinned to a
/// whole number of physical pixels and indented to the frame's inner edge.
pub fn hintOpts(font: dvui.Font) dvui.Options {
    const theme = tokens.current;
    const scale = ds.pixelScale();
    const line = if (dvui.current_window == null)
        ds.snapPx(@as(f32, @floatFromInt(theme.font_size_sm)) * 1.3, scale)
    else
        ds.snapPx(font.textHeight(), scale);
    return .{
        .font = font,
        .color_text = .{ .color = theme.text_muted },
        .padding = ds.paddingXY(theme.space_sm, 0),
        .margin = dvui.Rect.all(0),
        .min_size_content = .{ .w = 0, .h = line },
        .max_size_content = .height(line),
    };
}

fn hintFont() dvui.Font {
    return dvui.Font.theme(.mono).withSize(@floatFromInt(tokens.current.font_size_sm));
}

test {
    _ = @import("composer_tests.zig");
}
