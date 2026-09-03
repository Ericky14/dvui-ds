//! wgpu + SDL3 platform backend for dvui.
//!
//! Uses zig-sdl3 bindings. Integrates with an existing SDL3 window.
//! Rendering is delegated to the wgpu render backend.

const std = @import("std");
const dvui = @import("dvui");
const sdl3 = @import("sdl3");
const focus = @import("ds_focus");

pub const kind: dvui.enums.Backend = .custom;

gpa: std.mem.Allocator,
arena: std.heap.ArenaAllocator,
window: sdl3.video.Window,
cursor: ?sdl3.mouse.Cursor,
quit: bool,
scale: f32,

/// dvui reads clocks through the global `dvui.io` ("set by the backend when it
/// is initialized"): `Window.mouseWheelBatch` calls `std.Io.Clock.awake.now(dvui.io)`
/// on every wheel event and dereferences an unset vtable if nobody assigned it —
/// the first mouse-wheel tick crashed the zigame editor (found 2026-09-03). The
/// backend owns one blocking single-threaded `Io` for that, like dvui's own
/// backends do; `init_single_threaded` ships `Allocator.failing`, so give it a
/// real allocator for the paths that allocate internally.
var dvui_io: std.Io.Threaded = blk: {
    var instance: std.Io.Threaded = .init_single_threaded;
    instance.allocator = std.heap.page_allocator;
    break :blk instance;
};

pub fn init(gpa: std.mem.Allocator, window: sdl3.video.Window, content_scale: f32) @This() {
    dvui.io = dvui_io.io();
    return .{
        .gpa = gpa,
        .arena = .init(gpa),
        .window = window,
        .cursor = null,
        .quit = false,
        .scale = content_scale,
    };
}

pub fn deinit(self: *@This()) void {
    if (self.cursor) |cur| cur.deinit();
    self.arena.deinit();
}

pub fn begin(_: *@This(), _: std.mem.Allocator) !void {}

pub fn end(_: *@This()) !void {}

/// Process all pending SDL3 events and feed them to dvui.
pub fn addAllEvents(self: *@This(), win: *dvui.Window) void {
    while (sdl3.events.poll()) |event| {
        switch (event) {
            .quit, .window_close_requested => {
                self.quit = true;
                return;
            },
            .key_down => |key| {
                focus.notifyKeyboard();
                handleKeyEvent(win, key, true);
            },
            .key_up => |key| handleKeyEvent(win, key, false),
            .text_input => |ti| handleTextInput(win, ti),
            .mouse_motion => |motion| self.handleMouseMotion(win, motion),
            .mouse_button_down => |btn| {
                focus.notifyMouse();
                self.handleMouseButton(win, btn, true);
            },
            .mouse_button_up => |btn| self.handleMouseButton(win, btn, false),
            .mouse_wheel => |wheel| handleMouseWheel(win, wheel),
            .window_display_scale_changed, .window_pixel_size_changed => {
                self.scale = detectContentScale(self.window);
            },
            else => {},
        }
    }
}

/// Real framebuffer size. This MUST match the size the wgpu surface is
/// configured with (`GpuContext` uses `getSizeInPixels()` too): dvui derives
/// its clip/scissor rects from this, and wgpu rejects a scissor larger than
/// the render target.
pub fn pixelSize(self: *@This()) dvui.Size.Physical {
    const pixels = self.window.getSizeInPixels() catch return .{ .w = 0, .h = 0 };
    return .{
        .w = @floatFromInt(pixels[0]),
        .h = @floatFromInt(pixels[1]),
    };
}

pub fn windowSize(self: *@This()) dvui.Size.Natural {
    const size = self.window.getSize() catch return .{ .w = 0, .h = 0 };
    return .{
        .w = @floatFromInt(size[0]),
        .h = @floatFromInt(size[1]),
    };
}

/// DPI scaling dvui should apply to logical content.
///
/// Wayland/macOS hand SDL a HiDPI framebuffer (pixels > window size), and dvui
/// picks that up through `pixelSize()`/`windowSize()` as its natural scale;
/// returning the scale here too would double-apply it. Windows/X11 report
/// pixels == window size, so the display content scale is applied here.
pub fn contentScale(self: *@This()) f32 {
    if (hasHiDpiFramebuffer(self.window)) return 1.0;
    return self.scale;
}

pub fn clipboardText(_: *@This()) ![]const u8 {
    return sdl3.clipboard.getText() catch "";
}

