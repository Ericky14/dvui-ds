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
pub const iconButton = @import("widgets/icon_button.zig").iconButton;
pub const iconButtonSource = @import("widgets/icon_button.zig").iconButtonSource;
pub const card = @import("widgets/card.zig").card;
pub const checkbox = @import("widgets/checkbox.zig").checkbox;
pub const toggle = @import("widgets/switch.zig").toggle;
pub const slider = @import("widgets/slider.zig").slider;
pub const tabs = @import("widgets/tabs.zig").tabs;
pub const dropdown = @import("widgets/dropdown.zig").dropdown;
pub const modal = @import("widgets/modal.zig").modal;
pub const badge = @import("widgets/badge.zig").badge;
pub const tooltip = @import("widgets/tooltip.zig").tooltip;
pub const radio = @import("widgets/radio.zig").radio;
pub const scrollArea = @import("widgets/scroll_area.zig").scrollArea;
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
pub const glass = @import("widgets/glass.zig").glass;
pub const glassScene = @import("widgets/glass.zig").glassScene;
pub const windowFrame = @import("widgets/window_frame.zig").windowFrame;
pub const previewFrame = @import("widgets/preview_frame.zig").previewFrame;
pub const chip = @import("widgets/chip.zig").chip;
pub const chipSource = @import("widgets/chip.zig").chipSource;
pub const pill = @import("widgets/pill.zig").pill;
pub const spacer = @import("widgets/spacer.zig").spacer;
pub const gap = @import("widgets/spacer.zig").gap;
pub const gapH = @import("widgets/spacer.zig").gapH;
pub const icon = @import("widgets/icon.zig").icon;
pub const iconTvg = @import("widgets/icon.zig").iconTvg;
pub const textInput = @import("widgets/text_input.zig").textInput;
pub const textInputAdvanced = @import("widgets/text_input.zig").textInputAdvanced;
pub const TextInput = @import("widgets/text_input.zig").TextInput;
pub const textarea = @import("widgets/textarea.zig").textarea;
pub const textareaAdvanced = @import("widgets/textarea.zig").textareaAdvanced;
pub const TextArea = @import("widgets/textarea.zig").TextArea;
pub const IconButton = @import("widgets/icon_button.zig").IconButton;
pub const Card = @import("widgets/card.zig").Card;
pub const CardVariant = @import("widgets/card.zig").CardVariant;
pub const Checkbox = @import("widgets/checkbox.zig").Checkbox;
pub const Switch = @import("widgets/switch.zig").Switch;
pub const Slider = @import("widgets/slider.zig").Slider;
pub const Tabs = @import("widgets/tabs.zig").Tabs;
pub const Dropdown = @import("widgets/dropdown.zig").Dropdown;
pub const Modal = @import("widgets/modal.zig").Modal;
pub const Badge = @import("widgets/badge.zig").Badge;
pub const BadgeVariant = @import("widgets/badge.zig").BadgeVariant;
pub const Tooltip = @import("widgets/tooltip.zig").Tooltip;
pub const TooltipPosition = @import("widgets/tooltip.zig").Position;
pub const Radio = @import("widgets/radio.zig").Radio;
pub const ScrollArea = @import("widgets/scroll_area.zig").ScrollArea;
pub const ScrollAreaHandle = @import("widgets/scroll_area.zig").Handle;
pub const Router = @import("widgets/router.zig").Router;
pub const Glass = @import("widgets/glass.zig").Glass;
pub const GlassHandle = @import("widgets/glass.zig").Handle;
pub const GlassScene = @import("widgets/glass.zig").GlassScene;
pub const GlassSceneHandle = @import("widgets/glass.zig").Scene;
pub const WindowFrame = @import("widgets/window_frame.zig").WindowFrame;
pub const PreviewFrame = @import("widgets/preview_frame.zig").PreviewFrame;
pub const PreviewFrameHandle = @import("widgets/preview_frame.zig").Handle;
pub const PreviewEdge = @import("widgets/preview_frame.zig").Edge;
pub const Chip = @import("widgets/chip.zig").Chip;
pub const ChipState = @import("widgets/chip.zig").ChipState;
pub const Pill = @import("widgets/pill.zig").Pill;
pub const PillTone = @import("widgets/pill.zig").PillTone;

