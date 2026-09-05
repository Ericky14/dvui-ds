//! Component screenshots — headless CPU rendering via dvui's testing backend.
//!
//! Run:  zig build screenshots
//! Output: ds-screenshots/<name>.png (one per component).
//!
//! Each test renders a DS component into a Picture target and writes a PNG.
//! No GPU or window — deterministic, so these double as visual regression
//! fixtures (commit the PNGs and diff them).
const std = @import("std");
const dvui = @import("dvui");
const ds = @import("dvui_ds");

/// Where every fixture's PNG lands.
pub const image_dir = "ds-screenshots";

/// Render `frame` once (settled) and write it to ds-screenshots/<name>.
/// The dvui testing backend always rasterises at 2 physical pixels per logical
/// pixel, so this is `captureAt(..., 2.0, ...)`.
pub fn capture(name: []const u8, w: f32, h: f32, frame: dvui.App.frameFunction) !void {
    var t = try dvui.testing.init(.{
        .image_dir = image_dir,
        .window_size = .{ .w = w, .h = h },
        .window_init_opts = .{ .theme = ds.tokens.dvuiTheme() },
    });
    defer t.deinit();
    try dvui.testing.settle(frame);
    try savePng(name, frame);
}

/// Render `frame` at a chosen scale — for fixtures that have to prove chrome
/// stays aligned on a fractional-DPI display (the owner's is 1.75), not only on
/// the clean 1.0 and 2.0 the maths is easy at.
///
/// `logical_w`/`logical_h` are the layout size the widgets see; the PNG comes
/// out `logical × scale` pixels. The testing backend hard-wires its framebuffer
/// to 2× the window size it is handed, so the scale is dialled in by asking for
/// a window of `logical × scale / 2` and setting the window's own content scale
/// to `scale / 2` — the two multiply back to exactly `scale`.
pub fn captureAt(name: []const u8, logical_w: f32, logical_h: f32, scale: f32, frame: dvui.App.frameFunction) !void {
    return captureDriven(name, logical_w, logical_h, scale, frame, null);
}

/// `captureAt` with a chance to drive the UI once it has settled — click a
/// widget by tag, type into it — before the frame that is written out. A state
/// that only exists after an interaction (focus, hover, a pressed button) is not
/// a state a fixture can pass in as data, and mocking it with a flag would be a
/// screenshot of the mock rather than of the widget.
pub fn captureDriven(
    name: []const u8,
    logical_w: f32,
    logical_h: f32,
    scale: f32,
    frame: dvui.App.frameFunction,
    drive: ?*const fn () anyerror!void,
) !void {
    var t = try dvui.testing.init(.{
        .image_dir = image_dir,
        .window_size = .{ .w = logical_w * scale / 2, .h = logical_h * scale / 2 },
        .window_init_opts = .{ .theme = ds.tokens.dvuiTheme() },
    });
    defer t.deinit();
    t.window.content_scale = scale / 2;
    // `dvui.testing.init` already opened a frame at the old scale; burn one so
    // the next `begin` picks the new one up before anything is measured.
    _ = try dvui.testing.step(frame);
    try dvui.testing.settle(frame);
    if (drive) |act| {
        try act();
        _ = try dvui.testing.step(frame);
        try dvui.testing.settle(frame);
    }
    try savePng(name, frame);
}

