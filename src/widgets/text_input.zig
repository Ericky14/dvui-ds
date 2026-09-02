/// TextInput — themed text input field for dvui-ds.
///
/// Matches the Playtron DS spec: sized (sm/md/lg), states (default/focus/error/disabled),
/// optional label + helper text, rounded border, placeholder support.
///
/// Usage:
///   ds.textInput(@src(), &my_buffer).draw();
///   ds.textInput(@src(), &my_buffer).size(.lg).placeholder("Email").draw();
///   ds.textInput(@src(), &my_buffer).label("Name").helper("How others see you").draw();
///   ds.textInput(@src(), &my_buffer).err(true).helper("Invalid email").draw();
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

    /// Draw the text input (with optional label/helper).
    pub fn draw(self: TextInput) void {
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
                .color_text = theme.text_secondary,
                .font = ds.fontMedium(theme.font_size_sm),
                .id_extra = id_extra,
            });
        }

        // ─── Input field ─────────────────────────────────────────────────
        // Use focus state from previous frame to set border color (focus persists across frames)
        const focus_key: dvui.Id = @fromBackingInt(@intCast(id_extra));
        const was_focused = dvui.dataGetPtrDefault(null, focus_key, "_ds_focused", bool, false);

        const border_color = if (self.is_error)
            (if (was_focused.*) theme.destructive.opacity(0.6) else theme.destructive.opacity(0.4))
        else if (was_focused.*)
            theme.accent.opacity(0.4)
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
        was_focused.* = if (dvui.focusedWidgetId()) |fid| te.data().id == fid else false;

        te.deinit();

        // ─── Helper text ─────────────────────────────────────────────────
        if (self.helper_text) |hlp| {
            const helper_color = if (self.is_error) theme.destructive else theme.text_muted;
            dvui.labelNoFmt(@src(), hlp, .{}, .{
                .color_text = helper_color,
                .font = ds.font(theme.font_size_sm),
                .id_extra = id_extra,
            });
        }
    }

    pub fn inputOpts(self: TextInput, border_color: Color) dvui.Options {
        // CSS spec per size:
        //   sm: h-7 (28px), text-[12px], px-2.5 (10px)
        //   md: h-8 (32px), text-[13px], px-3   (12px)
        //   lg: h-10(40px), text-[14px], px-3.5 (14px)
        const font_size: u16 = switch (self.input_size) {
            .sm => 12,
            .md => 13,
            .lg => 14,
        };
        // Vertical padding: (height - line_height) / 2
        // Approximate line heights: 12px→16, 13px→17, 14px→18
        //   sm: (28-16)/2 = 6px,  md: (32-17)/2 ≈ 8px,  lg: (40-18)/2 = 11px
        const pad = switch (self.input_size) {
            .sm => ds.paddingXY(10, 6),
            .md => ds.paddingXY(12, 8),
            .lg => ds.paddingXY(14, 11),
        };

        return .{
            .color_fill = .{ .r = 0, .g = 0, .b = 0, .a = 0 },
            .color_border = border_color,
            .color_text = tokens.current.text_primary,
            .corner_radius = dvui.Rect.all(tokens.current.radius_md),
            .border = dvui.Rect.all(tokens.current.border_width),
            .padding = pad,
            .font = ds.font(font_size),
            .expand = if (self.input_expand) |e| e else .horizontal,
        };
    }
};

test {
    _ = @import("text_input_tests.zig");
}