/// Measured geometry, so a caller can size a floating row without
/// re-deriving design-system internals. Both are in logical px and already
/// rounded to whole physical pixels at the scale you pass.
pub const chipMetrics = @import("widgets/chip.zig").chipMetrics;
pub const pillMetrics = @import("widgets/pill.zig").pillMetrics;
pub const Square = @import("helpers/pixels.zig").Square;

// ─── Chat widgets (ds.chat.*) ────────────────────────────────────────────────
pub const chat = @import("widgets/chat/chat.zig");

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
pub const fontMono = @import("helpers/fonts.zig").fontMono;
pub const fontMonoMedium = @import("helpers/fonts.zig").fontMonoMedium;

// ─── Color helpers ───────────────────────────────────────────────────────────

pub const cachedTvg = @import("helpers/svg.zig").cachedTvg;

/// Physical-pixel snapping — see `helpers/pixels.zig`.
pub const pixelScale = @import("helpers/pixels.zig").pixelScale;
pub const snapPx = @import("helpers/pixels.zig").snapPx;
pub const hairline = @import("helpers/pixels.zig").hairline;
pub const borderPx = @import("helpers/pixels.zig").borderPx;

/// A uniform border of `logical` px, snapped to whole physical pixels.
/// `ds.border(theme.border_width)` is what every ds widget outlines with.
pub const border = @import("helpers/padding.zig").border;
pub const isSnapped = @import("helpers/pixels.zig").isSnapped;

pub const alpha = @import("helpers/color.zig").alpha;
pub const withOpacity = @import("helpers/color.zig").withOpacity;
pub const Opacity = @import("helpers/color.zig").Opacity;

/// CSS `:focus-visible` — true only after keyboard input (auto-detected from the
/// frame's events; no backend cooperation required).
pub const focusVisible = @import("helpers/focus_visible.zig").visible;

// ─── Icons ───────────────────────────────────────────────────────────────────
pub const icons = @import("icons.zig");

// ─── Types ───────────────────────────────────────────────────────────────────
pub const Variant = @import("tokens.zig").Variant;
pub const Size = @import("tokens.zig").Size;
pub const Source = @import("source.zig");
pub const LabelStyle = @import("widgets/label.zig").LabelStyle;

/// The text style to use on a glass surface: one rung brighter than the same
/// text on an opaque panel. See `widgets/label.zig`.
pub const onGlass = @import("widgets/label.zig").onGlass;

/// The colour a `LabelStyle` resolves to, for drawing through raw dvui.
pub const labelColor = @import("widgets/label.zig").labelColor;
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

/// Borderless-window chrome: declare the drag region and caption buttons
/// each frame. See `platform/window_chrome.zig`.
pub const windowChrome = @import("platform/window_chrome.zig");
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
    _ = @import("widgets/icon_button_tests.zig");
    _ = @import("widgets/card_tests.zig");
    _ = @import("widgets/checkbox_tests.zig");
    _ = @import("widgets/switch_tests.zig");
    _ = @import("widgets/slider_tests.zig");
    _ = @import("widgets/tabs_tests.zig");
    _ = @import("widgets/dropdown_tests.zig");
    _ = @import("widgets/modal_tests.zig");
    _ = @import("widgets/badge_tests.zig");
    _ = @import("widgets/tooltip_tests.zig");
    _ = @import("widgets/radio_tests.zig");
    _ = @import("widgets/scroll_area_tests.zig");
    _ = @import("widgets/text_input_tests.zig");
    _ = @import("widgets/textarea_tests.zig");
    _ = @import("widgets/glass_tests.zig");
    _ = @import("widgets/window_frame_tests.zig");
    _ = @import("widgets/preview_frame_tests.zig");
    _ = @import("widgets/chip_tests.zig");
    _ = @import("widgets/pill_tests.zig");
    _ = @import("helpers/pixels.zig");
    _ = @import("platform/window_chrome_tests.zig");
    _ = @import("anim/anim_tests.zig");
    _ = @import("helpers/fonts.zig");
    _ = @import("widgets/chat/chat.zig");
}

const std = @import("std");
