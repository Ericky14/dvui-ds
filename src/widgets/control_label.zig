//! **A radio's or a checkbox's label**, shared by both controls: one line beside
//! the control (the default — exactly the label it always was), or, with
//! `wrap`, lines broken at the width the row is given, the control level with
//! the FIRST line rather than centred on the whole paragraph.
//!
//! A one-line wrapped label sits where the one-line label sat: the control's
//! top is the label's top padding plus half a line, less half the control —
//! the centre the old `gravity_y = 0.5` gave it — so a short option looks the
//! same either way and only a long one grows.
const std = @import("std");
const dvui = @import("dvui");
const ds = @import("../ds.zig");
const tokens = @import("../tokens.zig");

/// The top inset of a wrapped label's text (dvui's text-layout default, which
/// equals a label's): the first line's half-height is measured from here.
fn textPadTop() f32 {
    return dvui.TextLayoutWidget.defaults.padding.?.y;
}

/// How far below the row's top the control sits so it is level with the first
/// line of a wrapped label in `font` (zero when the control is the taller).
pub fn controlTop(font: dvui.Font, control: f32) f32 {
    const offset = textPadTop() + font.sizeM(1, 1).h / 2 - control / 2;
    return if (offset > 0) ds.snapPx(offset, ds.pixelScale()) else 0;
}

/// **The control's place in a wrapped row**: a lane as tall as the row, the
/// control at its top, level with the label's first line (`controlTop`). A
/// control left at the top of a two-line row sits off the row's centre line
/// (the layout lint's `row_centre`); one in a lane the row's height does not.
/// Returns the control's own rect, for drawing it.
pub fn reserveWrapped(control: f32, font: dvui.Font) dvui.WidgetData {
    var lane = dvui.box(@src(), .{ .dir = .vertical }, .{ .expand = .vertical });
    defer lane.deinit();
    return dvui.spacer(@src(), .{ .min_size_content = dvui.Size.all(control), .margin = .{ .y = controlTop(font, control) } });
}

/// How far below the row's top a wrapped label starts so its first line is
/// level with a control taller than the line (zero otherwise).
pub fn textTop(font: dvui.Font, control: f32) f32 {
    const offset = control / 2 - textPadTop() - font.sizeM(1, 1).h / 2;
    return if (offset > 0) ds.snapPx(offset, ds.pixelScale()) else 0;
}

/// Draw `text` as the control's label in `font`. `wrap` breaks it at the row's
/// width (the row must expand horizontally); otherwise it is one line, centred
/// on the control as before. `src` is the control's own call site, so a dump
/// names the radio or the checkbox that drew the words.
pub fn draw(src: std.builtin.SourceLocation, text: []const u8, font: dvui.Font, wrap: bool, control: f32) void {
    const theme = tokens.current;
    if (!wrap) {
        dvui.labelNoFmt(src, text, .{}, .{
            .color_text = .{ .color = theme.text_primary },
            .font = font,
            .gravity_y = 0.5,
        });
        return;
    }
    var layout = dvui.textLayout(src, .{ .break_lines = true }, .{
        .expand = .horizontal,
        .background = false,
        .margin = .{ .y = textTop(font, control) },
        .color_text = .{ .color = theme.text_primary },
        .font = font,
    });
    defer layout.deinit();
    layout.addText(text, .{});
}
