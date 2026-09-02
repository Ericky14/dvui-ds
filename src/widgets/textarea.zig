/// TextArea — multi-line themed text input for dvui-ds.
///
/// Like `textInput`, but multi-line: wraps long lines, scrolls vertically, and
/// sizes its visible height by `rows`. Supports an optional label + helper text,
/// error state, placeholder, and disabled state.
///
/// Usage:
///   ds.textarea(@src(), &my_buffer).draw();
///   ds.textarea(@src(), &my_buffer).rows(6).placeholder("Notes…").draw();
///   ds.textarea(@src(), &my_buffer).label("Bio").helper("Tell us about yourself").draw();
///   ds.textarea(@src(), &my_buffer).err(true).helper("Required").draw();
const std = @import("std");
const dvui = @import("dvui");
const ds = @import("../ds.zig");
const tokens = @import("../tokens.zig");

const TextOption = dvui.TextEntryWidget.InitOptions.TextOption;

pub fn textarea(src: std.builtin.SourceLocation, buffer: []u8) TextArea {
    return .{ .src = src, .text = .{ .buffer = buffer } };
}

/// Create a text area from an advanced TextOption (buffer_dynamic, array_list, …).
pub fn textareaAdvanced(src: std.builtin.SourceLocation, text: TextOption) TextArea {
    return .{ .src = src, .text = text };
}