/// Render one frame into an offscreen target and write it out as a PNG.
///
/// This is `dvui.testing.saveImage` minus its `dvui.Picture`, and the
/// difference is not cosmetic. `Picture.start` installs its own deferred-render
/// queue, so *every* deferred draw in the frame lands in one flat list that is
/// replayed by `Picture.stop()` — which `capturePng` calls **after**
/// `endRendering`. Anything that renders out of a subwindow (`FloatingWidget`,
/// and so every `ds.glass` overlay) is drawn by `endRendering` and then painted
/// straight over by the background it was supposed to float on. The app, which
/// has no Picture, orders those correctly; a screenshot taken through a Picture
/// does not, and a design system whose review artefact is the screenshot cannot
/// afford the two to disagree. Rendering to a plain target keeps dvui's own
/// subwindow ordering, so the PNG shows what the window shows.
fn savePng(name: []const u8, frame: dvui.App.frameFunction) !void {
    const cw = dvui.currentWindow();
    const area = dvui.windowRectPixels();
    const width: u32 = @intFromFloat(@round(area.w));
    const height: u32 = @intFromFloat(@round(area.h));

    const target = try dvui.textureCreateTarget(.{ .width = width, .height = height });
    const previous = dvui.renderTarget(.{ .texture = target, .offset = .{} });
    if (try frame() == .close) return error.closed;
    cw.endRendering(.{});
    _ = dvui.renderTarget(previous);

    // Frame arena, not the LIFO one: the PNG writer allocates after this and a
    // LIFO arena can only give back its most recent block.
    const premultiplied = try dvui.textureReadTarget(cw.arena(), target);
    const rgba = dvui.Color.PMA.sliceToRGBA(premultiplied);
    target.destroyLater();

    var dir = try std.Io.Dir.cwd().createDirPathOpen(dvui.io, image_dir, .{});
    defer dir.close(dvui.io);
    const file = try dir.createFile(dvui.io, name, .{});
    defer file.close(dvui.io);
    var buffer: [512]u8 = undefined;
    var writer = file.writer(dvui.io, &buffer);
    try dvui.PNGEncoder.write(&writer.interface, rgba, width, height);
    try writer.end();

    _ = try cw.end(.{});
    try cw.begin(cw.frame_time_ns + 100 * std.time.ns_per_ms);
}

/// Full-window themed background so components sit on the app surface.
pub fn background(src: std.builtin.SourceLocation) *dvui.BoxWidget {
    return dvui.box(src, .{}, .{
        .expand = .both,
        .background = true,
        .color_fill = .{ .color = ds.tokens.current.surface_0 },
    });
}

test "buttons" {
    const Local = struct {
        fn frame() !dvui.App.Result {
            var bg = background(@src());
            defer bg.deinit();
            var col = ds.column(@src()).padding(ds.tokens.current.space_lg).draw();
            defer col.deinit();
            var row = ds.row(@src()).gap(ds.tokens.current.space_sm).draw();
            defer row.deinit();
            _ = ds.button(@src(), "Primary").variant(.filled).draw();
            _ = ds.button(@src(), "Outlined").variant(.outlined).draw();
            _ = ds.button(@src(), "Ghost").variant(.ghost).draw();
            return .ok;
        }
    };
    try capture("buttons.png", 320, 90, Local.frame);
}

test "labels" {
    const Local = struct {
        fn frame() !dvui.App.Result {
            var bg = background(@src());
            defer bg.deinit();
            var col = ds.column(@src()).padding(ds.tokens.current.space_lg).gap(ds.tokens.current.space_xs).draw();
            defer col.deinit();
            ds.label(@src(), "Title").style(.title).draw();
            ds.label(@src(), "Secondary").style(.secondary).draw();
            ds.label(@src(), "Muted caption").style(.muted).draw();
            return .ok;
        }
    };
    try capture("labels.png", 260, 170, Local.frame);
}

test "text input" {
    const Local = struct {
        var buffer: [64]u8 = @splat(0);
        fn frame() !dvui.App.Result {
            var bg = background(@src());
            defer bg.deinit();
            var col = ds.column(@src()).padding(ds.tokens.current.space_lg).expand(.horizontal).draw();
            defer col.deinit();
            ds.textInput(@src(), &buffer).label("Email").helper("We'll never share it.").draw();
            return .ok;
        }
    };
    @memcpy(Local.buffer[0.."hello@example.com".len], "hello@example.com");
    try capture("text_input.png", 320, 150, Local.frame);
}

