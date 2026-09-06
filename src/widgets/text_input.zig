/// TextInput — themed text input field for dvui-ds.
///
/// Matches the Playtron DS spec: sized (sm/md/lg), states (default/focus/error/disabled),
/// optional label + helper text, rounded border, placeholder support.
///
/// Usage:
///   _ = ds.textInput(@src(), &my_buffer).draw();
///   _ = ds.textInput(@src(), &my_buffer).size(.lg).placeholder("Email").draw();
///   _ = ds.textInput(@src(), &my_buffer).label("Name").helper("How others see you").draw();
///   if (ds.textInput(@src(), &my_buffer).placeholder("Folder").draw().enter_pressed) open(text);
const std = @import("std");
const dvui = @import("dvui");
const ds = @import("../ds.zig");
const tokens = @import("../tokens.zig");

const Color = dvui.Color;
const TextOption = dvui.TextEntryWidget.InitOptions.TextOption;

pub fn textInput(src: std.builtin.SourceLocation, buffer: []u8) TextInput {
    return .{ .src = src, .text = .{ .buffer = buffer } };
}

/// Create a text input from an advanced TextOption (buffer_dynamic, array_list, etc).
pub fn textInputAdvanced(src: std.builtin.SourceLocation, text: TextOption) TextInput {
    return .{ .src = src, .text = text };
}

