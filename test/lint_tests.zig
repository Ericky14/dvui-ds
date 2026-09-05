//! Geometry gate for the design system's own widgets.
//!
//! Run: `zig build test`.
//!
//! `zigame ui lint` reported 26 finding classes inside these widgets — icons on
//! fractional physical pixels at 1.75, a chat-row button under the 24 px hit
//! target, sibling gaps off the 4 px grid, an action row whose buttons sit off
//! its centre line. The engine can only see this repo through a pinned commit,
//! so each of those is reproduced here, over the widget alone, and the fix is
//! proven where it lives.
//!
//! Each test draws one widget on a bare page, arms dvui's frame capture, and
//! runs `test/ds_lint.zig` — the same rules and the same tolerances the engine
//! uses — filtered to the widget's own source file so a fixture's scaffolding
//! cannot mask or manufacture a finding.
const std = @import("std");
const dvui = @import("dvui");
const ds = @import("dvui_ds");
const lint = @import("ds_lint.zig");

/// 1.0 proves nothing about snapping (a logical pixel *is* a physical one) but
/// everything about the grid and the hit target; 1.75 is where DPI rounding
/// actually bites; 2.0 is the retina case.
const scales = [_]f32{ 1.0, 1.75, 2.0 };

/// Draw `frame` at `scale` until it settles, then lint the widgets that came
/// from `source_file`.
fn lintAt(scale: f32, logical: dvui.Size, source_file: []const u8, frame: dvui.App.frameFunction) !lint.Counts {
    var t = try dvui.testing.init(.{
        .window_size = .{ .w = logical.w * scale / 2, .h = logical.h * scale / 2 },
        .window_init_opts = .{ .theme = ds.tokens.dvuiTheme() },
    });
    defer t.deinit();
    t.window.content_scale = scale / 2;
    _ = try dvui.testing.step(frame);
    try dvui.testing.settle(frame);

    // `captureFrame` arms the *next* `Window.begin`, and `step` runs a frame and
    // then begins the following one — so the armed frame is the second step.
    dvui.debug.captureFrame();
    _ = try dvui.testing.step(frame);
    _ = try dvui.testing.step(frame);
    defer dvui.debug.clearCaptures(std.testing.allocator);

    // Printing is on: when a residual moves, the test prints exactly which
    // widget and which edge moved, which is the whole point of keeping the
    // numbers rather than a "close enough" threshold.
    return lint.run(std.testing.allocator, scale, source_file, true);
}

fn expectClean(logical: dvui.Size, source_file: []const u8, frame: dvui.App.frameFunction) !void {
    try expectFindings(logical, source_file, frame, .{});
}

/// A ratchet, not a threshold. `expected` is what this widget still reports, and
/// the assertion is *equality*: fixing one more finding fails this test just as
/// loudly as breaking one, so the number can only move on purpose and with a
/// reason written next to it.
fn expectFindings(
    logical: dvui.Size,
    source_file: []const u8,
    frame: dvui.App.frameFunction,
    expected: Residual,
) !void {
    for (scales) |scale| {
        const counts = try lintAt(scale, logical, source_file, frame);
        const want: usize = if (scale > 1.9) expected.at_200 else if (scale > 1.01) expected.at_175 else 0;
        if (counts.total() != want) {
            std.debug.print(
                "{s} at scale {d}: {d} snapped, {d} grid, {d} row_centre, {d} hit_target (expected {d})" ++ nl,
                .{ source_file, scale, counts.snapped, counts.grid, counts.row_centre, counts.hit_target, want },
            );
        }
        try std.testing.expectEqual(want, counts.total());
    }
}

const nl = "\n";

/// Findings a widget still reports. Every one of them is a `snapped` finding, so
/// there are none at scale 1, where `snapped` does not apply — and the count can
/// differ between 1.75 and 2.0, because whether an inherited fractional y lands
/// on a whole physical pixel depends on the scale it is multiplied by.
const Residual = struct { at_175: usize = 0, at_200: usize = 0 };