pub fn clipboardTextSet(self: *@This(), text: []const u8) !void {
    const duped = try self.gpa.dupeSentinel(u8, text, 0);
    defer self.gpa.free(duped);
    sdl3.clipboard.setText(duped) catch return error.BackendError;
}

pub fn openURL(self: *@This(), url: []const u8, _: bool) !void {
    const duped = self.gpa.dupeSentinel(u8, url, 0) catch return error.OutOfMemory;
    defer self.gpa.free(duped);
    sdl3.openURL(duped) catch return error.BackendError;
}

pub fn setCursor(self: *@This(), cursor: dvui.enums.Cursor) void {
    if (cursor == .hidden) {
        sdl3.mouse.hide() catch {};
        return;
    }
    sdl3.mouse.show() catch {};

    if (self.cursor) |cur| cur.deinit();
    const shape: sdl3.mouse.SystemCursor = switch (cursor) {
        .arrow => .default,
        .arrow_all => .move,
        .arrow_n_s => .north_south_resize,
        .arrow_ne_sw => .northeast_southwest_resize,
        .arrow_nw_se => .northwest_southeast_resize,
        .arrow_w_e => .east_west_resize,
        .bad => .not_allowed,
        .crosshair => .crosshair,
        .hand => .pointer,
        .ibeam => .text,
        .wait => .wait,
        .wait_arrow => .progress,
        .hidden => unreachable,
    };
    self.cursor = sdl3.mouse.Cursor.initSystem(shape) catch null;
    if (self.cursor) |cur| sdl3.mouse.set(cur) catch {};
}

/// Enable/disable SDL3 text input based on dvui's request.
/// Must be called each frame after `ui.end()` so that text entry widgets
/// receive `text_input` events from the compositor (required on Wayland).
pub fn textInputRect(self: *@This(), rect: ?dvui.Rect.Natural) void {
    if (rect) |r| {
        sdl3.keyboard.setTextInputArea(self.window, .{
            .x = @intFromFloat(r.x),
            .y = @intFromFloat(r.y),
            .w = @intFromFloat(r.w),
            .h = @intFromFloat(r.h),
        }, 0) catch {};
        sdl3.keyboard.startTextInput(self.window) catch {};
    } else {
        sdl3.keyboard.stopTextInput(self.window) catch {};
    }
}

/// Presentation happens in `App.runWithConfig` (wgpu surface present), so
/// dvui's end-of-frame present request is a no-op here.
pub fn renderPresent(_: *@This()) void {}

pub fn preferredColorScheme(_: *@This()) ?dvui.enums.ColorScheme {
    const theme = sdl3.video.getSystemTheme() orelse return null;
    return switch (theme) {
        .dark => .dark,
        .light => .light,
    };
}

pub fn prefersReducedMotion(_: *@This()) bool {
    const output = portalRead("org.freedesktop.appearance", "reduce-motion") orelse return false;
    const val = parsePortalUint(&output) orelse return false;
    return val == 1;
}

const libc = struct {
    extern "c" fn popen(command: [*:0]const u8, mode: [*:0]const u8) ?*anyopaque;
    extern "c" fn pclose(stream: *anyopaque) c_int;
    extern "c" fn fgets(buf: [*]u8, size: c_int, stream: *anyopaque) ?[*]u8;
};

/// Call busctl to read a portal setting. Returns a stack buffer with output.
fn portalRead(namespace: [*:0]const u8, key: [*:0]const u8) ?[256]u8 {
    var cmd_buf: [512]u8 = undefined;
    const full_cmd = std.fmt.bufPrint(&cmd_buf, "busctl --user call org.freedesktop.portal.Desktop /org/freedesktop/portal/desktop org.freedesktop.portal.Settings Read ss {s} {s}\x00", .{ namespace, key }) catch return null;
    const stream = libc.popen(full_cmd[0 .. full_cmd.len - 1 :0], "r") orelse return null;
    defer _ = libc.pclose(stream);
    var buf: [256]u8 = undefined;
    if (libc.fgets(&buf, 256, stream) == null) return null;
    return buf;
}

/// Parse the uint value from busctl output like "v u 1\n".
fn parsePortalUint(output: []const u8) ?u32 {
    const trimmed = std.mem.trimEnd(u8, output, "\n\r \x00");
    const last_space = std.mem.lastIndexOfScalar(u8, trimmed, ' ') orelse return null;
    return std.fmt.parseInt(u32, trimmed[last_space + 1 ..], 10) catch null;
}

