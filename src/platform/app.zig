/// High-level application wrapper.
///
/// Encapsulates SDL3 window + wgpu GPU + dvui backends + frame loop
/// into a single struct. The entire render cycle is hidden — consumers
/// only provide a frame callback that draws dvui widgets.
const std = @import("std");
const dvui = @import("dvui");
const sdl3 = @import("sdl3");
const wgpu = @import("wgpu");
const GpuContext = @import("gpu.zig").GpuContext;
const tokens = @import("../tokens.zig");

const log = std.log.scoped(.dvui_ds);

pub const AppConfig = struct {
    title: [:0]const u8 = "dvui-ds",
    width: u32 = 900,
    height: u32 = 600,
    clear_color: [4]f64 = .{ 0.05, 0.05, 0.05, 1.0 },
};

pub const App = struct {
    window: sdl3.video.Window,
    gpu: GpuContext,
    backend: dvui.backend,
    renderer: dvui.render_backend,

    pub fn init(config: AppConfig) !App {
        log.info("starting: {s} ({d}x{d})", .{ config.title, config.width, config.height });

        // Linux only: on Windows/macOS this hint would restrict SDL to drivers that do
        // not exist there and make SDL_Init(VIDEO) fail.
        if (@import("builtin").os.tag == .linux) {
            sdl3.hints.set(.video_driver, "wayland,x11") catch {};
        }
        try sdl3.init(.{ .video = true, .events = true });

        const window = try sdl3.video.Window.init(
            config.title,
            config.width,
            config.height,
            .{ .resizable = true, .high_pixel_density = true },
        );

        const content_scale = detectContentScale(window);
        log.info("window: scale={d:.2}", .{content_scale});

        // Windows/X11 size windows in pixels and report the DPI scale
        // separately (no HiDPI framebuffer), so `config.width x height` would
        // come out `scale` times smaller in logical units than on Wayland.
        // Grow the window so the logical layout size is what was asked for.
        if (content_scale > 1.0 and !dvui.backend.hasHiDpiFramebuffer(window)) {
            const scaled_w: u32 = @intFromFloat(@round(@as(f32, @floatFromInt(config.width)) * content_scale));
            const scaled_h: u32 = @intFromFloat(@round(@as(f32, @floatFromInt(config.height)) * content_scale));
            window.setSize(scaled_w, scaled_h) catch {};
            log.info("window: sized {d}x{d} px for {d}x{d} logical", .{ scaled_w, scaled_h, config.width, config.height });
        }

        const gpu = try GpuContext.init(window);

        const backend = dvui.backend.init(std.heap.smp_allocator, window, content_scale);

        const renderer = try dvui.render_backend.init(
            std.heap.smp_allocator,
            gpu.device,
            gpu.queue,
            gpu.surface_config.format,
        );

        log.info("ready", .{});

        return .{
            .window = window,
            .gpu = gpu,
            .backend = backend,
            .renderer = renderer,
        };
    }

    pub fn deinit(self: *App) void {
        self.renderer.deinit();
        self.backend.deinit();
        self.gpu.deinit();
        self.window.deinit();
        sdl3.quit(.{ .video = true, .events = true });
    }

    /// Run the main loop. Calls `frame_fn` each frame for widget rendering.
    /// Loop exits when `frame_fn` returns `false` or the window is closed.
    pub fn run(self: *App, frame_fn: *const fn () bool) !void {
        const bg = tokens.current.surface_0;
        const clear_color = .{
            @as(f64, @floatFromInt(bg.r)) / 255.0,
            @as(f64, @floatFromInt(bg.g)) / 255.0,
            @as(f64, @floatFromInt(bg.b)) / 255.0,
            1.0,
        };
        try self.runWithConfig(frame_fn, clear_color);
    }

    /// Run with a custom clear color.
    pub fn runWithConfig(self: *App, frame_fn: *const fn () bool, clear_color: [4]f64) !void {
        // Create dvui.Window here — self is now at its final address,
        // so pointers to backend/renderer fields are stable.
        var ui = try dvui.Window.init(
            @src(),
            std.heap.smp_allocator,
            dvui.Backend.init(&self.backend, &self.renderer),
            .{ .theme = tokens.dvuiTheme() },
        );
        defer ui.deinit();

        while (!self.backend.quit) {
            self.backend.addAllEvents(&ui);
            if (self.backend.quit) break;

            // ─── Layout-settle pass (no rendering) ──────────────────────────
            // dvui is immediate-mode: a widget's size is measured *during* its
            // frame and only cached for the next one. So content that first
            // appears this frame (e.g. after switching storybook pages) has no
            // cached size yet — it lays out at zero/min size for one visible
            // frame, then "pops in" and pushes the layout the next frame.
            //
            // To avoid that, run the UI once here WITHOUT rendering: null the
            // render targets so every draw / render-target call no-ops (only
            // CPU layout + glyph/icon texture uploads run), which warms the
            // min-size cache. The visible pass below then lays everything out
            // correctly on the same frame. dvui clears events in end(), so the
            // visible pass sees none — input is handled exactly once, here.
            self.renderer.current_pass = null;
            self.renderer.command_encoder = null;
            try ui.begin(self.backend.nanoTime());
            const keep_running = frame_fn();
            _ = try ui.end(.{});
            if (!keep_running) break;

            // Resize
            const new_fb = self.window.getSizeInPixels() catch .{ self.gpu.width, self.gpu.height };
            const new_w: u32 = @intCast(new_fb[0]);
            const new_h: u32 = @intCast(new_fb[1]);
            if (new_w != self.gpu.width or new_h != self.gpu.height) {
                self.gpu.resize(new_w, new_h);
            }

            // Acquire
            const surface_texture = self.gpu.currentTexture() orelse {
                self.gpu.resize(self.gpu.width, self.gpu.height);
                continue;
            };

            const view = wgpu.wgpuTextureCreateView(surface_texture.texture, null);
            defer wgpu.wgpuTextureViewRelease(view);

            const encoder = self.gpu.createEncoder();

            // Begin render pass
            const pass = wgpu.wgpuCommandEncoderBeginRenderPass(encoder, &.{
                .nextInChain = null,
                .label = wgpu.WGPUStringView{ .data = "main", .length = 4 },
                .colorAttachmentCount = 1,
                .colorAttachments = &wgpu.WGPURenderPassColorAttachment{
                    .view = view,
                    .depthSlice = wgpu.WGPU_DEPTH_SLICE_UNDEFINED,
                    .resolveTarget = null,
                    .loadOp = wgpu.WGPULoadOp_Clear,
                    .storeOp = wgpu.WGPUStoreOp_Store,
                    .clearValue = .{ .r = clear_color[0], .g = clear_color[1], .b = clear_color[2], .a = clear_color[3] },
                },
                .depthStencilAttachment = null,
                .occlusionQuerySet = null,
                .timestampWrites = null,
            });

            // dvui frame
            self.renderer.setViewportSize(.{
                .width = @floatFromInt(self.gpu.width),
                .height = @floatFromInt(self.gpu.height),
            });
            self.renderer.setRenderPass(pass);
            self.renderer.setCommandEncoder(encoder, view);

            // Visible pass — same frame, now with warmed min-sizes. No events
            // remain (consumed by the settle pass above), so this only renders.
            try ui.begin(self.backend.nanoTime());
            _ = frame_fn();
            _ = try ui.end(.{});

            // Enable/disable text input for focused text widgets (required on Wayland)
            self.backend.textInputRect(ui.textInputRequested());

            // Update cursor based on dvui's request (e.g. hand on button hover)
            self.backend.setCursor(ui.cursorRequested());

            // End render pass
            if (self.renderer.current_pass) |active_pass| {
                wgpu.wgpuRenderPassEncoderEnd(active_pass);
                wgpu.wgpuRenderPassEncoderRelease(active_pass);
                self.renderer.current_pass = null;
            } else {
                wgpu.wgpuRenderPassEncoderEnd(pass);
                wgpu.wgpuRenderPassEncoderRelease(pass);
            }

            self.gpu.submit(encoder);
            self.gpu.present();
        }
    }
};

fn detectContentScale(window: sdl3.video.Window) f32 {
    const pixels = window.getSizeInPixels() catch return 1.0;
    const win_size = window.getSize() catch return 1.0;
    if (pixels[0] > win_size[0]) {
        return @as(f32, @floatFromInt(pixels[0])) / @as(f32, @floatFromInt(win_size[0]));
    }
    const display = window.getDisplayForWindow() catch return 1.0;
    return display.getContentScale() catch 1.0;
}
