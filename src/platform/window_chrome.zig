//! Borderless-window chrome: the drag region, the caption buttons and the
//! resize borders that an app draws itself.
//!
//! A window with its own title bar has to be borderless, or the OS draws one
//! too and you get two — which is exactly what the editor showed. Borderless
//! then costs you everything the OS title bar was doing: dragging, the resize
//! edges, and double-click-to-maximise. SDL gives all three back through one
//! callback, `SDL_SetWindowHitTest`, which asks "what is at this point?" — so
//! the app's job is to answer, every frame, where its own title bar and its
//! caption buttons are.
//!
//! Usage — the editor, once per frame, right after laying its title bar out:
//!
//!   ds.windowChrome.declare(.{
//!       .drag = title_bar_rect,
//!       .buttons = &.{ minimise_rect, maximise_rect, close_rect },
//!   });
//!
//! Rects are in dvui logical window coordinates — the same numbers a widget's
//! `dvui.Rect` carries — and are converted to SDL's window units here, so the
//! caller never has to know the display scale. Declare nothing and the window
//! simply has no drag region; the resize borders keep working, so a window is
//! never left un-resizable because one frame forgot.
//!
//! One window per process. The hit test is a C callback with a single userdata
//! slot, and the design system's `App` owns the one window there is.
const std = @import("std");
const dvui = @import("dvui");
const sdl3 = @import("sdl3");

/// What the OS should think is under a point.
pub const Hit = enum {
    normal,
    drag,
    resize_top,
    resize_bottom,
    resize_left,
    resize_right,
    resize_top_left,
    resize_top_right,
    resize_bottom_left,
    resize_bottom_right,
};

/// The regions an app declares for one frame.
pub const Regions = struct {
    /// The title bar: drag the window from here. Null means nothing is
    /// draggable, which is the safe state for a frame that has not declared
    /// anything yet.
    drag: ?dvui.Rect = null,
    /// Holes in `drag` — the caption buttons. A click on one of these has to
    /// reach the widget, so it stays `normal` even though it is inside the
    /// title bar.
    buttons: []const dvui.Rect = &.{},
    /// Width of the resize border on each edge, in logical px. 6–8 is the usual
    /// range: under 6 it is a fight to grab, over 8 it starts stealing clicks
    /// from the content behind it.
    resize_margin: f32 = 6,
};

/// How many caption buttons are remembered between frames: minimise, maximise
/// and close, with room for an app that adds one or two of its own.
const max_buttons = 8;

/// Live state, in *SDL window units* — the space the hit-test callback asks in.
pub const State = struct {
    active: bool = false,
    resizable: bool = true,
    drag: ?dvui.Rect = null,
    buttons: [max_buttons]dvui.Rect = @splat(.{}),
    button_count: usize = 0,
    resize_margin: f32 = 6,
    width: f32 = 0,
    height: f32 = 0,
};

var state: State = .{};
/// The window the hit test is installed on, for the caption buttons to act on.
var window_handle: ?sdl3.video.Window = null;

/// Classify a point against a window's regions. Pure, which is the whole reason
/// the hit test can be tested at all.
///
/// The order is the interesting part. Resize borders beat everything, including
/// the title bar, or a borderless window's top-left corner can be dragged but
/// never resized. Buttons beat the drag region, or the close button moves the
/// window instead of closing it. Everything else is normal, so the widgets
/// underneath keep their clicks.
pub fn classify(x: f32, y: f32, regions: State) Hit {
    const margin = regions.resize_margin;
    if (regions.resizable and margin > 0 and regions.width > 0 and regions.height > 0) {
        const on_left = x < margin;
        const on_right = x >= regions.width - margin;
        const on_top = y < margin;
        const on_bottom = y >= regions.height - margin;
        if (on_top and on_left) return .resize_top_left;
        if (on_top and on_right) return .resize_top_right;
        if (on_bottom and on_left) return .resize_bottom_left;
        if (on_bottom and on_right) return .resize_bottom_right;
        if (on_top) return .resize_top;
        if (on_bottom) return .resize_bottom;
        if (on_left) return .resize_left;
        if (on_right) return .resize_right;
    }
    const drag = regions.drag orelse return .normal;
    if (!contains(drag, x, y)) return .normal;
    for (regions.buttons[0..regions.button_count]) |button| {
        if (contains(button, x, y)) return .normal;
    }
    return .drag;
}

fn contains(r: dvui.Rect, x: f32, y: f32) bool {
    return x >= r.x and x < r.x + r.w and y >= r.y and y < r.y + r.h;
}

