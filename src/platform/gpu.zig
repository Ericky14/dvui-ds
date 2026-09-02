/// GPU context — wraps wgpu instance, adapter, device, queue, and surface.
///
/// One call to `init()` replaces ~50 lines of callback boilerplate.
const std = @import("std");
const sdl3 = @import("sdl3");
const wgpu = @import("wgpu");

const log = std.log.scoped(.dvui_ds);

pub const GpuContext = struct {
    instance: wgpu.WGPUInstance,
    surface: wgpu.WGPUSurface,
    adapter: wgpu.WGPUAdapter,
    device: wgpu.WGPUDevice,
    queue: wgpu.WGPUQueue,
    surface_config: wgpu.WGPUSurfaceConfiguration,
    width: u32,
    height: u32,

    pub fn init(window: sdl3.video.Window) !GpuContext {
        const instance = wgpu.wgpuCreateInstance(&.{
            .nextInChain = null,
            .requiredFeatureCount = 0,
            .requiredFeatures = null,
            .requiredLimits = null,
        }) orelse return error.FailedToCreateInstance;

        const surface = createSurface(instance, window) orelse {
            wgpu.wgpuInstanceRelease(instance);
            return error.FailedToCreateSurface;
        };

        const adapter = requestAdapter(instance, surface);
        const device = requestDevice(instance, adapter);
        const queue = wgpu.wgpuDeviceGetQueue(device);

        const fb = window.getSizeInPixels() catch .{ 800, 600 };
        const width: u32 = @intCast(fb[0]);
        const height: u32 = @intCast(fb[1]);

        const surface_config = wgpu.WGPUSurfaceConfiguration{
            .nextInChain = null,
            .device = device,
            .format = wgpu.WGPUTextureFormat_BGRA8Unorm,
            .usage = wgpu.WGPUTextureUsage_RenderAttachment,
            .viewFormatCount = 0,
            .viewFormats = null,
            .alphaMode = wgpu.WGPUCompositeAlphaMode_Auto,
            .width = width,
            .height = height,
            .presentMode = wgpu.WGPUPresentMode_Fifo,
        };
        wgpu.wgpuSurfaceConfigure(surface, &surface_config);

        log.info("gpu: device ready, surface {d}x{d}", .{ width, height });

        return .{
            .instance = instance,
            .surface = surface,
            .adapter = adapter,
            .device = device,
            .queue = queue,
            .surface_config = surface_config,
            .width = width,
            .height = height,
        };
    }

    pub fn deinit(self: *GpuContext) void {
        wgpu.wgpuQueueRelease(self.queue);
        wgpu.wgpuDeviceRelease(self.device);
        wgpu.wgpuAdapterRelease(self.adapter);
        wgpu.wgpuSurfaceRelease(self.surface);
        wgpu.wgpuInstanceRelease(self.instance);
    }

    pub fn resize(self: *GpuContext, width: u32, height: u32) void {
        if (width == 0 or height == 0) return;
        self.width = width;
        self.height = height;
        self.surface_config.width = width;
        self.surface_config.height = height;
        wgpu.wgpuSurfaceConfigure(self.surface, &self.surface_config);
    }

    pub fn currentTexture(self: *GpuContext) ?wgpu.WGPUSurfaceTexture {
        var surface_texture: wgpu.WGPUSurfaceTexture = undefined;
        wgpu.wgpuSurfaceGetCurrentTexture(self.surface, &surface_texture);
        if (surface_texture.status != wgpu.WGPUSurfaceGetCurrentTextureStatus_SuccessOptimal and
            surface_texture.status != wgpu.WGPUSurfaceGetCurrentTextureStatus_SuccessSuboptimal)
        {
            return null;
        }
        return surface_texture;
    }

    pub fn createEncoder(self: *GpuContext) wgpu.WGPUCommandEncoder {
        return wgpu.wgpuDeviceCreateCommandEncoder(self.device, &.{
            .nextInChain = null,
            .label = wgpu.WGPUStringView{ .data = "frame", .length = 5 },
        });
    }

    pub fn submit(self: *GpuContext, encoder: wgpu.WGPUCommandEncoder) void {
        const cmd_buf = wgpu.wgpuCommandEncoderFinish(encoder, &.{
            .nextInChain = null,
            .label = wgpu.WGPUStringView{ .data = "cmd", .length = 3 },
        });
        wgpu.wgpuQueueSubmit(self.queue, 1, &cmd_buf);
    }

    pub fn present(self: *GpuContext) void {
        _ = wgpu.wgpuSurfacePresent(self.surface);
    }
};

// ─── Internal helpers ────────────────────────────────────────────────────────

