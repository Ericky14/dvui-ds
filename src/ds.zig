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

// ─── Widgets ─────────────────────────────────────────────────────────────────
pub const button = @import("widgets/button.zig").button;
pub const row = @import("widgets/row.zig").row;
pub const column = @import("widgets/column.zig").column;
pub const loader = @import("widgets/loader.zig").loader;
pub const menuBar = @import("widgets/menu_bar.zig").menuBar;
pub const menuItem = @import("widgets/menu_item.zig").menuItem;
pub const floatingMenu = @import("widgets/menu_item.zig").floatingMenu;
pub const panel = @import("widgets/panel.zig").panel;
pub const panelHeader = @import("widgets/panel.zig").panelHeader;
pub const label = @import("widgets/label.zig").label;
pub const toolbar = @import("widgets/toolbar.zig").toolbar;
pub const spacer = @import("widgets/spacer.zig").gap;
pub const gap = @import("widgets/spacer.zig").gap;
pub const gapH = @import("widgets/spacer.zig").gapH;
pub const icon = @import("widgets/icon.zig").icon;
pub const iconTvg = @import("widgets/icon.zig").iconTvg;
pub const textInput = @import("widgets/text_input.zig").textInput;
pub const textInputAdvanced = @import("widgets/text_input.zig").textInputAdvanced;
pub const TextInput = @import("widgets/text_input.zig").TextInput;
pub const Router = @import("widgets/router.zig").Router;

// ─── Layout helpers ──────────────────────────────────────────────────────────
const dvui = @import("dvui");

pub const padding = @import("helpers/padding.zig").padding;
pub const paddingXY = @import("helpers/padding.zig").paddingXY;
pub const paddingEach = @import("helpers/padding.zig").paddingEach;

pub const font = @import("helpers/fonts.zig").font;
pub const fontLight = @import("helpers/fonts.zig").fontLight;
pub const fontMedium = @import("helpers/fonts.zig").fontMedium;
pub const fontSemibold = @import("helpers/fonts.zig").fontSemibold;
pub const fontBold = @import("helpers/fonts.zig").fontBold;

// ─── Color helpers ───────────────────────────────────────────────────────────

pub const cachedTvg = @import("helpers/svg.zig").cachedTvg;

pub const alpha = @import("helpers/color.zig").alpha;
pub const withOpacity = @import("helpers/color.zig").withOpacity;
pub const Opacity = @import("helpers/color.zig").Opacity;

// ─── Icons ───────────────────────────────────────────────────────────────────
pub const icons = @import("icons.zig");

// ─── Types ───────────────────────────────────────────────────────────────────
pub const Variant = @import("tokens.zig").Variant;
pub const Size = @import("tokens.zig").Size;
pub const Source = @import("source.zig");
pub const LabelStyle = @import("widgets/label.zig").LabelStyle;
pub const FontToken = @import("widgets/label.zig").FontToken;
pub const IconStyle = @import("widgets/icon.zig").IconStyle;
pub const Theme = @import("tokens.zig").Theme;
pub const tokens = @import("tokens.zig");
pub const motion = @import("motion.zig");
pub const anim = @import("anim/anim.zig");

// ─── Platform ────────────────────────────────────────────────────────────────
pub const runner = @import("platform/runner.zig");
pub const App = @import("platform/app.zig").App;
pub const GpuContext = @import("platform/gpu.zig").GpuContext;
pub const focus = @import("ds_focus");
pub const log = @import("log.zig");

/// Initialize the design system with your app's theme tokens.
/// Must be called before any widget draws.
pub fn init(theme: Theme) void {
    tokens.current = theme;
}

test {
    std.testing.refAllDecls(@This());
    _ = @import("widgets/button_tests.zig");
    _ = @import("widgets/text_input_tests.zig");
    _ = @import("anim/anim_tests.zig");
}

const std = @import("std");