/// A bare page: a themed background and nothing else, so the only findings can
/// come from the widget under test.
fn page(src: std.builtin.SourceLocation) *dvui.BoxWidget {
    return dvui.box(src, .{}, .{
        .expand = .both,
        .background = true,
        .color_fill = .{ .color = ds.tokens.current.surface_0 },
        .padding = dvui.Rect.all(8),
    });
}

// ─── button / icon_button ────────────────────────────────────────────────────

test "an icon-only button draws on whole physical pixels" {
    const Local = struct {
        fn frame() !dvui.App.Result {
            var background = page(@src());
            defer background.deinit();
            var row = ds.row(@src()).gap(ds.tokens.current.space_sm).draw();
            defer row.deinit();
            _ = ds.iconButton(@src(), "paperclip", ds.icons.paperclip).variant(.ghost).size(.sm).draw();
            _ = ds.iconButton(@src(), "cog", ds.icons.cog).variant(.filled).size(.md).draw();
            _ = ds.iconButton(@src(), "bell", ds.icons.bell).variant(.outlined).size(.lg).draw();
            return .ok;
        }
    };
    try expectClean(.{ .w = 220, .h = 90 }, "button.zig", Local.frame);
}

test "an icon-only button clears the 24px hit target at every size" {
    const Local = struct {
        fn frame() !dvui.App.Result {
            var background = page(@src());
            defer background.deinit();
            _ = ds.iconButton(@src(), "cog", ds.icons.cog).size(.sm).draw();
            return .ok;
        }
    };
    try expectClean(.{ .w = 120, .h = 80 }, "icon_button.zig", Local.frame);
}

test "a label+icon button draws on whole physical pixels" {
    const Local = struct {
        fn frame() !dvui.App.Result {
            var background = page(@src());
            defer background.deinit();
            var row = ds.row(@src()).gap(ds.tokens.current.space_sm).draw();
            defer row.deinit();
            _ = ds.button(@src(), "Send").variant(.filled).size(.sm).icon("send", ds.icons.send).draw();
            _ = ds.button(@src(), "Stop").variant(.danger).size(.sm).icon("square", ds.icons.square).iconFirst().draw();
            _ = ds.button(@src(), "Off").variant(.outlined).size(.sm).icon("cog", ds.icons.cog).disabled(true).draw();
            return .ok;
        }
    };
    try expectClean(.{ .w = 320, .h = 90 }, "button.zig", Local.frame);
}

test "a plain button clears the 24px hit target however it is padded" {
    const Local = struct {
        fn frame() !dvui.App.Result {
            var background = page(@src());
            defer background.deinit();
            // The checkpoint row's button: horizontal padding only, which used
            // to leave it 18 px tall.
            _ = ds.button(@src(), "Undo")
                .variant(.accent_ghost)
                .size(.sm)
                .padding(ds.paddingXY(ds.tokens.current.space_sm, 0))
                .draw();
            return .ok;
        }
    };
    try expectClean(.{ .w = 160, .h = 80 }, "button.zig", Local.frame);
}

// ─── chat widgets ────────────────────────────────────────────────────────────

test "a checkpoint row is snapped and its button is reachable" {
    const Local = struct {
        fn frame() !dvui.App.Result {
            var background = page(@src());
            defer background.deinit();
            _ = ds.chat.checkpoint(@src(), "Checkpoint · 2 files").draw();
            return .ok;
        }
    };
    try expectClean(.{ .w = 360, .h = 80 }, "checkpoint.zig", Local.frame);
}

