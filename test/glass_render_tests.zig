//! What a glass surface actually puts on screen, sampled in pixels.
//!
//! Run: `zig build test`.
//!
//! Geometry can be asserted from rects; *appearance* cannot. `.solid(true)` is
//! a user-facing setting — reduced transparency — and the only honest test of
//! it is that the pixels come out the same as the opaque arm and different from
//! the blurred one. So this file renders frames into an offscreen target and
//! reads them back, which is also the one way to catch a panel quietly ignoring
//! an option it was given.
const std = @import("std");
const dvui = @import("dvui");
const ds = @import("dvui_ds");

const scales = [_]f32{ 1.0, 1.75, 2.0 };

/// Render one settled frame at `scale` and hand back its pixels.
/// Caller owns the slice.
fn renderFrame(
    scale: f32,
    logical: dvui.Size,
    frame: dvui.App.frameFunction,
) !struct { pixels: []dvui.Color.PMA, width: u32, height: u32 } {
    var t = try dvui.testing.init(.{
        .window_size = .{ .w = logical.w * scale / 2, .h = logical.h * scale / 2 },
        .window_init_opts = .{ .theme = ds.tokens.dvuiTheme() },
    });
    defer t.deinit();
    t.window.content_scale = scale / 2;
    _ = try dvui.testing.step(frame);
    try dvui.testing.settle(frame);

    const cw = dvui.currentWindow();
    const area = dvui.windowRectPixels();
    const width: u32 = @intFromFloat(@round(area.w));
    const height: u32 = @intFromFloat(@round(area.h));

    const target = try dvui.textureCreateTarget(.{ .width = width, .height = height });
    const previous = dvui.renderTarget(.{ .texture = target, .offset = .{} });
    if (try frame() == .close) return error.closed;
    cw.endRendering(.{});
    _ = dvui.renderTarget(previous);

    const captured = try dvui.textureReadTarget(std.testing.allocator, target);
    target.destroyLater();
    _ = try cw.end(.{});
    try cw.begin(cw.frame_time_ns + 100 * std.time.ns_per_ms);

    return .{ .pixels = captured, .width = width, .height = height };
}

fn pixelAt(shot: anytype, x: f32, y: f32) dvui.Color.PMA {
    const column: u32 = @min(shot.width - 1, @as(u32, @intFromFloat(@max(0, x))));
    const row: u32 = @min(shot.height - 1, @as(u32, @intFromFloat(@max(0, y))));
    return shot.pixels[row * shot.width + column];
}

fn channelDistance(a: dvui.Color.PMA, b: dvui.Color.PMA) u32 {
    const dr = @abs(@as(i32, a.r) - @as(i32, b.r));
    const dg = @abs(@as(i32, a.g) - @as(i32, b.g));
    const db = @abs(@as(i32, a.b) - @as(i32, b.b));
    return @intCast(dr + dg + db);
}

// ─── the three arms ──────────────────────────────────────────────────────────

/// Three panels of identical size over one bright scene: blurred, `.solid`
/// under that same scene, and `.solid` with no scene at all. The middle one is
/// the case that was broken.
const Arms = struct {
    const stage: dvui.Rect = .{ .x = 0, .y = 0, .w = 300, .h = 120 };
    const panel_w: f32 = 80;
    const panel_h: f32 = 60;

    fn panelAt(index: f32) dvui.Rect {
        return .{ .x = 10 + index * 100, .y = 30, .w = panel_w, .h = panel_h };
    }

    /// Somewhere well inside a panel, in physical pixels.
    fn probe(index: f32, scale: f32) struct { x: f32, y: f32 } {
        const r = panelAt(index);
        return .{ .x = (r.x + r.w / 2) * scale, .y = (r.y + r.h / 2) * scale };
    }

    fn frame() !dvui.App.Result {
        var page = dvui.box(@src(), .{}, .{
            .expand = .both,
            .background = true,
            .color_fill = .{ .color = ds.tokens.current.surface_0 },
        });
        defer page.deinit();

        const scene = ds.glassScene(@src()).rect(stage).begin();
        // A bright, structured background, so "blurred" and "opaque" cannot
        // come out the same colour by accident.
        var canvas = dvui.box(@src(), .{}, .{
            .expand = .both,
            .background = true,
            .color_fill = .{ .color = .fromHex("#E8C070") },
        });
        inline for (.{ "#3C7FD0", "#D04C4C", "#4CD08C" }, 0..) |hex, index| {
            var bar = dvui.box(@src(), .{}, .{
                .id_extra = index,
                .rect = .{ .x = 10 + @as(f32, index) * 100, .y = 0, .w = 60, .h = 120 },
                .background = true,
                .color_fill = .{ .color = .fromHex(hex) },
            });
            bar.deinit();
        }
        canvas.deinit();

        {
            var blurred = ds.glass(@src()).rect(panelAt(0)).scene(scene).draw();
            blurred.deinit();
        }
        {
            // The bug: `.solid` on a panel that samples a shared scene.
            var solid_scene = ds.glass(@src()).rect(panelAt(1)).scene(scene).solid(true).draw();
            solid_scene.deinit();
        }
        {
            var solid_alone = ds.glass(@src()).rect(panelAt(2)).solid(true).draw();
            solid_alone.deinit();
        }
        scene.end();
        return .ok;
    }
};

test "solid is honoured on a panel that samples a shared scene" {
    for (scales) |scale| {
        const shot = try renderFrame(scale, .{ .w = 300, .h = 120 }, Arms.frame);
        defer std.testing.allocator.free(shot.pixels);

        const blurred_probe = Arms.probe(0, scale);
        const solid_scene_probe = Arms.probe(1, scale);
        const solid_alone_probe = Arms.probe(2, scale);

        const blurred = pixelAt(shot, blurred_probe.x, blurred_probe.y);
        const solid_scene = pixelAt(shot, solid_scene_probe.x, solid_scene_probe.y);
        const solid_alone = pixelAt(shot, solid_alone_probe.x, solid_alone_probe.y);

        // The two solid arms sit over differently-coloured bars, so they cannot
        // be compared to each other directly — what has to hold is that the one
        // under the scene is as opaque as the one without: it must be much
        // closer to the panel tint than the blurred arm is to it.
        const tint = ds.tokens.current.glass_tint orelse ds.tokens.current.surface_1;
        const opaque_tint: dvui.Color.PMA = .fromColor(tint);

        const solid_scene_gap = channelDistance(solid_scene, opaque_tint);
        const solid_alone_gap = channelDistance(solid_alone, opaque_tint);
        const blurred_gap = channelDistance(blurred, opaque_tint);

        // A `.solid` panel over a shared scene is as near the tint as a `.solid`
        // panel with no scene at all — within a few levels, not a bar's worth.
        try std.testing.expect(solid_scene_gap <= solid_alone_gap + 24);
        // …and the blurred one is visibly *not*, or the test would pass with
        // every arm drawing the same thing.
        try std.testing.expect(blurred_gap > solid_scene_gap + 24);
    }
}