test "icon buttons" {
    const Local = struct {
        fn frame() !dvui.App.Result {
            var bg = background(@src());
            defer bg.deinit();
            var col = ds.column(@src()).padding(ds.tokens.current.space_lg).draw();
            defer col.deinit();
            var r = ds.row(@src()).gap(ds.tokens.current.space_sm).draw();
            defer r.deinit();
            _ = ds.iconButton(@src(), "cog", ds.icons.cog).variant(.filled).size(.md).draw();
            _ = ds.iconButton(@src(), "copy", ds.icons.copy).variant(.outlined).size(.md).draw();
            _ = ds.iconButton(@src(), "bell", ds.icons.bell).variant(.ghost).size(.md).draw();
            _ = ds.iconButton(@src(), "delete", ds.icons.delete).variant(.danger).size(.md).draw();
            return .ok;
        }
    };
    try capture("icon_buttons.png", 260, 80, Local.frame);
}

test "text area" {
    const Local = struct {
        var buffer: [256]u8 = @splat(0);
        fn frame() !dvui.App.Result {
            var bg = background(@src());
            defer bg.deinit();
            var col = ds.column(@src()).padding(ds.tokens.current.space_lg).expand(.horizontal).draw();
            defer col.deinit();
            ds.textarea(@src(), &buffer)
                .rows(3)
                .label("Notes")
                .helper("Wraps and scrolls vertically.")
                .draw();
            return .ok;
        }
    };
    @memcpy(
        Local.buffer[0.."The quick brown fox jumps over the lazy dog near the riverbank.".len],
        "The quick brown fox jumps over the lazy dog near the riverbank.",
    );
    try capture("text_area.png", 340, 200, Local.frame);
}

test "text area fixed width" {
    const Local = struct {
        var buffer: [256]u8 = @splat(0);
        fn frame() !dvui.App.Result {
            var bg = background(@src());
            defer bg.deinit();
            var col = ds.column(@src()).padding(ds.tokens.current.space_lg).expand(.horizontal).draw();
            defer col.deinit();
            // .width() pins the input — it wraps within 220px and never grows.
            ds.textarea(@src(), &buffer).rows(3).width(220).label("Fixed 220px").draw();
            return .ok;
        }
    };
    @memcpy(
        Local.buffer[0.."Pinned to a fixed width; long text wraps inside it.".len],
        "Pinned to a fixed width; long text wraps inside it.",
    );
    try capture("text_area_fixed.png", 320, 200, Local.frame);
}

test "cards" {
    const Local = struct {
        fn frame() !dvui.App.Result {
            var bg = background(@src());
            defer bg.deinit();
            var row = ds.row(@src()).gap(ds.tokens.current.space_md).padding(ds.tokens.current.space_xl).draw();
            defer row.deinit();
            {
                var c = ds.card(@src()).variant(.elevated).draw();
                defer c.deinit();
                ds.label(@src(), "Elevated").style(.secondary).font(.heading).draw();
                ds.gap(@src(), ds.tokens.current.space_xs);
                ds.label(@src(), "Body text").style(.muted).draw();
            }
            {
                var c = ds.card(@src()).variant(.filled).draw();
                defer c.deinit();
                ds.label(@src(), "Filled").style(.secondary).font(.heading).draw();
                ds.gap(@src(), ds.tokens.current.space_xs);
                ds.label(@src(), "Body text").style(.muted).draw();
            }
            {
                var c = ds.card(@src()).variant(.outlined).draw();
                defer c.deinit();
                ds.label(@src(), "Outlined").style(.secondary).font(.heading).draw();
                ds.gap(@src(), ds.tokens.current.space_xs);
                ds.label(@src(), "Body text").style(.muted).draw();
            }
            return .ok;
        }
    };
    try capture("cards.png", 420, 160, Local.frame);
}

test "checkboxes" {
    const Local = struct {
        var on: bool = true;
        var off: bool = false;
        var dis: bool = true;
        fn frame() !dvui.App.Result {
            var bg = background(@src());
            defer bg.deinit();
            var col = ds.column(@src()).gap(ds.tokens.current.space_md).padding(ds.tokens.current.space_xl).draw();
            defer col.deinit();
            _ = ds.checkbox(@src(), &on).label("Checked").draw();
            _ = ds.checkbox(@src(), &off).label("Unchecked").draw();
            _ = ds.checkbox(@src(), &dis).label("Disabled (checked)").disabled(true).draw();
            var sizes = ds.row(@src()).gap(ds.tokens.current.space_md).draw();
            defer sizes.deinit();
            _ = ds.checkbox(@src(), &on).size(.sm).draw();
            _ = ds.checkbox(@src(), &on).size(.md).draw();
            _ = ds.checkbox(@src(), &on).size(.lg).draw();
            return .ok;
        }
    };
    try capture("checkboxes.png", 320, 240, Local.frame);
}