test "the composer's rows are on the grid and snapped" {
    const Local = struct {
        var buffer: [128]u8 = @splat(0);
        fn frame() !dvui.App.Result {
            var background = page(@src());
            defer background.deinit();
            _ = ds.chat.composer(@src(), &buffer).draw();
            return .ok;
        }
    };
    // Residual: 3 `snapped` findings above scale 1, all of them a *top* edge.
    //
    // The composer's frame is as tall as the text entry inside it, and a text
    // entry is as tall as its font's line box — a font metric, fractional in
    // physical pixels at 175 %. Everything laid out under it then starts on a
    // fraction, and no amount of snapping the composer's own paddings, borders
    // or gaps (all of which are snapped now) moves it, because the fraction is
    // inherited, not produced here.
    //
    // Fixing it means rounding a *multi-line* text block's height, which the
    // design system cannot do without owning text layout: pinning the height
    // would cap the composer at one line. The right fix is one level down —
    // dvui rounding a widget's resolved rect to physical pixels when
    // `snap_to_pixels` is on, which moves every widget in every dvui app by up
    // to half a pixel and is not a change to make on the way past.
    try expectFindings(.{ .w = 420, .h = 160 }, "composer.zig", Local.frame, .{ .at_175 = 3, .at_200 = 3 });
}

test "a plan card's action row shares a centre line, a column and the grid" {
    const Local = struct {
        fn frame() !dvui.App.Result {
            var background = page(@src());
            defer background.deinit();
            _ = ds.chat.planCard(@src(), "Frame the preview", "1. Add the frame.\n2. Blur the drawer.").draw();
            return .ok;
        }
    };
    // Residual: 3 `snapped` findings above scale 1 — the three action buttons'
    // top edge. Same single cause as the composer's: the markdown body stacked
    // above them is n × a fractional line box tall, so the row under it starts
    // on a fraction. Their left edges, widths, heights, gaps and centre line —
    // everything this file actually controls — are exact.
    try expectFindings(.{ .w = 420, .h = 260 }, "plan_card.zig", Local.frame, .{ .at_175 = 3, .at_200 = 3 });
}

test "a markdown block keeps its rows centred and snapped" {
    const Local = struct {
        fn frame() !dvui.App.Result {
            var background = page(@src());
            defer background.deinit();
            ds.chat.markdown(@src(),
                \\A line with `inline code` in it.
                \\
                \\1. Spawn a sphere with a red MeshRenderer and give it a floor bounce, long enough that this item has to wrap.
                \\2. Second step
            ).draw();
            return .ok;
        }
    };
    try expectClean(.{ .w = 300, .h = 260 }, "markdown.zig", Local.frame);
}

test "a chat message is snapped" {
    const Local = struct {
        fn frame() !dvui.App.Result {
            var background = page(@src());
            defer background.deinit();
            // Streaming, so the blinking caret — a 2 px bar sized from a font metric —
            // is drawn and measured too.
            ds.chat.message(@src(), .assistant, "Framed the preview and blurred the drawer.").streaming(true).draw();
            return .ok;
        }
    };
    // Residual: 1 `snapped` finding above scale 1 — the streaming caret's top
    // edge. Its own size is snapped now (it was a 2 px bar scaled from a font
    // metric, i.e. 3.5 physical px at 175 %); what is left is the y it inherits
    // from the text block above it, which is the same font-metric cause as the
    // composer's and the plan card's.
    try expectFindings(.{ .w = 420, .h = 160 }, "message.zig", Local.frame, .{ .at_175 = 0, .at_200 = 1 });
}

// ─── the new chrome widgets ──────────────────────────────────────────────────

test "chips and pills are snapped, on the grid and reachable" {
    const Local = struct {
        fn frame() !dvui.App.Result {
            var background = page(@src());
            defer background.deinit();
            var strip = ds.row(@src()).gap(ds.tokens.current.space_2xs).draw();
            defer strip.deinit();
            _ = ds.chip(@src(), "undo", ds.icons.undo).idExtra(0).draw();
            _ = ds.chip(@src(), "redo", ds.icons.redo).state(.current).idExtra(1).draw();
            ds.pill(@src(), "60 fps").mono(true).draw();
            return .ok;
        }
    };
    try expectClean(.{ .w = 260, .h = 80 }, "chip.zig", Local.frame);
    try expectClean(.{ .w = 260, .h = 80 }, "pill.zig", Local.frame);
}

// force
