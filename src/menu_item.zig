/// Menu Item — wraps dvui.menuItemLabel() with themed defaults.
///
/// Usage:
///   if (ds.menuItem(@src(), "File").submenu().draw()) |r| {
///       var fw = ds.floatingMenu(@src(), r);
///       defer fw.deinit();
///       if (ds.menuItem(@src(), "New").draw() != null) fw.close();
///   }
const std = @import("std");
const dvui = @import("dvui");
const tokens = @import("tokens.zig");

pub fn menuItem(src: std.builtin.SourceLocation, label_str: []const u8) MenuItem {
    return .{ .src = src, .label_str = label_str };
}

pub fn floatingMenu(src: std.builtin.SourceLocation, from: dvui.Rect.Natural) *dvui.FloatingMenuWidget {
    return dvui.floatingMenu(src, .{ .from = from }, floatingOpts());
}

pub const MenuItem = struct {
    src: std.builtin.SourceLocation,
    label_str: []const u8,
    is_submenu: bool = false,

    pub fn submenu(self: MenuItem) MenuItem {
        var m = self;
        m.is_submenu = true;
        return m;
    }

    pub fn draw(self: MenuItem) ?dvui.Rect.Natural {
        const base = itemOpts();
        return dvui.menuItemLabel(
            self.src,
            self.label_str,
            .{ .submenu = self.is_submenu },
            if (self.is_submenu) base else base.override(.{ .expand = .horizontal }),
        );
    }
};

fn itemOpts() dvui.Options {
    const t = tokens.current;
    return .{
        .color_text = t.text_secondary,
        .corner_radius = dvui.Rect.all(t.radius_sm),
        .padding = .{ .x = t.space_xs, .y = t.space_xs, .w = t.space_xs, .h = t.space_xs },
    };
}

fn floatingOpts() dvui.Options {
    const t = tokens.current;
    return .{
        .color_fill = t.bg_elevated,
        .color_border = t.border_normal,
        .corner_radius = dvui.Rect.all(t.radius_lg),
    };
}