test "switches" {
    const Local = struct {
        var on: bool = true;
        var off: bool = false;
        var dis_on: bool = true;
        var s_sm: bool = true;
        var s_md: bool = true;
        var s_lg: bool = true;
        fn frame() !dvui.App.Result {
            var bg = background(@src());
            defer bg.deinit();
            var col = ds.column(@src()).gap(ds.tokens.current.space_md).padding(ds.tokens.current.space_xl).draw();
            defer col.deinit();
            _ = ds.toggle(@src(), &on).label("On").draw();
            _ = ds.toggle(@src(), &off).label("Off").draw();
            _ = ds.toggle(@src(), &dis_on).label("Disabled (on)").disabled(true).draw();
            var sizes = ds.row(@src()).gap(ds.tokens.current.space_md).draw();
            defer sizes.deinit();
            _ = ds.toggle(@src(), &s_sm).size(.sm).draw();
            _ = ds.toggle(@src(), &s_md).size(.md).draw();
            _ = ds.toggle(@src(), &s_lg).size(.lg).draw();
            return .ok;
        }
    };
    try capture("switches.png", 320, 240, Local.frame);
}

test "sliders" {
    const Local = struct {
        var vol: f32 = 0.6;
        var dim: f32 = 0.3;
        var locked: f32 = 0.5;
        var s_sm: f32 = 0.25;
        var s_md: f32 = 0.5;
        var s_lg: f32 = 0.75;
        fn frame() !dvui.App.Result {
            var bg = background(@src());
            defer bg.deinit();
            var col = ds.column(@src()).gap(ds.tokens.current.space_md).padding(ds.tokens.current.space_xl).draw();
            defer col.deinit();
            _ = ds.slider(@src(), &vol).draw();
            _ = ds.slider(@src(), &dim).draw();
            _ = ds.slider(@src(), &locked).disabled(true).draw();
            var sizes = ds.row(@src()).gap(ds.tokens.current.space_md).draw();
            defer sizes.deinit();
            _ = ds.slider(@src(), &s_sm).size(.sm).draw();
            _ = ds.slider(@src(), &s_md).size(.md).draw();
            _ = ds.slider(@src(), &s_lg).size(.lg).draw();
            return .ok;
        }
    };
    try capture("sliders.png", 420, 260, Local.frame);
}

test "tabs" {
    const Local = struct {
        var active: usize = 1;
        const labels = [_][]const u8{ "Design", "Code", "Preview" };
        fn frame() !dvui.App.Result {
            var bg = background(@src());
            defer bg.deinit();
            var col = ds.column(@src()).padding(ds.tokens.current.space_lg).gap(ds.tokens.current.space_md).draw();
            defer col.deinit();
            _ = ds.tabs(@src(), &active, &labels).draw();
            return .ok;
        }
    };
    try capture("tabs.png", 360, 90, Local.frame);
}

test "dropdown" {
    const Local = struct {
        var fruit: usize = 0;
        var difficulty: usize = 1;
        var size_md: usize = 1;
        const fruits = [_][]const u8{ "Apple", "Banana", "Cherry" };
        const difficulties = [_][]const u8{ "Easy", "Normal", "Hard" };
        fn frame() !dvui.App.Result {
            var bg = background(@src());
            defer bg.deinit();
            var col = ds.column(@src()).padding(ds.tokens.current.space_lg).gap(ds.tokens.current.space_md).draw();
            defer col.deinit();
            var row = ds.row(@src()).gap(ds.tokens.current.space_lg).draw();
            defer row.deinit();
            _ = ds.dropdown(@src(), &fruit, &fruits).draw();
            _ = ds.dropdown(@src(), &difficulty, &difficulties).draw();
            _ = ds.dropdown(@src(), &size_md, &fruits).size(.sm).draw();
            return .ok;
        }
    };
    try capture("dropdown.png", 480, 120, Local.frame);
}

