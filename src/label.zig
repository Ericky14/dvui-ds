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
    label_style: LabelStyle = .primary,

    pub fn style(self: Label, val: LabelStyle) Label {
        var result = self;
        result.label_style = val;
        return result;
    }

    pub fn draw(self: Label) void {
        dvui.label(self.src, "{s}", .{self.text}, self.labelOpts());
    }

    fn labelOpts(self: Label) dvui.Options {
        const theme = tokens.current;
        return switch (self.label_style) {
            .primary => .{ .color_text = theme.text_primary },
            .secondary => .{ .color_text = theme.text_secondary },
            .muted => .{ .color_text = theme.text_muted },
            .weak => .{ .color_text = theme.text_weak },
            .title => .{ .color_text = theme.text_primary, .font = dvui.themeGet().font_title },
            .accent => .{ .color_text = theme.accent },
            .danger => .{ .color_text = theme.danger },
        };
    }
};
