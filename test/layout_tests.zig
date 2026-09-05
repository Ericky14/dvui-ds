//! Layout tests — the alignment discipline, asserted numerically.
//!
//! Run: `zig build test` (these are part of the unit-test gate, not the
//! screenshot gate — a PNG cannot claim a widget is centred, it can only look
//! like it is).
//!
//! Each test lays real widgets out through dvui's testing backend at 1.0, 1.75
//! and 2.0 physical pixels per logical pixel, then reads their physical rects
//! back through `dvui.tagGet` and asserts:
//!
//!   * the widget's edges land on whole physical pixels (a hairline that lands
//!     on a half pixel antialiases into a grey smear, and 1.75 is the scale
//!     where that happens — which is the owner's display);
//!   * a lone child sits in the middle of its parent, within half a pixel;
//!   * gaps that the design system says are on the 4 px grid actually are.
const std = @import("std");
const dvui = @import("dvui");
const ds = @import("dvui_ds");

/// The scales worth testing: the two where the arithmetic is easy, and the one
/// where it is not.
const scales = [_]f32{ 1.0, 1.75, 2.0 };

/// Settle `frame` at `scale` and hand the tags back to the caller's assertions.
/// Mirrors `test/screenshots.zig`'s `captureAt`: the testing backend fixes its
/// framebuffer at 2× the window size, so the scale is dialled in through the
/// window's own content scale.
fn atScale(scale: f32, logical: dvui.Size, frame: dvui.App.frameFunction, check: *const fn () anyerror!void) !void {
    var t = try dvui.testing.init(.{
        .window_size = .{ .w = logical.w * scale / 2, .h = logical.h * scale / 2 },
        .window_init_opts = .{ .theme = ds.tokens.dvuiTheme() },
    });
    defer t.deinit();
    t.window.content_scale = scale / 2;
    _ = try dvui.testing.step(frame);
    try dvui.testing.settle(frame);
    // One more frame so the tags describe the settled layout, then assert while
    // that frame's tag table is still alive.
    _ = try dvui.testing.step(frame);
    try check();
}

fn isWhole(value: f32) bool {
    return @abs(value - @round(value)) < 0.02;
}

/// A widget owns its *size*; where it is put is the parent's business. So the
/// two are asserted separately, and the fixtures below feed their parents
/// paddings that are themselves whole physical pixels at all three scales —
/// which is the other half of the same discipline.
fn expectWholeSize(rect: dvui.Rect.Physical) !void {
    try std.testing.expect(isWhole(rect.w));
    try std.testing.expect(isWhole(rect.h));
}

fn expectWholeOrigin(rect: dvui.Rect.Physical) !void {
    try std.testing.expect(isWhole(rect.x));
    try std.testing.expect(isWhole(rect.y));
}

fn expectWholePixelRect(rect: dvui.Rect.Physical) !void {
    try expectWholeOrigin(rect);
    try expectWholeSize(rect);
}

/// The child must sit in the middle of the parent: the two gaps on each axis
/// differ by no more than one physical pixel (they cannot always be equal —
/// an odd leftover pixel has to go somewhere).
fn expectCentred(parent: dvui.Rect.Physical, child: dvui.Rect.Physical) !void {
    const left = child.x - parent.x;
    const right = (parent.x + parent.w) - (child.x + child.w);
    const top = child.y - parent.y;
    const bottom = (parent.y + parent.h) - (child.y + child.h);
    try std.testing.expect(left >= 0 and right >= 0 and top >= 0 and bottom >= 0);
    try std.testing.expectApproxEqAbs(left, right, 1.0);
    try std.testing.expectApproxEqAbs(top, bottom, 1.0);
}

fn tagRect(name: []const u8) !dvui.Rect.Physical {
    const found = dvui.tagGet(name) orelse {
        std.debug.print("tag \"{s}\" was never drawn\n", .{name});
        return error.TagNotFound;
    };
    return found.rect;
}

// ─── chip ────────────────────────────────────────────────────────────────────

