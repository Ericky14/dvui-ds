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

/// Render `frame` once (settled) and write it to ds-screenshots/<name>.
fn capture(name: []const u8, w: f32, h: f32, frame: dvui.App.frameFunction) !void {
    var t = try dvui.testing.init(.{
        .image_dir = "ds-screenshots",
        .window_size = .{ .w = w, .h = h },
        .window_init_opts = .{ .theme = ds.tokens.dvuiTheme() },
    });
    defer t.deinit();
    try dvui.testing.settle(frame);
    try t.saveImage(frame, null, name);
}

/// Full-window themed background so components sit on the app surface.
fn background(src: std.builtin.SourceLocation) *dvui.BoxWidget {
    return dvui.box(src, .{}, .{
        .expand = .both,
        .background = true,
        .color_fill = ds.tokens.current.surface_0,
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