pub const TextArea = struct {
    src: std.builtin.SourceLocation,
    text: TextOption,
    visible_rows: f32 = 4,
    fixed_width: ?f32 = null,
    placeholder_text: ?[]const u8 = null,
    label_text: ?[]const u8 = null,
    helper_text: ?[]const u8 = null,
    is_error: bool = false,
    is_disabled: bool = false,
    input_expand: ?dvui.Options.Expand = null,
    id_extra_val: usize = 0,

    /// Set the visible height in text rows (default 4).
    pub fn rows(self: TextArea, n: u32) TextArea {
        var t = self;
        t.visible_rows = @floatFromInt(n);
        return t;
    }

    /// Disambiguate instances built from the same `@src()` (loops / lists).
    pub fn idExtra(self: TextArea, val: usize) TextArea {
        var t = self;
        t.id_extra_val = val;
        return t;
    }

    /// Pin the input to a fixed width (logical px). The text wraps within this
    /// width and the box never grows as you type. Mutually exclusive with
    /// `expand` (a fixed width wins).
    pub fn width(self: TextArea, px: f32) TextArea {
        var t = self;
        t.fixed_width = px;
        return t;
    }

    /// Set placeholder text (shown when empty).
    pub fn placeholder(self: TextArea, text: []const u8) TextArea {
        var t = self;
        t.placeholder_text = text;
        return t;
    }

    /// Set a label above the input.
    pub fn label(self: TextArea, text: []const u8) TextArea {
        var t = self;
        t.label_text = text;
        return t;
    }

    /// Set helper text below the input.
    pub fn helper(self: TextArea, text: []const u8) TextArea {
        var t = self;
        t.helper_text = text;
        return t;
    }

    /// Set error state (red border + helper turns red).
    pub fn err(self: TextArea, val: bool) TextArea {
        var t = self;
        t.is_error = val;
        return t;
    }

    /// Set disabled state.
    pub fn disabled(self: TextArea, val: bool) TextArea {
        var t = self;
        t.is_disabled = val;
        return t;
    }

    /// Expand to fill available space.
    pub fn expand(self: TextArea, val: dvui.Options.Expand) TextArea {
        var t = self;
        t.input_expand = val;
        return t;
    }

    /// Draw the text area (with optional label/helper).
    pub fn draw(self: TextArea) void {
        const theme = tokens.current;

        // Disabled opacity wrapper
        var opacity: ?ds.Opacity = null;
        if (self.is_disabled) {
            opacity = ds.withOpacity(theme.opacity_disabled);
        }
        defer if (opacity) |o| o.restore();

        // Use caller src hash (+ optional idExtra for loops) as id_extra so each
        // instance gets unique child IDs.
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
        // Use focus state from previous frame to set border color (focus persists).
        const focus_key: dvui.Id = @fromBackingInt(@intCast(id_extra));
        const was_focused = dvui.dataGetPtrDefault(null, focus_key, "_ds_focused", bool, false);

        const border_color = if (self.is_error)
            (if (was_focused.*) theme.destructive.opacity(0.6) else theme.destructive.opacity(0.4))
        else if (was_focused.*)
            theme.accent.opacity(0.4)
        else
            theme.border_input;

        // A plain box draws the border/padding and gives the inner multiline
        // entry a *definite* width to wrap into. The entry (expand .both) fills
        // the box; `break_lines` wraps long lines so content never needs
        // horizontal scroll.
        //
        // The trick that stops it growing as you type is `min == max` on the
        // box's content size — the same thing dvui does automatically for
        // single-line entries (TextEntryWidget pins max = min when !multiline,
        // but NOT for multiline, which is why a bare multiline entry grows).
        // `minSizeSetAndRefresh` caps a widget's min size (including the child
        // entry's ever-growing content width) to `max_size_content`, so pinning
        // both to the same value makes the box rigid. `placeIn` ignores
        // `max_size_content`, so `expand` still fills a wider parent past it.
        //   • fixed (`.width(px)`): min == max == px → exact width; or
        //   • default: min == max == a 14-"M" natural width (matches single-line
        //     entries), `expand .horizontal` fills any wider parent.
        // Height is always pinned to `rows`; overflow scrolls vertically.
        const content_h = @round(self.visible_rows * ds.font(theme.font_size_md).lineHeight());
        const natural_w = ds.font(theme.font_size_md).sizeM(14, 1).w;
        const box_opts: dvui.Options = if (self.fixed_width) |fixed| .{
            .background = true,
            .color_fill = .{ .color = .{ .r = 0, .g = 0, .b = 0, .a = 0 } },
            .color_border = .{ .color = border_color },
            .corners = dvui.CornerRect.round(theme.radius_md),
            .border = dvui.Rect.all(theme.border_width),
            .padding = ds.paddingXY(12, 8),
            .expand = .none,
            .min_size_content = .{ .w = fixed, .h = content_h },
            .max_size_content = .size(.{ .w = fixed, .h = content_h }),
            .id_extra = id_extra,
        } else .{
            .background = true,
            .color_fill = .{ .color = .{ .r = 0, .g = 0, .b = 0, .a = 0 } },
            .color_border = .{ .color = border_color },
            .corners = dvui.CornerRect.round(theme.radius_md),
            .border = dvui.Rect.all(theme.border_width),
            .padding = ds.paddingXY(12, 8),
            .expand = self.input_expand orelse .horizontal,
            .min_size_content = .{ .w = natural_w, .h = content_h },
            .max_size_content = .size(.{ .w = natural_w, .h = content_h }),
            .id_extra = id_extra,
        };
        var frame = dvui.box(@src(), .{ .dir = .vertical }, box_opts);

        var te = dvui.textEntry(self.src, .{
            .text = self.text,
            .placeholder = self.placeholder_text,
            .placeholder_color = theme.text_ghost,
            .multiline = true,
            .break_lines = true,
            .scroll_horizontal = false,
            .focus_border = false,
        }, .{
            .expand = .both,
            .background = false,
            .border = dvui.Rect.all(0),
            .margin = dvui.Rect.all(0),
            .padding = dvui.Rect.all(0),
            .color_text = .{ .color = theme.text_primary },
            .font = ds.font(theme.font_size_md),
        });

        // Update focus state for next frame
        was_focused.* = if (dvui.focusedWidgetId()) |fid| te.data().id == fid else false;

        te.deinit();
        frame.deinit();

        // ─── Helper text ─────────────────────────────────────────────────
        if (self.helper_text) |hlp| {
            const helper_color = if (self.is_error) theme.destructive else theme.text_muted;
            dvui.labelNoFmt(@src(), hlp, .{}, .{
                .color_text = .{ .color = helper_color },
                .font = ds.font(theme.font_size_sm),
                .id_extra = id_extra,
            });
        }
    }
};

test {
    _ = @import("textarea_tests.zig");
}
