//! What one `ds.glassScene` capture costs per frame.
//!
//! Run: `zig build blur-cost -Doptimize=ReleaseFast` (in Debug the numbers are
//! several times larger and tell you nothing).
//!
//! ⚠ This is dvui's **CPU testing backend** — a software rasteriser walking
//! every triangle of every blur pass over the whole physical framebuffer. It is
//! not the wgpu path the app runs, where those passes are GPU blits. What it
//! measures honestly is the *shape* of the cost:
//!
//!   * a cached capture is free — one textured quad per panel, and the number
//!     below is indistinguishable from drawing nothing;
//!   * a re-capture is not remotely free, on any backend, because it replays the
//!     background's render commands (real glyph shaping and path triangulation,
//!     not a blit) and then runs ~2·log2(radius) resampling passes over the
//!     captured area.
//!
//! Which is the whole argument for `witness`: pass the preview's frame counter
//! only while it is playing, and a constant while it is paused.
const std = @import("std");
const dvui = @import("dvui");
const ds = @import("dvui_ds");
const chrome = @import("editor_chrome");

var witness: u64 = 0;
var live: bool = false;

fn frame() !dvui.App.Result {
    var page = dvui.box(@src(), .{}, .{
        .expand = .both,
        .background = true,
        .color_fill = .{ .color = ds.tokens.current.surface_0 },
    });
    defer page.deinit();

    var preview = ds.previewFrame(@src()).draw();
    const viewport = preview.bounds;
    if (live) witness += 1;
    const scene = ds.glassScene(@src()).rect(viewport).witness(witness).begin();
    chrome.picture(@src(), preview.corners());
    preview.deinit();
    {
        var drawer = ds.glass(@src())
            .rect(.{ .x = viewport.x + viewport.w - 220, .y = viewport.y, .w = 220, .h = viewport.h })
            .scene(scene)
            .draw();
        defer drawer.deinit();
        ds.label(@src(), "Inspect").style(.primary).draw();
    }
    scene.end();
    return .ok;
}

fn nowNs() i96 {
    return std.Io.Clock.now(.awake, dvui.io).nanoseconds;
}

test "one blurred backdrop, 1400x860 at 1.75" {
    const scale: f32 = 1.75;
    var t = try dvui.testing.init(.{
        .window_size = .{ .w = 1400 * scale / 2, .h = 860 * scale / 2 },
        .window_init_opts = .{ .theme = ds.tokens.dvuiTheme() },
    });
    defer t.deinit();
    t.window.content_scale = scale / 2;
    _ = try dvui.testing.step(frame);
    try dvui.testing.settle(frame);

    const rounds = 10;

    live = false;
    var mark = nowNs();
    for (0..rounds) |_| _ = try dvui.testing.step(frame);
    const cached_ns: u64 = @intCast(@divTrunc(nowNs() - mark, rounds));

    live = true;
    mark = nowNs();
    for (0..rounds) |_| _ = try dvui.testing.step(frame);
    const live_ns: u64 = @intCast(@divTrunc(nowNs() - mark, rounds));

    std.debug.print(
        "[blur] 1400x860 logical at 1.75 (2450x1505 physical), CPU rasteriser: " ++
            "cached {d:.3} ms/frame, re-blurring {d:.3} ms/frame, the capture {d:.3} ms" ++
            "\n",
        .{
            @as(f64, @floatFromInt(cached_ns)) / 1_000_000.0,
            @as(f64, @floatFromInt(live_ns)) / 1_000_000.0,
            @as(f64, @floatFromInt(live_ns -| cached_ns)) / 1_000_000.0,
        },
    );
}
