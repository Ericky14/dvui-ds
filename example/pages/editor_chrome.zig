//! Editor Chrome — the design-review page.
//!
//! A mock of the zigame editor built only out of ds widgets: `ds.windowFrame`
//! around the whole thing, a title bar, a chat column with a `ds.chip` history
//! strip and an inline `ds.glass` composer, and a `ds.previewFrame` holding a
//! stand-in render with three `ds.glass` overlays floating on one shared
//! `ds.glassScene` capture — a tool bar of chips, a row of `ds.pill` readouts,
//! and a docked inspect drawer.
//!
//! Shared, not copied: `test/chrome_screenshots.zig` imports this same file as
//! the `editor_chrome` module and renders `frame()` at 1.0 and 1.75, so the
//! screenshots the design review looks at and the page the storybook runs are
//! the same code.
const std = @import("std");
const dvui = @import("dvui");
const ds = @import("dvui_ds");

// ─── A stand-in for the 3-D preview ──────────────────────────────────────────

/// A "render": a cool-to-warm diagonal gradient with a few soft bodies in it.
/// Blur is only legible over content that has structure, so a flat fill would
/// make every glass surface here look like a plain translucent box.
pub fn picture(src: std.builtin.SourceLocation, corners: dvui.CornerRect) void {
    const sky = [_]dvui.Gradient.Stop{
        .{ .color = .fromHex("#101726"), .offset = 0.0 },
        .{ .color = .fromHex("#26456A"), .offset = 0.5 },
        .{ .color = .fromHex("#C9AC80"), .offset = 1.0 },
    };
    var canvas = dvui.box(src, .{}, .{
        .expand = .both,
        .background = true,
        .corners = corners,
        .color_fill = .{ .gradient = .{ .linear = .{ .stops = &sky, .angle_degrees = 115 } } },
    });
    defer canvas.deinit();

    const bodies = [_]struct { x: f32, y: f32, w: f32, h: f32, hex: []const u8, round: f32 }{
        .{ .x = 0.58, .y = 0.14, .w = 0.26, .h = 0.40, .hex = "#E7A84B", .round = 999 },
        .{ .x = 0.04, .y = 0.50, .w = 0.34, .h = 0.40, .hex = "#4FA3E0", .round = 14 },
        .{ .x = 0.42, .y = 0.62, .w = 0.48, .h = 0.28, .hex = "#7FD4A8", .round = 10 },
        .{ .x = 0.16, .y = 0.16, .w = 0.20, .h = 0.24, .hex = "#B07FE0", .round = 999 },
    };
    const area = canvas.data().contentRect();
    inline for (bodies, 0..) |body, index| {
        var shape = dvui.box(@src(), .{}, .{
            .id_extra = index,
            .rect = .{
                .x = body.x * area.w,
                .y = body.y * area.h,
                .w = body.w * area.w,
                .h = body.h * area.h,
            },
            .background = true,
            .corners = dvui.CornerRect.round(body.round),
            .color_fill = .{ .color = .fromHex(body.hex) },
        });
        shape.deinit();
    }
}

/// A small icon at the chrome's caption size.
pub fn glyph(src: std.builtin.SourceLocation, comptime name: [:0]const u8, bytes: []const u8, style: ds.IconStyle) void {
    ds.icon(src, ds.Source.namedIcon(name, bytes)).style(style).size(.sm).draw();
}

/// An elastic gap that pushes what follows to the far edge of a row.
pub fn stretch(src: std.builtin.SourceLocation) void {
    var spacer = dvui.box(src, .{}, .{ .expand = .horizontal });
    spacer.deinit();
}

// ─── The mock ────────────────────────────────────────────────────────────────

const Entry = struct { name: [:0]const u8, bytes: []const u8, state: ds.ChipState };

const history = [_]Entry{
    .{ .name = "undo", .bytes = ds.icons.undo, .state = .rest },
    .{ .name = "redo", .bytes = ds.icons.redo, .state = .rest },
    .{ .name = "square-pen", .bytes = ds.icons.square_pen, .state = .rest },
    .{ .name = "pencil", .bytes = ds.icons.pencil, .state = .current },
    .{ .name = "history", .bytes = ds.icons.history, .state = .faded },
};

const tools = [_]Entry{
    .{ .name = "play", .bytes = ds.icons.play, .state = .rest },
    .{ .name = "pause", .bytes = ds.icons.pause, .state = .rest },
    .{ .name = "square", .bytes = ds.icons.square, .state = .rest },
    .{ .name = "move", .bytes = ds.icons.move, .state = .active },
    .{ .name = "rotate-cw", .bytes = ds.icons.rotate_cw, .state = .rest },
    .{ .name = "scaling", .bytes = ds.icons.scaling, .state = .rest },
    .{ .name = "globe", .bytes = ds.icons.globe, .state = .rest },
    .{ .name = "camera", .bytes = ds.icons.camera, .state = .rest },
};

/// The composer's buffer. Empty, so the review shows the placeholder state.
var composer_buffer: [256]u8 = @splat(0);

