/// dvui-ds — Design system widget library for dvui.
///
/// Provides themed, chainable widget builders that eliminate hard-coded
/// dvui.Options throughout application code.
///
/// Setup:
///   1. Call `ds.init(your_theme)` before the dvui frame loop.
///   2. Use builders: `ds.button(@src(), "Save").variant(.filled).draw()`
///
/// The theme is a comptime-known struct of color/spacing tokens. Set it once
/// at app startup; widgets read it automatically.
pub const button = @import("button.zig").button;
pub const menuBar = @import("menu_bar.zig").menuBar;
pub const menuItem = @import("menu_item.zig").menuItem;
pub const floatingMenu = @import("menu_item.zig").floatingMenu;
pub const panel = @import("panel.zig").panel;
pub const panelHeader = @import("panel.zig").panelHeader;
pub const label = @import("label.zig").label;
pub const toolbar = @import("toolbar.zig").toolbar;
pub const spacer = @import("spacer.zig").spacer;
pub const icon = @import("icon.zig").icon;

pub const Variant = @import("tokens.zig").Variant;
pub const Size = @import("tokens.zig").Size;
pub const LabelStyle = @import("label.zig").LabelStyle;
pub const IconStyle = @import("icon.zig").IconStyle;
pub const Theme = @import("tokens.zig").Theme;
pub const tokens = @import("tokens.zig");

/// Initialize the design system with your app's theme tokens.
/// Must be called before any widget draws.
pub fn init(theme: Theme) void {
    tokens.current = theme;
}
