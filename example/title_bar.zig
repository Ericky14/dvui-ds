//! The storybook's own title bar — and the worked example of `ds.windowChrome`.
//!
//! The window is borderless, so this row *is* the title bar: it names the app,
//! it is where the window is dragged from, and it carries the three caption
//! buttons the OS used to draw. Everything an app has to do for a borderless
//! window is in `draw()` below, and it is four lines of declaration at the end.
const std = @import("std");
const dvui = @import("dvui");
const ds = @import("dvui_ds");

/// Draw the title bar. Returns false when the close button was pressed, which
/// is the frame function's cue to stop the loop — closing is the app's business
/// (it owns whatever has to be saved first), so `ds.windowChrome` does not do
/// it.
pub fn draw(title: []const u8) bool {
    const theme = ds.tokens.current;
    var keep_running = true;

    var bar = dvui.box(@src(), .{ .dir = .horizontal, .gap = theme.space_sm }, .{
        .expand = .horizontal,
        .background = true,
        .color_fill = .{ .color = theme.surface_1 },
        .padding = ds.paddingXY(theme.space_md, 0),
        .min_size_content = .{ .h = theme.chrome_titlebar_height },
        .border = ds.paddingEach(0, 0, ds.hairline(ds.pixelScale()), 0),
        .color_border = .{ .color = theme.border_subtle },
    });
    defer bar.deinit();

    ds.icon(@src(), ds.Source.namedIcon("circle", ds.icons.circle)).style(.accent).size(.sm).draw();
    ds.label(@src(), title).style(.secondary).gravityY(0.5).draw();

    var spacer = dvui.box(@src(), .{}, .{ .expand = .horizontal });
    spacer.deinit();

    // The three caption buttons. Each is tagged so its rect can be read back
    // and declared as a hole in the drag region — a click on close has to close
    // the window, not move it.
    if (ds.iconButton(@src(), "minus", ds.icons.minus).size(.sm).tag("chrome.minimise").draw()) {
        ds.windowChrome.minimise();
    }
    const maximise_icon = if (ds.windowChrome.maximised()) ds.icons.minimize else ds.icons.maximize;
    if (ds.iconButton(@src(), "maximize", maximise_icon).size(.sm).tag("chrome.maximise").draw()) {
        ds.windowChrome.toggleMaximise();
    }
    if (ds.iconButton(@src(), "x", ds.icons.x).variant(.danger).size(.sm).tag("chrome.close").draw()) {
        keep_running = false;
    }

    const buttons = [_]dvui.Rect{
        taggedRect("chrome.minimise"),
        taggedRect("chrome.maximise"),
        taggedRect("chrome.close"),
    };

    // The whole declaration, once the row has been laid out.
    ds.windowChrome.declare(.{
        .drag = logicalRect(bar.data().rectScale().r),
        .buttons = &buttons,
    });

    return keep_running;
}

/// Physical → dvui logical window coordinates, which is what `declare` wants.
fn logicalRect(physical: dvui.Rect.Physical) dvui.Rect {
    return dvui.windowRectScale().rectFromPhysical(physical);
}

/// A tagged widget's rect, or nothing if it has not been drawn yet.
fn taggedRect(name: []const u8) dvui.Rect {
    const found = dvui.tagGet(name) orelse return .{};
    return logicalRect(found.rect);
}