fn requestAdapter(instance: wgpu.WGPUInstance, surface: wgpu.WGPUSurface) wgpu.WGPUAdapter {
    var adapter: wgpu.WGPUAdapter = null;
    _ = wgpu.wgpuInstanceRequestAdapter(instance, &.{
        .nextInChain = null,
        .compatibleSurface = surface,
        .powerPreference = wgpu.WGPUPowerPreference_HighPerformance,
        .backendType = wgpu.WGPUBackendType_Undefined,
        .forceFallbackAdapter = @intFromBool(false),
    }, .{
        .nextInChain = null,
        .mode = wgpu.WGPUCallbackMode_AllowProcessEvents,
        .callback = &struct {
            fn cb(_: wgpu.WGPURequestAdapterStatus, a: wgpu.WGPUAdapter, _: wgpu.WGPUStringView, ud: ?*anyopaque, _: ?*anyopaque) callconv(.c) void {
                const ptr: *wgpu.WGPUAdapter = @ptrCast(@alignCast(ud));
                ptr.* = a;
            }
        }.cb,
        .userdata1 = @ptrCast(&adapter),
        .userdata2 = null,
    });
    while (adapter == null) wgpu.wgpuInstanceProcessEvents(instance);
    return adapter;
}

fn requestDevice(instance: wgpu.WGPUInstance, adapter: wgpu.WGPUAdapter) wgpu.WGPUDevice {
    var device: wgpu.WGPUDevice = null;
    _ = wgpu.wgpuAdapterRequestDevice(adapter, &.{
        .nextInChain = null,
        .label = wgpu.WGPUStringView{ .data = "dvui-ds", .length = 7 },
        .requiredFeatureCount = 0,
        .requiredFeatures = null,
        .requiredLimits = null,
        .defaultQueue = .{
            .nextInChain = null,
            .label = wgpu.WGPUStringView{ .data = "default", .length = 7 },
        },
        .deviceLostCallbackInfo = .{ .nextInChain = null, .mode = wgpu.WGPUCallbackMode_AllowSpontaneous, .callback = null, .userdata1 = null, .userdata2 = null },
        .uncapturedErrorCallbackInfo = .{ .nextInChain = null, .callback = null, .userdata1 = null, .userdata2 = null },
    }, .{
        .nextInChain = null,
        .mode = wgpu.WGPUCallbackMode_AllowProcessEvents,
        .callback = &struct {
            fn cb(_: wgpu.WGPURequestDeviceStatus, d: wgpu.WGPUDevice, _: wgpu.WGPUStringView, ud: ?*anyopaque, _: ?*anyopaque) callconv(.c) void {
                const ptr: *wgpu.WGPUDevice = @ptrCast(@alignCast(ud));
                ptr.* = d;
            }
        }.cb,
        .userdata1 = @ptrCast(&device),
        .userdata2 = null,
    });
    while (device == null) wgpu.wgpuInstanceProcessEvents(instance);
    return device;
}

fn createSurface(instance: wgpu.WGPUInstance, window: sdl3.video.Window) ?wgpu.WGPUSurface {
    const props = window.getProperties() catch return null;

    // Windows: wgpu wants the HWND plus the module HINSTANCE (null is accepted).
    if (props.win32_hwnd) |hwnd| {
        log.info("surface: win32", .{});
        const from_win32 = wgpu.WGPUSurfaceSourceWindowsHWND{
            .chain = .{ .next = null, .sType = wgpu.WGPUSType_SurfaceSourceWindowsHWND },
            .hinstance = if (props.win32_instance) |inst| inst.value else null,
            .hwnd = hwnd.value,
        };
        return wgpu.wgpuInstanceCreateSurface(instance, &.{
            .nextInChain = @ptrCast(@constCast(&from_win32)),
            .label = wgpu.WGPUStringView{ .data = "win32", .length = 5 },
        });
    }

    if (props.wayland_display) |display| {
        if (props.wayland_surface) |wl_surface| {
            log.info("surface: wayland", .{});
            const from_wayland = wgpu.WGPUSurfaceSourceWaylandSurface{
                .chain = .{ .next = null, .sType = wgpu.WGPUSType_SurfaceSourceWaylandSurface },
                .display = display.value,
                .surface = wl_surface.value,
            };
            return wgpu.wgpuInstanceCreateSurface(instance, &.{
                .nextInChain = @ptrCast(@constCast(&from_wayland)),
                .label = wgpu.WGPUStringView{ .data = "wayland", .length = 7 },
            });
        }
    }

    if (props.x11_display) |display| {
        if (props.x11_window) |x11_win| {
            log.info("surface: x11", .{});
            const from_x11 = wgpu.WGPUSurfaceSourceXlibWindow{
                .chain = .{ .next = null, .sType = wgpu.WGPUSType_SurfaceSourceXlibWindow },
                .display = display.value,
                .window = @intCast(x11_win),
            };
            return wgpu.wgpuInstanceCreateSurface(instance, &.{
                .nextInChain = @ptrCast(@constCast(&from_x11)),
                .label = wgpu.WGPUStringView{ .data = "x11", .length = 3 },
            });
        }
    }

    return null;
}