/// Width of the docked inspect drawer, shared with the toolbar maths.
const drawer_width: f32 = 216;

fn titleBar(src: std.builtin.SourceLocation) void {
    const theme = ds.tokens.current;
    var bar = dvui.box(src, .{ .dir = .horizontal, .gap = theme.space_sm }, .{
        .expand = .horizontal,
        .background = true,
        .color_fill = .{ .color = theme.surface_1 },
        .padding = ds.paddingXY(theme.space_md, 0),
        .min_size_content = .{ .h = theme.chrome_titlebar_height },
        .border = ds.paddingEach(0, 0, ds.hairline(ds.pixelScale()), 0),
        .color_border = .{ .color = theme.border_subtle },
    });
    defer bar.deinit();

    glyph(@src(), "circle", ds.icons.circle, .accent);
    ds.label(@src(), "zigame").style(.secondary).gravityY(0.5).draw();
    ds.label(@src(), "·").style(.weak).gravityY(0.5).draw();
    ds.label(@src(), "proj").style(.muted).gravityY(0.5).draw();
    stretch(@src());
    ds.pill(@src(), "MCP :4141").mono(true).draw();
    ds.pill(@src(), "Claude Code").tone(.accent).icon("bot", ds.icons.bot).draw();
    _ = ds.iconButton(@src(), "minus", ds.icons.minus).size(.sm).draw();
    _ = ds.iconButton(@src(), "maximize", ds.icons.maximize).size(.sm).draw();
    _ = ds.iconButton(@src(), "x", ds.icons.x).variant(.danger).size(.sm).draw();
}

fn chatColumn(src: std.builtin.SourceLocation, width: f32) void {
    const theme = ds.tokens.current;
    var column = dvui.box(src, .{ .gap = theme.space_sm }, .{
        .expand = .vertical,
        .background = true,
        .color_fill = .{ .color = theme.surface_1 },
        .min_size_content = .{ .w = width },
        .padding = dvui.Rect.all(theme.space_md),
        .border = ds.paddingEach(0, ds.hairline(ds.pixelScale()), 0, 0),
        .color_border = .{ .color = theme.border_subtle },
    });
    defer column.deinit();

    {
        var header = ds.row(@src()).gap(theme.space_sm).expand(.horizontal).draw();
        defer header.deinit();
        ds.label(@src(), "CHAT").style(.muted).gravityY(0.5).draw();
        stretch(@src());
        ds.pill(@src(), "ready").draw();
    }
    {
        var strip = ds.row(@src()).gap(theme.space_2xs).expand(.horizontal).draw();
        defer strip.deinit();
        inline for (history, 0..) |entry, index| {
            _ = ds.chip(@src(), entry.name, entry.bytes).state(entry.state).idExtra(index).draw();
        }
    }
    {
        var card = ds.card(@src()).variant(.filled).padding(theme.space_md).gap(theme.space_2xs).expand(.horizontal).draw();
        defer card.deinit();
        ds.label(@src(), "Duplicated Ground").style(.secondary).draw();
        ds.label(@src(), "your edit · b100a47").style(.weak).font(.mono).draw();
    }
    {
        var card = ds.card(@src()).variant(.filled).padding(theme.space_md).gap(theme.space_2xs).expand(.horizontal).draw();
        defer card.deinit();
        ds.label(@src(), "Framed the preview").style(.secondary).draw();
        ds.label(@src(), "assistant · 4 files").style(.weak).font(.mono).draw();
    }

    var filler = dvui.box(@src(), .{}, .{ .expand = .vertical });
    filler.deinit();

    // The real widget, not a mock of it: this page is the design review, so the
    // composer it shows has to be the composer the editor gets.
    _ = ds.chat.composer(@src(), &composer_buffer).placeholder("@ / Ask for anything…").draw();
}

fn statusStrip(src: std.builtin.SourceLocation) void {
    const theme = ds.tokens.current;
    var strip = dvui.box(src, .{ .dir = .horizontal, .gap = theme.space_sm }, .{
        .expand = .horizontal,
        .background = true,
        .color_fill = .{ .color = theme.surface_1 },
        .padding = ds.paddingXY(theme.space_md, 0),
        .min_size_content = .{ .h = theme.chrome_status_height },
        .border = ds.paddingEach(ds.hairline(ds.pixelScale()), 0, 0, 0),
        .color_border = .{ .color = theme.border_subtle },
    });
    defer strip.deinit();
    glyph(@src(), "check", ds.icons.check, .accent);
    ds.label(@src(), "no errors").style(.muted).gravityY(0.5).draw();
    stretch(@src());
    ds.label(@src(), "wgpu · 2450×1505 · 1.75×").style(.weak).font(.mono).gravityY(0.5).draw();
}

/// A hairline rule that reads on glass: white at low alpha, one physical pixel.
fn divider(src: std.builtin.SourceLocation) void {
    var rule = dvui.box(src, .{}, .{
        .expand = .horizontal,
        .background = true,
        .color_fill = .{ .color = ds.alpha(.white, ds.tokens.current.glass_border_alpha) },
        .min_size_content = .{ .h = ds.hairline(ds.pixelScale()) },
    });
    rule.deinit();
}