pub fn nanoTime(_: *@This()) i128 {
    const freq: i128 = @intCast(sdl3.timer.getPerformanceFrequency());
    const value: i128 = @intCast(sdl3.timer.getPerformanceCounter());
    return @divFloor(value * 1_000_000_000, freq);
}

pub fn sleep(_: *@This(), ns: u64) void {
    const ms: u32 = @intCast(@min(ns / 1_000_000, std.math.maxInt(u32)));
    sdl3.timer.delay(ms);
}

pub fn refresh(_: *@This()) void {
    // Push a wakeup event so SDL_WaitEvent returns immediately
    sdl3.events.push(.{ .user = .{
        .common = .{ .timestamp = 0 },
        .event_type = @backingInt(sdl3.events.Type.user),
        .code = 0,
    } }) catch {};
}

// --- Event handlers ---

fn handleKeyEvent(dvui_window: *dvui.Window, key: sdl3.events.Keyboard, down: bool) void {
    if (key.repeat) {
        const dvui_key = sdlScancodeToDvui(key.scancode);
        _ = dvui_window.addEventKey(.{ .action = .repeat, .code = dvui_key, .mod = sdlModToDvui(key.mod) }) catch {};
        return;
    }
    const dvui_action: @FieldType(dvui.Event.Key, "action") = if (down) .down else .up;
    const dvui_key = sdlScancodeToDvui(key.scancode);
    _ = dvui_window.addEventKey(.{ .action = dvui_action, .code = dvui_key, .mod = sdlModToDvui(key.mod) }) catch {};
}

fn handleTextInput(dvui_window: *dvui.Window, ti: sdl3.events.TextInput) void {
    _ = dvui_window.addEventText(.{ .text = ti.text }) catch {};
}

/// SDL reports the mouse in window coordinates; dvui wants framebuffer pixels.
/// The factor is the framebuffer ratio alone (`pixelSize / windowSize`: 2.0 on a
/// HiDPI Wayland/macOS surface, 1.0 on Windows/X11), exactly as dvui's own SDL
/// backend does. NOT `natural_scale`: that already includes `contentScale()`,
/// which on Windows/X11 is the display scale (1.75 on a 175 % desk), so using it
/// scaled every click twice and only the top-left 57 % of the window was
/// reachable (found 2026-09-03 driving the zigame welcome sheet).
fn mouseScale(self: *@This()) f32 {
    const window_w = self.windowSize().w;
    return if (window_w == 0) 1.0 else self.pixelSize().w / window_w;
}

fn handleMouseMotion(self: *@This(), dvui_window: *dvui.Window, motion: sdl3.events.MouseMotion) void {
    const scale = self.mouseScale();
    const physical: dvui.Point.Physical = .{
        .x = motion.x * scale,
        .y = motion.y * scale,
    };
    _ = dvui_window.addEventMouseMotion(.{ .pt = physical }) catch {};
}

fn handleMouseButton(self: *@This(), dvui_window: *dvui.Window, btn: sdl3.events.MouseButton, down: bool) void {
    const dvui_button: dvui.enums.Button = switch (btn.button) {
        .left => .left,
        .right => .right,
        .middle => .middle,
        else => return, // ignore extra buttons (x1, x2, etc.)
    };
    // Update the mouse position first so the press lands where the pointer is.
    const scale = self.mouseScale();
    const physical: dvui.Point.Physical = .{
        .x = btn.x * scale,
        .y = btn.y * scale,
    };
    _ = dvui_window.addEventMouseMotion(.{ .pt = physical }) catch {};
    const dvui_action: dvui.Event.Mouse.Action = if (down) .press else .release;
    _ = dvui_window.addEventMouseButton(dvui_button, dvui_action) catch {};
}

fn handleMouseWheel(dvui_window: *dvui.Window, wheel: sdl3.events.MouseWheel) void {
    // dvui wants to know whether the wheel is a classic notched mouse or a
    // smooth-scrolling trackpad (it changes scroll animation / batching).
    // Same heuristic as dvui's own SDL backend: the smallest raw delta seen in
    // the current batch is exactly 1.0 for a notched wheel.
    if (wheel.scroll_x != 0) {
        const mouse_type = wheelMouseType(dvui_window, .horizontal, wheel.scroll_x);
        _ = dvui_window.addEventMouseWheel(wheel.scroll_x * dvui.scroll_speed, .horizontal, mouse_type) catch {};
    }
    if (wheel.scroll_y != 0) {
        const mouse_type = wheelMouseType(dvui_window, .vertical, wheel.scroll_y);
        _ = dvui_window.addEventMouseWheel(wheel.scroll_y * dvui.scroll_speed, .vertical, mouse_type) catch {};
    }
}

