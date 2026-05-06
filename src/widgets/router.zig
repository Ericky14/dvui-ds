/// Router — generic sidebar navigation with route-based page switching.
///
/// Usage:
///   const Page = enum { buttons, labels, panel };
///   var router = ds.Router(Page).init(.buttons);
///
///   // In your frame function:
///   {
///       var sb = router.sidebar(@src());
///       defer sb.deinit();
///       router.section(@src(), "COMPONENTS");
///       router.link(@src(), .buttons, "Buttons");
///       router.link(@src(), .labels, "Labels");
///       router.link(@src(), .panel, "Panel");
///   }
///
///   // Content area — switch on the active route:
///   switch (router.active) {
///       .buttons => renderButtons(),
///       .labels => renderLabels(),
///       .panel => renderPanel(),
///   }
const std = @import("std");
const dvui = @import("dvui");
const ds = @import("../ds.zig");
const tokens = @import("../tokens.zig");
const focus = @import("ds_focus");
const btn = @import("button.zig");

/// A sidebar router parameterized on a Route enum.
pub fn Router(comptime Route: type) type {
    return struct {
        const Self = @This();

        active: Route,

        pub fn init(initial: Route) Self {
            return .{ .active = initial };
        }

        /// Begin a sidebar container. Call deinit() when done adding links.
        pub fn sidebar(self: *Self, src: std.builtin.SourceLocation) Sidebar {
            _ = self;
            const theme = tokens.current;
            const sb = dvui.box(src, .{}, .{
                .min_size_content = .{ .w = theme.sidebar_min_width, .h = 0 },
                .background = true,
                .color_fill = theme.surface_1,
                .border = ds.paddingEach(0, theme.border_width, 0, 0),
                .color_border = theme.border_subtle,
                .padding = ds.paddingXY(theme.sidebar_padding_x, theme.sidebar_padding_y),
                .expand = .vertical,
            });
            return .{ .box = sb };
        }

        /// Render a non-clickable section heading in the sidebar.
        pub fn section(_: *Self, src: std.builtin.SourceLocation, title: []const u8) void {
            const theme = tokens.current;
            dvui.label(src, "{s}", .{title}, .{
                .color_text = theme.text_ghost,
                .padding = ds.paddingEach(theme.space_2xs, theme.space_sm, theme.space_sm, theme.space_sm),
            });
        }

        /// Render a clickable navigation link. Highlights if active.
        pub fn link(self: *Self, src: std.builtin.SourceLocation, route: Route, label_text: []const u8) void {
            const theme = tokens.current;
            const is_active = self.active == route;

            const text_color = if (is_active) theme.accent else theme.text_muted;
            const fill_color: dvui.Color = if (is_active) theme.surface_2 else dvui.Color.transparent;
            const fill_hover = if (is_active) theme.surface_2 else theme.surface_4;
            const fill_press = if (is_active) theme.surface_2 else theme.surface_3;

            if (btn.button(src, label_text)
                .textColor(text_color)
                .fillColor(fill_color)
                .fillHover(fill_hover)
                .fillPress(fill_press)
                .gravityX(0)
                .expand(.horizontal)
                .padding(ds.paddingXY(theme.space_sm, theme.space_xs))
                .draw())
            {
                self.active = route;
            }
        }

        /// Add vertical spacing in the sidebar.
        pub fn gap(_: *Self, src: std.builtin.SourceLocation, height: f32) void {
            _ = dvui.spacer(src, .{ .min_size_content = .{ .w = 0, .h = height } });
        }

        pub const Sidebar = struct {
            box: *dvui.BoxWidget,
            pub fn deinit(self: *Sidebar) void {
                self.box.deinit();
            }
        };
    };
}