test "badges" {
    const Local = struct {
        fn frame() !dvui.App.Result {
            var bg = background(@src());
            defer bg.deinit();
            var col = ds.column(@src()).gap(ds.tokens.current.space_md).padding(ds.tokens.current.space_xl).draw();
            defer col.deinit();
            {
                var variants = ds.row(@src()).gap(ds.tokens.current.space_sm).draw();
                defer variants.deinit();
                ds.badge(@src(), "New").variant(.neutral).draw();
                ds.badge(@src(), "Beta").variant(.accent).draw();
                ds.badge(@src(), "Error").variant(.danger).draw();
            }
            {
                var dots = ds.row(@src()).gap(ds.tokens.current.space_md).draw();
                defer dots.deinit();
                ds.badge(@src(), "").dot(true).variant(.neutral).draw();
                ds.badge(@src(), "").dot(true).variant(.accent).draw();
                ds.badge(@src(), "").dot(true).variant(.danger).draw();
            }
            return .ok;
        }
    };
    try capture("badges.png", 300, 160, Local.frame);
}

test "radios" {
    const Local = struct {
        fn frame() !dvui.App.Result {
            var bg = background(@src());
            defer bg.deinit();
            var col = ds.column(@src()).gap(ds.tokens.current.space_md).padding(ds.tokens.current.space_xl).draw();
            defer col.deinit();
            _ = ds.radio(@src(), false, "Option A").draw();
            _ = ds.radio(@src(), true, "Option B").draw();
            _ = ds.radio(@src(), false, "Disabled").disabled(true).draw();
            var sizes = ds.row(@src()).gap(ds.tokens.current.space_md).draw();
            defer sizes.deinit();
            _ = ds.radio(@src(), true, null).size(.sm).draw();
            _ = ds.radio(@src(), true, null).size(.md).draw();
            _ = ds.radio(@src(), true, null).size(.lg).draw();
            return .ok;
        }
    };
    try capture("radios.png", 320, 240, Local.frame);
}

test "modal" {
    const Local = struct {
        var open: bool = true;
        fn frame() !dvui.App.Result {
            var bg = background(@src());
            defer bg.deinit();
            var col = ds.column(@src()).padding(ds.tokens.current.space_lg).draw();
            defer col.deinit();
            ds.label(@src(), "Page content behind the scrim").style(.secondary).draw();
            if (ds.modal(@src(), &open).title("Delete file?").draw()) |dialog| {
                defer dialog.deinit();
                ds.label(@src(), "This action cannot be undone.").style(.muted).draw();
                ds.gap(@src(), ds.tokens.current.space_lg);
                if (ds.button(@src(), "Close").variant(.filled).draw()) open = false;
            }
            return .ok;
        }
    };
    try capture("modal.png", 440, 300, Local.frame);
}

test "scroll area" {
    const Local = struct {
        fn frame() !dvui.App.Result {
            var bg = background(@src());
            defer bg.deinit();
            var sc = ds.scrollArea(@src()).draw();
            defer sc.deinit();
            var col = ds.column(@src()).padding(ds.tokens.current.space_lg).gap(ds.tokens.current.space_sm).expand(.horizontal).draw();
            defer col.deinit();
            inline for (0..16) |i| {
                dvui.labelNoFmt(@src(), std.fmt.comptimePrint("Item {d}", .{i + 1}), .{}, .{
                    .id_extra = i,
                    .color_text = .{ .color = ds.tokens.current.text_secondary },
                    .font = ds.font(ds.tokens.current.font_size_md),
                });
            }
            return .ok;
        }
    };
    // Short window so the 16 items overflow and the area scrolls.
    try capture("scroll_area.png", 220, 200, Local.frame);
}

