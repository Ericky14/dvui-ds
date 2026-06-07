/// dvui-ds Storybook — visual component showcase.
///
/// Demonstrates all ds widgets with the default dark theme.
/// Run with: cd vendor/dvui-ds && zig build example
const std = @import("std");
const ds = @import("dvui_ds");
const pages = @import("pages/pages.zig");

/// Custom log handler with timestamps.
pub const std_options: std.Options = .{
    .log_level = .info,
    .logFn = ds.log.timestamped,
};

pub fn main() !void {
    ds.log.init();
    try ds.runner.run(.{
        .title = "dvui-ds Storybook",
        .width = 900,
        .height = 600,
    }, &storybookFrame);
}

const Page = enum {
    colors,
    typography,
    spacing,
    icons,
    buttons,
    icon_button,
    input,
    textarea,
    labels,
    panel,
    menu_bar,
    toolbar,
    card,
    checkbox,
    radio,
    toggle,
    slider,
    tabs,
    dropdown,
    modal,
    badge,
    tooltip,
};

var router = ds.Router(Page).init(.buttons);

fn storybookFrame() bool {
    // Main layout: sidebar + content
    var main_box = ds.row(@src()).expand(.both).draw();
    defer main_box.deinit();

    // ─── Sidebar ─────────────────────────────────────────────────────────────
    {
        var sb = router.sidebar(@src());
        defer sb.deinit();

        // Branding
        ds.label(@src(), "dvui-ds").style(.title).paddingRect(ds.paddingXY(ds.tokens.current.space_sm, 0)).draw();
        ds.label(@src(), "DESIGN SYSTEM").style(.weak).paddingRect(ds.paddingEach(ds.tokens.current.space_3xs, ds.tokens.current.space_sm, 0, ds.tokens.current.space_sm)).draw();

        router.gap(@src(), ds.tokens.current.space_2xl);

        router.section(@src(), "FOUNDATIONS");
        router.link(@src(), .colors, "Colors");
        router.link(@src(), .typography, "Typography");
        router.link(@src(), .spacing, "Spacing");
        router.link(@src(), .icons, "Icons");

        router.gap(@src(), ds.tokens.current.space_lg);

        router.section(@src(), "CORE COMPONENTS");
        router.link(@src(), .buttons, "Button");
        router.link(@src(), .icon_button, "Icon Button");
        router.link(@src(), .input, "Text Input");
        router.link(@src(), .textarea, "Text Area");
        router.link(@src(), .labels, "Label");
        router.link(@src(), .panel, "Panel");
        router.link(@src(), .menu_bar, "Menu Bar");
        router.link(@src(), .toolbar, "Toolbar");

        router.gap(@src(), ds.tokens.current.space_lg);

        router.section(@src(), "MATERIAL");
        router.link(@src(), .card, "Card");
        router.link(@src(), .checkbox, "Checkbox");
        router.link(@src(), .radio, "Radio");
        router.link(@src(), .toggle, "Switch");
        router.link(@src(), .slider, "Slider");
        router.link(@src(), .tabs, "Tabs");
        router.link(@src(), .dropdown, "Dropdown");
        router.link(@src(), .modal, "Modal");
        router.link(@src(), .badge, "Badge");
        router.link(@src(), .tooltip, "Tooltip");
    }

    // ─── Content Area ────────────────────────────────────────────────────────
    {
        var content = ds.column(@src()).padding(ds.tokens.current.space_lg).expand(.both).draw();
        defer content.deinit();

        switch (router.active) {
            .colors => pages.colors.draw(),
            .typography => pages.typography.draw(),
            .spacing => pages.spacing.draw(),
            .icons => pages.icons.draw(),
            .buttons => pages.buttons.draw(),
            .icon_button => pages.icon_button.draw(),
            .input => pages.input.draw(),
            .textarea => pages.textarea.draw(),
            .labels => pages.labels.draw(),
            .panel => pages.panel.draw(),
            .menu_bar => pages.menu_bar.draw(),
            .toolbar => pages.toolbar.draw(),
            .card => pages.card.draw(),
            .checkbox => pages.checkbox.draw(),
            .radio => pages.radio.draw(),
            .toggle => pages.switch_page.draw(),
            .slider => pages.slider.draw(),
            .tabs => pages.tabs.draw(),
            .dropdown => pages.dropdown.draw(),
            .modal => pages.modal.draw(),
            .badge => pages.badge.draw(),
            .tooltip => pages.tooltip.draw(),
        }
    }

    return true;
}
