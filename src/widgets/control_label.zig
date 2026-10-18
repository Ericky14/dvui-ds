//! **A radio's or a checkbox's label**, shared by both controls: one line beside
//! the control (the default — exactly the label it always was), or, with
//! `wrap`, lines broken at the width the row is given, the control level with
//! the FIRST line rather than centred on the whole paragraph.
//!
//! A one-line wrapped label sits where the one-line label sat: the control's
//! top is half of what a one-line label's box leaves over it — the centre the
//! old `gravity_y = 0.5` gave it, to the physical pixel — so a short option
//! looks the same either way and only a long one grows (the question card
//! tests hold the row, the control and the words equal at 1.0 and 1.75).
const std = @import("std");
const dvui = @import("dvui");
const ds = @import("../ds.zig");
const tokens = @import("../tokens.zig");

/// `length` grown to whole physical pixels, as dvui grows every widget's min
/// size under `snap_to_pixels` (`minSizeSetAndRefresh`); unchanged without it.
/// For a widget that centres something by hand where gravity once did.
pub fn ceilPx(length: f32) f32 {
    if (!dvui.snapToPixels()) return length;
    const scale = ds.pixelScale();
    if (!(scale > 0) or length <= 0) return length;
    return @ceil(length * scale - 0.001) / scale;
}

/// How tall a ONE-line label in `font` is laid out: its line and its padding,
/// grown to whole pixels. The plain control was centred in this box.
fn lineBox(font: dvui.Font) f32 {
    const padding = dvui.LabelWidget.defaults.paddingGet();
    return ceilPx(padding.y + font.sizeM(1, 1).h + padding.h);
}

/// How far below the row's top the control sits so it is level with the first
/// line of a wrapped label in `font` (zero when the control is the taller).
///
/// The offset is the plain row's centring, `(line box − control) / 2`, and is
/// deliberately NOT snapped here: dvui puts the control's edge on a pixel the
/// same way it put the centred control's (half up), so a one-line option draws
/// exactly where it did. Snapping the offset first rounded 5.5 px to 5 where
/// dvui rounds the edge to 6 — every circle a pixel high in the engine's chat.
pub fn controlTop(font: dvui.Font, control: f32) f32 {
    return @max(0, (lineBox(font) - ceilPx(control)) / 2);
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
/// Like `controlTop`, the plain row's centring, left for dvui to snap.
pub fn textTop(font: dvui.Font, control: f32) f32 {
    return @max(0, (ceilPx(control) - lineBox(font)) / 2);
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
