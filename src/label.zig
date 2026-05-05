/// Label — themed text labels.
///
/// Usage:
///   ds.label(@src(), "Hello").draw();
///   ds.label(@src(), "Muted").style(.muted).draw();
const std = @import("std");
const dvui = @import("dvui");
const tokens = @import("tokens.zig");

pub const LabelStyle = enum {
    primary,
    secondary,
    muted,
    weak,
    title,
    accent,
    danger,
};

pub fn label(src: std.builtin.SourceLocation, text: []const u8) Label {
    return .{ .src = src, .text = text };
}

pub const Label = struct {
    src: std.builtin.SourceLocation,
    text: []const u8,
    s: LabelStyle = .primary,

    pub fn style(self: Label, s: LabelStyle) Label {
        var l = self;
        l.s = s;
        return l;
    }

    pub fn draw(self: Label) void {
        dvui.label(self.src, "{s}", .{self.text}, self.opts());
    }

    fn opts(self: Label) dvui.Options {
        const t = tokens.current;
        return switch (self.s) {
            .primary => .{ .color_text = t.text_primary },
            .secondary => .{ .color_text = t.text_secondary },
            .muted => .{ .color_text = t.text_muted },
            .weak => .{ .color_text = t.text_weak },
            .title => .{ .color_text = t.text_primary, .font = dvui.themeGet().font_title },
            .accent => .{ .color_text = t.accent },
            .danger => .{ .color_text = t.danger },
        };
    }
};