fn wheelMouseType(dvui_window: *dvui.Window, dir: dvui.enums.Direction, raw_delta: f32) dvui.enums.MouseType {
    const batch_min = dvui_window.mouseWheelBatch(dir, raw_delta);
    return if (batch_min == 1.0) .mouse else .trackpad;
}

fn sdlModToDvui(mod: sdl3.keycode.KeyModifier) dvui.enums.Mod {
    var result = dvui.enums.Mod.none;
    if (mod.left_shift or mod.right_shift) result.combine(.lshift);
    if (mod.left_alt or mod.right_alt) result.combine(.lalt);
    if (mod.left_control or mod.right_control) result.combine(.lcontrol);
    if (mod.left_gui or mod.right_gui) result.combine(.lcommand);
    return result;
}

fn sdlScancodeToDvui(scancode: ?sdl3.Scancode) dvui.enums.Key {
    const sc = scancode orelse return .unknown;
    return switch (sc) {
        .a => .a,
        .b => .b,
        .c => .c,
        .d => .d,
        .e => .e,
        .f => .f,
        .g => .g,
        .h => .h,
        .i => .i,
        .j => .j,
        .k => .k,
        .l => .l,
        .m => .m,
        .n => .n,
        .o => .o,
        .p => .p,
        .q => .q,
        .r => .r,
        .s => .s,
        .t => .t,
        .u => .u,
        .v => .v,
        .w => .w,
        .x => .x,
        .y => .y,
        .z => .z,

        .zero => .zero,
        .one => .one,
        .two => .two,
        .three => .three,
        .four => .four,
        .five => .five,
        .six => .six,
        .seven => .seven,
        .eight => .eight,
        .nine => .nine,

        .func1 => .f1,
        .func2 => .f2,
        .func3 => .f3,
        .func4 => .f4,
        .func5 => .f5,
        .func6 => .f6,
        .func7 => .f7,
        .func8 => .f8,
        .func9 => .f9,
        .func10 => .f10,
        .func11 => .f11,
        .func12 => .f12,

        .return_key => .enter,
        .escape => .escape,
        .tab => .tab,
        .left_shift => .left_shift,
        .right_shift => .right_shift,
        .left_ctrl => .left_control,
        .right_ctrl => .right_control,
        .left_alt => .left_alt,
        .right_alt => .right_alt,
        .left_gui => .left_command,
        .right_gui => .right_command,
        .num_lock_clear => .num_lock,
        .caps_lock => .caps_lock,
        .print_screen => .print,
        .scroll_lock => .scroll_lock,
        .pause => .pause,
        .delete => .delete,
        .home => .home,
        .end => .end,
        .pageup => .page_up,
        .pagedown => .page_down,
        .insert => .insert,
        .left => .left,
        .right => .right,
        .up => .up,
        .down => .down,
        .backspace => .backspace,
        .space => .space,
        .minus => .minus,
        .equals => .equal,
        .left_bracket => .left_bracket,
        .right_bracket => .right_bracket,
        .backslash => .backslash,
        .semicolon => .semicolon,
        .apostrophe => .apostrophe,
        .comma => .comma,
        .period => .period,
        .slash => .slash,
        .grave => .grave,

        else => .unknown,
    };
}

/// True when SDL gives the window a framebuffer larger than its logical size
/// (Wayland, macOS retina). False on Windows/X11, where window units are pixels.
pub fn hasHiDpiFramebuffer(window: sdl3.video.Window) bool {
    const pixels = window.getSizeInPixels() catch return false;
    const win_size = window.getSize() catch return false;
    return pixels[0] > win_size[0] or pixels[1] > win_size[1];
}

fn detectContentScale(window: sdl3.video.Window) f32 {
    const pixels = window.getSizeInPixels() catch return 1.0;
    const win_size = window.getSize() catch return 1.0;
    if (pixels[0] > win_size[0]) {
        return @as(f32, @floatFromInt(pixels[0])) / @as(f32, @floatFromInt(win_size[0]));
    }
    const display = window.getDisplayForWindow() catch return 1.0;
    return display.getContentScale() catch 1.0;
}