test "icons" {
    const Local = struct {
        fn frame() !dvui.App.Result {
            var bg = background(@src());
            defer bg.deinit();
            var row = ds.row(@src()).gap(ds.tokens.current.space_lg).padding(ds.tokens.current.space_lg).draw();
            defer row.deinit();
            ds.icon(@src(), ds.Source.namedIcon("save", ds.icons.save)).size(.lg).style(.secondary).draw();
            ds.icon(@src(), ds.Source.namedIcon("heart", ds.icons.heart)).size(.lg).style(.accent).draw();
            ds.icon(@src(), ds.Source.namedIcon("trash_2", ds.icons.trash_2)).size(.lg).style(.danger).draw();
            ds.icon(@src(), ds.Source.namedIcon("settings", ds.icons.settings)).size(.lg).style(.primary).draw();
            ds.icon(@src(), ds.Source.namedIcon("star", ds.icons.star)).size(.lg).style(.muted).draw();
            return .ok;
        }
    };
    try capture("icons.png", 240, 80, Local.frame);
}

test "image source" {
    const Local = struct {
        const w = 28;
        const h = 28;
        var buf: [w * h * 4]u8 = undefined;
        var filled = false;
        fn img() ds.Source {
            if (!filled) {
                const from = [3]u32{ 110, 181, 255 };
                const to = [3]u32{ 168, 120, 245 };
                const span = (w - 1) + (h - 1);
                var y: usize = 0;
                while (y < h) : (y += 1) {
                    var x: usize = 0;
                    while (x < w) : (x += 1) {
                        const i = (y * w + x) * 4;
                        const t = x + y;
                        inline for (0..3) |c| {
                            buf[i + c] = @intCast((from[c] * (span - t) + to[c] * t) / span);
                        }
                        buf[i + 3] = 255;
                    }
                }
                filled = true;
            }
            return ds.Source.pixels(&buf, w, h);
        }
        fn frame() !dvui.App.Result {
            var bg = background(@src());
            defer bg.deinit();
            var row = ds.row(@src()).gap(ds.tokens.current.space_md).padding(ds.tokens.current.space_lg).draw();
            defer row.deinit();
            // image-only button, image+label button, and a plain image icon
            _ = ds.button(@src(), "").source(img()).variant(.outlined).size(.lg).draw();
            _ = ds.button(@src(), "Photo").source(img()).iconFirst().variant(.filled).size(.lg).draw();
            ds.icon(@src(), img()).size(.lg).draw();
            return .ok;
        }
    };
    try capture("image_source.png", 360, 110, Local.frame);
}

test "icon grid" {
    const Local = struct {
        fn cell(src: @import("std").builtin.SourceLocation, comptime name: [:0]const u8, svg: []const u8) void {
            const theme = ds.tokens.current;
            var col = dvui.box(src, .{ .dir = .vertical, .gap = theme.space_2xs }, .{ .min_size_content = .{ .w = 80 } });
            defer col.deinit();
            {
                var ic = dvui.box(@src(), .{}, .{ .gravity_x = 0.5 });
                defer ic.deinit();
                if (ds.icons.resolve(name, svg)) |r| ds.iconTvg(@src(), r.name, r.tvg_bytes).size(.lg).style(.secondary).draw();
            }
            dvui.labelNoFmt(@src(), name, .{}, .{ .color_text = .{ .color = theme.text_ghost }, .font = ds.font(theme.font_size_sm), .gravity_x = 0.5 });
        }
        fn frame() !dvui.App.Result {
            var bg = background(@src());
            defer bg.deinit();
            var row = ds.row(@src()).gap(ds.tokens.current.space_md).padding(ds.tokens.current.space_lg).draw();
            defer row.deinit();
            cell(@src(), "house", ds.icons.house);
            cell(@src(), "search", ds.icons.search);
            cell(@src(), "settings", ds.icons.settings);
            cell(@src(), "bell", ds.icons.bell);
            return .ok;
        }
    };
    try capture("icon_grid.png", 400, 110, Local.frame);
}

// Chat widget fixtures live in their own files so parallel work does not collide.
test {
    _ = @import("chat_screenshots.zig");
    _ = @import("card_screenshots.zig");
    _ = @import("chrome_screenshots.zig");
}
