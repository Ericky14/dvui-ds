/// dvui-ds Storybook — visual component showcase.
///
/// Demonstrates all ds widgets with the default dark theme.
/// Run with: zig build example
const dvui = @import("dvui");
const ds = @import("dvui_ds");

pub fn main() !void {
    // Use default theme (no custom init needed — ds ships with sensible defaults)
    _ = ds;

    // TODO: Initialize dvui window + frame loop when building standalone storybook.
    // For now this serves as a compile-check that the library is importable.
    @compileLog("dvui-ds storybook: build OK — needs dvui window setup for standalone run");
}
