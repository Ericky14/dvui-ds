/// Standalone runner for dvui-ds applications.
///
/// Thin wrapper over `App` — initializes the DS theme and runs the loop.
const tokens = @import("../tokens.zig");
const App = @import("app.zig").App;

pub const RunConfig = struct {
    title: [:0]const u8 = "dvui-ds",
    width: u32 = 900,
    height: u32 = 600,
    theme: tokens.Theme = tokens.default_theme,
};

/// Run a dvui-ds application. The `frame_fn` draws widgets; return `false` to exit.
pub fn run(config: RunConfig, frame_fn: *const fn () bool) !void {
    var app = try App.init(.{
        .title = config.title,
        .width = config.width,
        .height = config.height,
    });
    defer app.deinit();

    const ds = @import("../ds.zig");
    ds.init(config.theme);

    try app.run(frame_fn);
}