fn lane(src: std.builtin.SourceLocation, name: []const u8, value: []const u8, index: usize) void {
    const theme = ds.tokens.current;
    var row = dvui.box(src, .{ .dir = .horizontal, .gap = theme.space_2xs }, .{
        .id_extra = index,
        .expand = .horizontal,
    });
    defer row.deinit();
    ds.label(@src(), name).style(.muted).gravityY(0.5).draw();
    stretch(@src());
    ds.pill(@src(), value).mono(true).draw();
}

fn inspectDrawer(src: std.builtin.SourceLocation, area: dvui.Rect, scene: ds.GlassSceneHandle) void {
    const theme = ds.tokens.current;
    var drawer = ds.glass(src)
        .rect(.{ .x = area.x + area.w - drawer_width, .y = area.y, .w = drawer_width, .h = area.h })
        .scene(scene)
        .gap(theme.space_sm)
        .padding(theme.space_md)
        .radius(theme.preview_radius)
        .draw();
    defer drawer.deinit();

    {
        var header = ds.row(@src()).gap(theme.space_sm).expand(.horizontal).draw();
        defer header.deinit();
        ds.label(@src(), "Inspect").style(.primary).gravityY(0.5).draw();
        stretch(@src());
        ds.pill(@src(), "#2").mono(true).draw();
    }
    divider(@src());
    {
        var section = ds.column(@src()).gap(theme.space_xs).expand(.horizontal).draw();
        defer section.deinit();
        // Text on glass uses `.secondary` / `.muted`; `.weak` is tuned for an
        // opaque dark surface and disappears over a bright blur.
        ds.label(@src(), "Transform").style(.secondary).draw();
        lane(@src(), "Position", "2.5", 0);
        lane(@src(), "Rotation", "0", 1);
        lane(@src(), "Scale", "1", 2);
    }
    divider(@src());
    {
        var section = ds.column(@src()).gap(theme.space_xs).expand(.horizontal).draw();
        defer section.deinit();
        ds.label(@src(), "MeshRenderer").style(.secondary).draw();
        var row = ds.row(@src()).gap(theme.space_2xs).expand(.horizontal).draw();
        defer row.deinit();
        ds.label(@src(), "Mesh").style(.muted).gravityY(0.5).draw();
        stretch(@src());
        ds.pill(@src(), "plane").mono(true).draw();
    }
}

/// Draw the whole mock into whatever space the caller gives it.
pub fn draw() void {
    const theme = ds.tokens.current;
    var shell = ds.windowFrame(@src()).draw();
    defer shell.deinit();

    titleBar(@src());

    {
        var body = ds.row(@src()).expand(.both).draw();
        defer body.deinit();

        chatColumn(@src(), 268);

        var preview = ds.previewFrame(@src()).draw();
        const viewport = preview.bounds;

        // One capture for the whole viewport; the three panels below each
        // sample their own patch of it.
        const scene = ds.glassScene(@src()).rect(viewport).begin();
        picture(@src(), preview.corners());
        // The vignette + hairline belong to the picture, so they are captured
        // with it — closing the frame inside the bracket is deliberate.
        preview.deinit();

        // The drawer is docked over the right of the picture, so the floating
        // rows centre on what is still visible rather than on the whole frame.
        const free = preview.reserve(.right, drawer_width);
        {
            const chip_pitch = theme.chrome_chip_size + theme.space_2xs;
            const bar_width = @as(f32, tools.len) * chip_pitch - theme.space_2xs + 2 * theme.space_2xs + 4;
            var bar = ds.glass(@src())
                .rect(free.toolbarRect(bar_width, theme.chrome_toolbar_height))
                .scene(scene)
                .horizontal()
                .gap(theme.space_2xs)
                .padding(theme.space_2xs)
                .radius(theme.radius_md)
                .draw();
            defer bar.deinit();
            inline for (tools, 0..) |tool, index| {
                _ = ds.chip(@src(), tool.name, tool.bytes).state(tool.state).idExtra(index).draw();
            }
        }
        {
            var pills = ds.glass(@src())
                .rect(free.statusRect(238, theme.chrome_toolbar_height))
                .scene(scene)
                .horizontal()
                .gap(theme.space_sm)
                .padding(theme.space_xs)
                .radius(theme.radius_md)
                .draw();
            defer pills.deinit();
            ds.pill(@src(), "Ground · 2").tone(.accent).icon("box", ds.icons.box).draw();
            ds.pill(@src(), "60 fps").mono(true).draw();
        }
        inspectDrawer(@src(), viewport, scene);
        // Last: the panels above had to be drawn while the bracket was open.
        scene.end();
    }

    statusStrip(@src());
}

/// The same mock as a whole-window frame, for the screenshot fixtures.
pub fn frame() !dvui.App.Result {
    draw();
    return .ok;
}