const ChipCase = struct {
    fn frame() !dvui.App.Result {
        var page = dvui.box(@src(), .{}, .{ .expand = .both, .background = true });
        defer page.deinit();
        var pad = ds.column(@src()).padding(8).draw();
        defer pad.deinit();
        _ = ds.chip(@src(), "pencil", ds.icons.pencil).tag("chip").tagIcon("chip.icon").draw();
        return .ok;
    }

    fn check() anyerror!void {
        const outer = try tagRect("chip");
        const icon = try tagRect("chip.icon");
        try expectWholePixelRect(outer);
        try std.testing.expectApproxEqAbs(outer.w, outer.h, 0.02);
        try expectCentred(outer, icon);
    }
};

test "a chip is square, pixel-aligned and centres its icon at 1.0, 1.75 and 2.0" {
    for (scales) |scale| {
        try atScale(scale, .{ .w = 120, .h = 80 }, ChipCase.frame, ChipCase.check);
    }
}

test "a chip is exactly the size the theme asked for, in physical pixels" {
    for (scales) |scale| {
        const Local = struct {
            var expected: f32 = 0;
            fn check() anyerror!void {
                const outer = try tagRect("chip");
                try std.testing.expectApproxEqAbs(expected, outer.w, 0.02);
                try std.testing.expectApproxEqAbs(expected, outer.h, 0.02);
            }
        };
        Local.expected = @round(ds.tokens.current.chrome_chip_size * scale);
        try atScale(scale, .{ .w = 120, .h = 80 }, ChipCase.frame, Local.check);
    }
}

// ─── pill ────────────────────────────────────────────────────────────────────

const PillCase = struct {
    fn frame() !dvui.App.Result {
        var page = dvui.box(@src(), .{}, .{ .expand = .both, .background = true });
        defer page.deinit();
        var pad = ds.column(@src()).padding(8).draw();
        defer pad.deinit();
        ds.pill(@src(), "60 fps").mono(true).tag("pill").tagLabel("pill.label").draw();
        return .ok;
    }

    fn check() anyerror!void {
        const outer = try tagRect("pill");
        const label = try tagRect("pill.label");
        try expectWholeOrigin(outer);
        // Height is the pill's own claim; width follows the text it was given.
        try std.testing.expect(isWhole(outer.h));
        // The label sits between two equal round ends.
        const left = label.x - outer.x;
        const right = (outer.x + outer.w) - (label.x + label.w);
        try std.testing.expectApproxEqAbs(left, right, 1.0);
    }
};

test "a pill is pixel-aligned and its label sits between equal ends" {
    for (scales) |scale| {
        try atScale(scale, .{ .w = 160, .h = 80 }, PillCase.frame, PillCase.check);
    }
}

test "a pill is exactly the height the theme asked for, in physical pixels" {
    for (scales) |scale| {
        const Local = struct {
            var expected: f32 = 0;
            fn check() anyerror!void {
                try std.testing.expectApproxEqAbs(expected, (try tagRect("pill")).h, 0.02);
            }
        };
        Local.expected = @round(ds.tokens.current.chrome_pill_height * scale);
        try atScale(scale, .{ .w = 160, .h = 80 }, PillCase.frame, Local.check);
    }
}

// ─── glass ───────────────────────────────────────────────────────────────────

const GlassCase = struct {
    const panel: dvui.Rect = .{ .x = 20, .y = 16, .w = 160, .h = 96 };

    fn frame() !dvui.App.Result {
        var page = dvui.box(@src(), .{}, .{ .expand = .both, .background = true });
        defer page.deinit();
        var surface = ds.glass(@src()).rect(panel).solid(true).tag("glass").draw();
        defer surface.deinit();
        var child = dvui.box(@src(), .{}, .{
            .tag = "glass.child",
            .expand = .both,
            .background = true,
            .color_fill = .{ .color = ds.tokens.current.accent },
        });
        child.deinit();
        return .ok;
    }

    fn check() anyerror!void {
        const outer = try tagRect("glass");
        const child = try tagRect("glass.child");
        try expectWholePixelRect(outer);
        // Equal padding + equal hairline on every edge means the content box is
        // centred inside the surface.
        try expectCentred(outer, child);
    }
};

test "a glass surface is pixel-aligned and centres its content box" {
    for (scales) |scale| {
        try atScale(scale, .{ .w = 220, .h = 140 }, GlassCase.frame, GlassCase.check);
    }
}

