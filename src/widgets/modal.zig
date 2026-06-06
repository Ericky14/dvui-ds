/// Modal — Material 3 dialog wrapping `dvui.floatingWindow` in modal mode.
///
/// Opens a centered floating window over a dimmed scrim (dvui paints the scrim
/// for modal windows). Themed as an M3 dialog: surface_2 fill, rounded corners,
/// a soft drop shadow, and (optionally) a bold title header drawn inside. The
/// dialog fades in on open and fades out on close (the modal keeps drawing until
/// the close animation finishes), and clicking the scrim outside the dialog
/// dismisses it.
///
/// `draw()` returns `?Handle` — null while fully closed. When non-null, draw the
/// body, then `deinit()` the handle. Toggle visibility with the `*bool` you pass
/// in; set it false (a Close button, or a scrim click) to dismiss.
///
/// Usage:
///   if (ds.modal(@src(), &open).title("Delete file?").draw()) |dialog| {
///       defer dialog.deinit();
///       ds.label(@src(), "This action cannot be undone.").style(.muted).draw();
///       ds.gap(@src(), ds.tokens.current.space_lg);
///       if (ds.button(@src(), "Close").variant(.filled).draw()) open = false;
///   }
const std = @import("std");
const dvui = @import("dvui");
const ds = @import("../ds.zig");
const tokens = @import("../tokens.zig");
const anim = @import("../anim/anim.zig");
const motion = @import("../motion.zig");

/// Default dialog content width in logical pixels.
const default_width: f32 = 360;

pub fn modal(src: std.builtin.SourceLocation, open: *bool) Modal {
    return .{ .src = src, .open = open };
}

/// Live dialog handle — draw the body into it, then `deinit()`.
pub const Handle = struct {
    fw: *dvui.FloatingWindowWidget,
    opacity: ds.Opacity,

    pub fn deinit(self: Handle) void {
        self.fw.deinit();
        self.opacity.restore();
    }
};

pub const Modal = struct {
    src: std.builtin.SourceLocation,
    open: *bool,
    title_text: ?[]const u8 = null,
    width_val: f32 = default_width,

    /// Set a bold title header drawn at the top of the dialog body.
    pub fn title(self: Modal, text: []const u8) Modal {
        var copy = self;
        copy.title_text = text;
        return copy;
    }

    /// Override the dialog content width (logical px, default 360).
    pub fn width(self: Modal, px: f32) Modal {
        var copy = self;
        copy.width_val = px;
        return copy;
    }

    /// Open the modal window (if visible) and draw the title header. Returns a
    /// `Handle` to draw the body into and `deinit()`, or null when fully closed.
    pub fn draw(self: Modal) ?Handle {
        const theme = tokens.current;

        // Animate an open/close phase so the dialog fades out (and the scrim
        // fades) before it disappears. State is keyed off the caller's @src().
        const id: dvui.Id = @enumFromInt(@as(usize, self.src.line) +% (@as(usize, self.src.column) *% 65599));
        const phase = anim.float(id, "phase", if (self.open.*) 1.0 else 0.0, .{ .duration = motion.normal, .easing = motion.out });
        if (!self.open.* and phase < 0.01) return null;

        const radius = dvui.Rect.all(theme.radius_lg);

        // Fade the whole dialog (scrim + window + body) by the phase. Restored by
        // the handle's deinit, after the body has been drawn.
        const opacity = ds.withOpacity(phase);

        const floating_window = dvui.floatingWindow(self.src, .{
            .modal = true,
            .window_avoid = .none,
            .resize = .none,
        }, .{
            .color_fill = theme.surface_2,
            .corner_radius = radius,
            .border = dvui.Rect.all(theme.border_width),
            .color_border = theme.border,
            .padding = ds.padding(theme.space_lg),
            .box_shadow = .{
                .color = .black,
                .corner_radius = radius,
                .offset = .{ .x = 0, .y = 4 },
                .fade = 14,
                .alpha = 0.4,
            },
            .max_size_content = .width(self.width_val),
        });

        // Dismiss on a click outside the dialog (on the scrim). The modal window
        // receives all mouse events, so a press not inside its rect is a scrim
        // click. This sets the caller's flag, triggering the fade-out.
        const win_rect = floating_window.data().rectScale().r;
        for (dvui.events()) |*e| {
            if (e.evt == .mouse) {
                const me = e.evt.mouse;
                if (me.action == .press and me.button.pointer() and !win_rect.contains(me.p)) {
                    self.open.* = false;
                }
            }
        }

        if (self.title_text) |text| {
            dvui.labelNoFmt(@src(), text, .{}, .{
                .font = ds.fontBold(theme.font_size_xl),
                .color_text = theme.text_primary,
            });
            _ = dvui.spacer(@src(), .{ .min_size_content = dvui.Size.all(theme.space_md) });
        }

        return .{ .fw = floating_window, .opacity = opacity };
    }
};

test {
    _ = @import("modal_tests.zig");
}