/// Declare this frame's regions. Call it inside a dvui frame, once the title
/// bar has been laid out; the rects are dvui logical window coordinates.
pub fn declare(regions: Regions) void {
    if (!state.active) return;

    // dvui logical → SDL window units, measured rather than assumed: SDL window
    // units are pixels on Windows and X11 but points on macOS and Wayland, and
    // dvui's logical unit is neither on a fractional-scale display.
    const logical = dvui.windowRect();
    const factor = if (logical.w > 0) state.width / logical.w else 1;

    state.drag = if (regions.drag) |r| scaleRect(r, factor) else null;
    state.button_count = @min(regions.buttons.len, max_buttons);
    for (regions.buttons[0..state.button_count], 0..) |button, index| {
        state.buttons[index] = scaleRect(button, factor);
    }
    state.resize_margin = regions.resize_margin * factor;
}

fn scaleRect(r: dvui.Rect, factor: f32) dvui.Rect {
    return .{ .x = r.x * factor, .y = r.y * factor, .w = r.w * factor, .h = r.h * factor };
}

/// Install the hit test on `window`. `App.init` calls it once.
pub fn install(window: sdl3.video.Window, resizable: bool) void {
    state = .{ .active = true, .resizable = resizable };
    window_handle = window;
    refreshSize(window);
    window.setHitTest(anyopaque, hitTest, null) catch {
        state.active = false;
        std.log.scoped(.dvui_ds).warn("window: no hit test; the title bar will not drag", .{});
    };
}

/// Re-read the window's size. The resize borders are measured from the far
/// edges, so a window that has been resized since the last frame would put them
/// in the wrong place.
pub fn refreshSize(window: sdl3.video.Window) void {
    const size = window.getSize() catch return;
    state.width = @floatFromInt(size[0]);
    state.height = @floatFromInt(size[1]);
}

/// The state the hit test is currently answering with. For tests and for an app
/// that wants to draw its own resize affordances in the right place.
pub fn current() State {
    return state;
}

// ─── The caption buttons ─────────────────────────────────────────────────────
//
// A borderless window draws its own minimise / maximise / close, so it needs
// the three actions the OS button used to perform. Close is the app's business
// (it owns the frame loop and whatever it has to save first), so it is not
// here: the frame function returns false.

/// Minimise the window.
pub fn minimise() void {
    const window = window_handle orelse return;
    window.minimize() catch {};
}

/// Maximise the window, or restore it if it already is. What a double-click on
/// the title bar does — and on Windows that double-click comes free, because
/// SDL answers `draggable` with HTCAPTION and the OS handles the rest.
pub fn toggleMaximise() void {
    const window = window_handle orelse return;
    if (maximised()) {
        window.restore() catch {};
    } else {
        window.maximize() catch {};
    }
}

/// True while the window is maximised — for drawing the restore icon instead of
/// the maximise one.
pub fn maximised() bool {
    const window = window_handle orelse return false;
    const flags = window.getFlags();
    return flags.maximized;
}

fn hitTest(_: sdl3.video.Window, area: sdl3.rect.IPoint, _: ?*anyopaque) sdl3.video.HitTestResult {
    return toSdl(classify(@floatFromInt(area.x), @floatFromInt(area.y), state));
}

fn toSdl(hit: Hit) sdl3.video.HitTestResult {
    return switch (hit) {
        .normal => .normal,
        .drag => .draggable,
        .resize_top => .resize_top,
        .resize_bottom => .resize_bottom,
        .resize_left => .resize_left,
        .resize_right => .resize_right,
        .resize_top_left => .resize_top_left,
        .resize_top_right => .resize_top_right,
        .resize_bottom_left => .resize_bottom_left,
        .resize_bottom_right => .resize_bottom_right,
    };
}

// ─── Windows: keep the rounded corners a borderless window loses ─────────────

/// Ask DWM for Windows 11's rounded corners.
///
/// Looked up at runtime rather than linked: a design system cannot make every
/// consumer add `dwmapi` to its build to keep its corners round, and a missing
/// export is a cosmetic loss rather than a failure.
pub fn applyNativeCorners(window: sdl3.video.Window) void {
    if (@import("builtin").os.tag != .windows) return;
    const props = window.getProperties() catch return;
    const handle = props.win32_hwnd orelse return;

    const library = LoadLibraryA("dwmapi.dll") orelse return;
    const symbol = GetProcAddress(library, "DwmSetWindowAttribute") orelse return;
    const setAttribute: *const fn (?*anyopaque, u32, *const anyopaque, u32) callconv(.winapi) i32 = @ptrCast(symbol);

    // DWMWA_WINDOW_CORNER_PREFERENCE = 33, DWMWCP_ROUND = 2.
    const round: u32 = 2;
    _ = setAttribute(handle.value, 33, &round, @sizeOf(u32));
}

extern "kernel32" fn LoadLibraryA(name: [*:0]const u8) callconv(.winapi) ?*anyopaque;
extern "kernel32" fn GetProcAddress(module: *anyopaque, name: [*:0]const u8) callconv(.winapi) ?*anyopaque;

test {
    _ = @import("window_chrome_tests.zig");
}
