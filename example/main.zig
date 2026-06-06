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
    }

    // ─── Content Area ────────────────────────────────────────────────────────
    {
        var content = ds.column(@src()).padding(ds.tokens.current.space_lg).expand(.both).draw();
        defer content.deinit();

        switch (router.active) {
            .buttons => pages.buttons.draw(),
            .icon_button => pages.icon_button.draw(),
            .input => pages.input.draw(),
            .textarea => pages.textarea.draw(),
            .labels => pages.labels.draw(),
            .panel => pages.panel.draw(),
            else => pages.placeholder.draw(),
        }
    }

    return true;
}