// ─── window frame ────────────────────────────────────────────────────────────

const WindowFrameCase = struct {
    fn frame() !dvui.App.Result {
        var shell = ds.windowFrame(@src()).tag("shell").draw();
        defer shell.deinit();
        var child = dvui.box(@src(), .{}, .{
            .tag = "shell.child",
            .expand = .both,
            .background = true,
            .color_fill = .{ .color = ds.tokens.current.surface_2 },
        });
        child.deinit();
        return .ok;
    }

    fn check() anyerror!void {
        const outer = try tagRect("shell");
        const child = try tagRect("shell.child");
        try expectWholePixelRect(outer);
        // Outer ring + inner gutter, the same on all four sides.
        try expectCentred(outer, child);
        // …and that inset is exactly two whole physical pixels' worth of rings.
        const inset = child.x - outer.x;
        try std.testing.expect(isWhole(inset));
        try std.testing.expect(inset >= 2);
    }
};

test "the window frame's two rings are whole pixels and equal on every side" {
    for (scales) |scale| {
        try atScale(scale, .{ .w = 200, .h = 140 }, WindowFrameCase.frame, WindowFrameCase.check);
    }
}

// ─── preview frame ───────────────────────────────────────────────────────────

const PreviewCase = struct {
    fn frame() !dvui.App.Result {
        var page = dvui.box(@src(), .{}, .{ .expand = .both, .background = true, .tag = "page" });
        defer page.deinit();
        var preview = ds.previewFrame(@src()).tag("picture").draw();
        var canvas = dvui.box(@src(), .{}, .{
            .expand = .both,
            .background = true,
            .color_fill = .{ .color = ds.tokens.current.accent },
        });
        canvas.deinit();
        preview.deinit();
        return .ok;
    }

    fn check() anyerror!void {
        const page = try tagRect("page");
        const picture = try tagRect("picture");
        try expectWholePixelRect(picture);
        // The gutter is the same on all four sides.
        try expectCentred(page, picture);
    }
};

test "the preview frame's gutter is even and pixel-aligned" {
    for (scales) |scale| {
        try atScale(scale, .{ .w = 240, .h = 160 }, PreviewCase.frame, PreviewCase.check);
    }
}

// ─── the 4 px grid ───────────────────────────────────────────────────────────

test "chrome gaps sit on the 4px grid at every scale" {
    // A gap authored on the grid must still be a whole number of physical
    // pixels after snapping, or a row of chips drifts by a pixel per gap.
    const theme = ds.tokens.current;
    const grid_gaps = [_]f32{ theme.space_2xs, theme.space_sm, theme.space_md, theme.space_lg, theme.space_xl, theme.space_2xl };
    for (grid_gaps) |gap| {
        try std.testing.expectApproxEqAbs(@as(f32, 0), @mod(gap, 4), 0.0001);
        for (scales) |scale| {
            try std.testing.expect(ds.isSnapped(ds.snapPx(gap, scale), scale));
        }
    }
}

test "a strip of chips keeps an even pitch at every scale" {
    const Local = struct {
        fn frame() !dvui.App.Result {
            var page = dvui.box(@src(), .{}, .{ .expand = .both, .background = true });
            defer page.deinit();
            var strip = ds.row(@src()).gap(ds.tokens.current.space_2xs).padding(8).draw();
            defer strip.deinit();
            _ = ds.chip(@src(), "undo", ds.icons.undo).tag("strip.0").idExtra(0).draw();
            _ = ds.chip(@src(), "redo", ds.icons.redo).tag("strip.1").idExtra(1).draw();
            _ = ds.chip(@src(), "pencil", ds.icons.pencil).tag("strip.2").idExtra(2).draw();
            return .ok;
        }

        fn check() anyerror!void {
            const first = try tagRect("strip.0");
            const second = try tagRect("strip.1");
            const third = try tagRect("strip.2");
            const pitch_a = second.x - first.x;
            const pitch_b = third.x - second.x;
            try std.testing.expectApproxEqAbs(pitch_a, pitch_b, 0.02);
            try std.testing.expect(isWhole(pitch_a));
        }
    };
    for (scales) |scale| {
        try atScale(scale, .{ .w = 220, .h = 80 }, Local.frame, Local.check);
    }
}
