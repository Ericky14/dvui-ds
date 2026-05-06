/// Timestamped logging — drop-in `std.Options.logFn` for dvui-ds apps.
///
/// Usage in your app's root file:
///   const ds = @import("dvui_ds");
///
///   pub const std_options: std.Options = .{
///       .log_level = .info,
///       .logFn = ds.log.timestamped,
///   };
///
///   pub fn main() !void {
///       ds.log.init();  // capture start time
///       // ...
///   }
const std = @import("std");
const sdl3 = @import("sdl3");

var start_time: u64 = 0;

/// Call once at the top of main() to capture the reference time.
pub fn init() void {
    start_time = @intCast(sdl3.timer.getPerformanceCounter());
}

/// Timestamped log function compatible with `std.Options.logFn`.
/// Prints: [secs.millis] LEVEL (scope) message
pub fn timestamped(
    comptime level: std.log.Level,
    comptime scope: @EnumLiteral(),
    comptime format: []const u8,
    args: anytype,
) void {
    const scope_prefix = if (scope == .default) "" else "(" ++ @tagName(scope) ++ ") ";
    const level_prefix = switch (level) {
        .err => "ERROR",
        .warn => "WARN ",
        .info => "INFO ",
        .debug => "DEBUG",
    };
    const freq: u64 = @intCast(sdl3.timer.getPerformanceFrequency());
    const now: u64 = @intCast(sdl3.timer.getPerformanceCounter());
    const elapsed = now -| start_time;
    const secs = elapsed / freq;
    const frac = elapsed % freq;
    const millis = frac * 1000 / freq;
    std.debug.print("[{d:>4}.{d:0>3}] {s} {s}" ++ format ++ "\n", .{ secs, millis, level_prefix, scope_prefix } ++ args);
}