pub const TextInput = struct {
    src: std.builtin.SourceLocation,
    text: TextOption,
    input_size: tokens.Size = .md,
    placeholder_text: ?[]const u8 = null,
    label_text: ?[]const u8 = null,
    helper_text: ?[]const u8 = null,
    is_error: bool = false,
    is_disabled: bool = false,
    is_password: bool = false,
    input_expand: ?dvui.Options.Expand = null,
    id_extra_val: usize = 0,

    /// Set the input size (sm, md, lg).
    pub fn size(self: TextInput, val: tokens.Size) TextInput {
        var t = self;
        t.input_size = val;
        return t;
    }

    /// Disambiguate instances built from the same `@src()` (loops / lists).
    pub fn idExtra(self: TextInput, val: usize) TextInput {
        var t = self;
        t.id_extra_val = val;
        return t;
    }

    /// Set placeholder text (shown when empty).
    pub fn placeholder(self: TextInput, text: []const u8) TextInput {
        var t = self;
        t.placeholder_text = text;
        return t;
    }

    /// Set a label above the input.
    pub fn label(self: TextInput, text: []const u8) TextInput {
        var t = self;
        t.label_text = text;
        return t;
    }

    /// Set helper text below the input.
    pub fn helper(self: TextInput, text: []const u8) TextInput {
        var t = self;
        t.helper_text = text;
        return t;
    }

    /// Set error state (red border + helper turns red).
    pub fn err(self: TextInput, val: bool) TextInput {
        var t = self;
        t.is_error = val;
        return t;
    }

    /// Set disabled state.
    pub fn disabled(self: TextInput, val: bool) TextInput {
        var t = self;
        t.is_disabled = val;
        return t;
    }

    /// Set password mode (masks input).
    pub fn password(self: TextInput, val: bool) TextInput {
        var t = self;
        t.is_password = val;
        return t;
    }

    /// Expand to fill available space.
    pub fn expand(self: TextInput, val: dvui.Options.Expand) TextInput {
        var t = self;
        t.input_expand = val;
        return t;
    }

    /// What one drawn field reports back. Every caller that only wants pixels
    /// ignores it (`_ = ds.textInput(…).draw();`); a form reads `enter_pressed`
    /// instead of hand-rolling a `dvui.TextEntryWidget` beside this one, which
    /// is how a second copy of the sizing rules gets written and drifts.
    pub const Result = struct {
        /// Enter (or the keypad's Enter) went DOWN in this field this frame.
        /// Always false for a multi-line field — see `ds.textarea`.
        enter_pressed: bool = false,
        /// The field holds keyboard focus.
        focused: bool = false,
        /// Its text changed this frame.
        changed: bool = false,
    };

    /// Draw the text input (with optional label/helper).
    pub fn draw(self: TextInput) Result {
        const theme = tokens.current;

        // Disabled opacity wrapper
        var opacity: ?ds.Opacity = null;
        if (self.is_disabled) {
            opacity = ds.withOpacity(theme.opacity_disabled);
        }
        defer if (opacity) |o| o.restore();

        // Use caller src hash (+ optional idExtra for loops) as id_extra so each
        // textInput instance gets unique child IDs.
        const id_extra = @as(usize, self.src.line) +% (@as(usize, self.src.column) *% 65599) +% self.id_extra_val;

        // Outer column for label + input + helper
        var col = dvui.box(@src(), .{ .dir = .vertical, .gap = theme.space_2xs }, .{
            .expand = self.input_expand,
            .id_extra = id_extra,
        });
        defer col.deinit();

        // ─── Label ───────────────────────────────────────────────────────
        if (self.label_text) |lbl| {
            dvui.labelNoFmt(@src(), lbl, .{}, .{
                .color_text = .{ .color = theme.text_secondary },
                .font = ds.fontMedium(theme.font_size_sm),
                .id_extra = id_extra,
            });
        }

        // ─── Input field ─────────────────────────────────────────────────
        // Use focus state from previous frame to set border color (focus persists across frames)
        const focus_key: dvui.Id = @fromBackingInt(@intCast(id_extra));
        const was_focused = dvui.dataGetPtrDefault(null, focus_key, "_ds_focused", bool, false);

        // ⚠ **A ring is the ink itself, never the ink at an alpha.** A colour at
        // 0.4 over a near-black input composites to the same murky slate
        // whatever the hue was — the accent and the destructive focus rings were
        // within a few points of each other, and neither read as a ring. This is
        // the rule the whole accent pass turned on (`d800c43`); the unfocused
        // state stays `border_input`, so the focus is still a CHANGE.
        const border_color = if (self.is_error)
            theme.destructive
        else if (was_focused.*)
            theme.accent
        else
            theme.border_input;

        var te = dvui.textEntry(self.src, .{
            .text = self.text,
            .placeholder = self.placeholder_text,
            .placeholder_color = theme.text_ghost,
            .password_char = if (self.is_password) "●" else null,
            .focus_border = false,
        }, self.inputOpts(border_color));

        // Update focus state for next frame
        const focused = if (dvui.focusedWidgetId()) |fid| te.data().id == fid else false;
        was_focused.* = focused;
        const result: Result = .{
            .enter_pressed = te.enter_pressed,
            .focused = focused,
            .changed = te.text_changed,
        };

        te.deinit();

        // ─── Helper text ─────────────────────────────────────────────────
        if (self.helper_text) |hlp| {
            const helper_color = if (self.is_error) theme.destructive else theme.text_muted;
            dvui.labelNoFmt(@src(), hlp, .{}, .{
                .color_text = .{ .color = helper_color },
                .font = ds.font(theme.font_size_sm),
                .id_extra = id_extra,
            });
        }
        return result;
    }

    /// The CSS spec's pixel table — the one set of literals this widget names.
    /// `height` is the control's border-box height; `pad_x` its horizontal
    /// inset; `font_size` the text.
    ///
    ///   sm: h-7 (28px), text-[12px], px-2.5 (10px)
    ///   md: h-8 (32px), text-[13px], px-3   (12px)
    ///   lg: h-10(40px), text-[14px], px-3.5 (14px)
    ///
    /// ⚠ There is **no vertical padding in the table**. It used to hold one,
    /// derived at authoring time from "approximate line heights 12px→16,
    /// 13px→17, 14px→18" — an approximation of a number the FONT decides. This
    /// face measures 15.60 / 16.90 / 18.20, so the guess was over on two sizes
    /// and under on the third, and none of it mattered next to the real defect:
    /// dvui sized the box in a different font entirely. `pad_y` is measured
    /// now; see `inputOpts`.
    const Spec = struct {
        height: f32,
        pad_x: f32,
        font_size: u16,
    };

    fn spec(which: tokens.Size) Spec {
        return switch (which) {
            .sm => .{ .height = 28, .pad_x = 10, .font_size = 12 },
            .md => .{ .height = 32, .pad_x = 12, .font_size = 13 },
            .lg => .{ .height = 40, .pad_x = 14, .font_size = 14 },
        };
    }

    /// One line of `font`, in logical pixels — **measured**, so it is the box
    /// the glyphs are actually drawn in.
    ///
    /// Outside a frame there is no font cache to measure with, so this answers
    /// the CSS table's own approximation (`size + 4`: 12→16, 13→17, 14→18) and
    /// `inputOpts` stays callable from a plain unit test — the same courtesy
    /// `ds.pixelScale` extends. Nothing is DRAWN outside a frame, so the
    /// approximation can never reach a pixel.
    fn lineBox(which: tokens.Size) f32 {
        const measurements = spec(which);
        if (dvui.current_window == null) return @as(f32, @floatFromInt(measurements.font_size)) + 4;
        return ds.font(measurements.font_size).textHeight();
    }

    /// **The options the entry is built with — sized by the font it will draw
    /// in, not by the theme's.**
    ///
    /// ⚠ This is the trap the whole widget turns on. `dvui.TextEntryWidget.init`
    /// sizes a field from `defaults.min_sizeM(defaultMWidth, 1)` and then, for a
    /// single-line field, CAPS it (`max_size_content = min_size_content`). Both
    /// happen before `options.override(opts)`, so the `.font` below arrives too
    /// late to move the box, and `defaults` has no font — meaning the height is
    /// measured in the **theme's body font**, whichever face that is. On the
    /// engine's theme it is 14.30 logical px while an `md` field draws in a
    /// 16.90 px one, so every descender was sliced 2.60 px short with nothing in
    /// any layout rule able to see it (the welcome sheet's `C:\games\MyGame`,
    /// 2026-09-06). The storybook's own theme hid it: its body font is the same
    /// 13 px as `md`, so only `lg` clipped there.
    ///
    /// So the box is stated here, from `lineBox`:
    ///
    ///  - `pad_y` is **derived**, never tabulated: half of whatever the spec
    ///    height has left over after the line box and the two borders, snapped
    ///    DOWN to a whole physical pixel (`ds.snapDownPx`) so the total stays
    ///    exactly `height` and lands on the pixel grid at 1.75 as well as at 1
    ///    and 2;
    ///  - the content height is then `height - 2·pad_y - 2·border`, and never
    ///    less than the line box: a face too tall for its spec height makes the
    ///    control taller rather than cutting the text.
    ///
    /// The width is `dvui`'s own default rule (14 M's) measured in the same
    /// font; outside a frame it is 0, which is the honest answer for "how wide
    /// are these glyphs" with no font cache to ask.
    pub fn inputOpts(self: TextInput, border_color: Color) dvui.Options {
        const measurements = spec(self.input_size);
        const scale = ds.pixelScale();
        const edge = ds.borderPx(tokens.current.border_width, scale);
        const line = lineBox(self.input_size);
        const pad_y = ds.snapDownPx(@max(0, (measurements.height - line - 2 * edge) / 2), scale);
        const content_h = @max(line, measurements.height - 2 * pad_y - 2 * edge);
        const font = ds.font(measurements.font_size);
        const content_w = if (dvui.current_window == null) 0 else font.sizeM(dvui.TextEntryWidget.defaultMWidth, 1).w;

        return .{
            .color_fill = .{ .color = .{ .r = 0, .g = 0, .b = 0, .a = 0 } },
            .color_border = .{ .color = border_color },
            .color_text = .{ .color = tokens.current.text_primary },
            .corners = dvui.CornerRect.round(tokens.current.radius_md),
            .border = .{ .x = edge, .y = edge, .w = edge, .h = edge },
            .padding = ds.paddingEach(pad_y, measurements.pad_x, pad_y, measurements.pad_x),
            .min_size_content = .{ .w = content_w, .h = content_h },
            // The width is a FLOOR, not a size: an expanding field takes its
            // row. Only the height is pinned, and pinning it is what stops
            // dvui capping the field at a box measured in the wrong font.
            .max_size_content = .{ .w = dvui.max_float_safe, .h = content_h },
            .font = font,
            .expand = if (self.input_expand) |e| e else .horizontal,
        };
    }
};

test {
    _ = @import("text_input_tests.zig");
}
