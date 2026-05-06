/// Label — themed text labels with builder pattern.
///
/// Usage:
///   ds.label(@src(), "Hello").draw();
///   ds.label(@src(), "Muted").style(.muted).draw();
///   ds.label(@src(), "Title").style(.title).padding(theme.space_md).draw();
///   ds.label(@src(), "Custom").color(theme.accent).font(.heading).draw();
const std = @import("std");
const dvui = @import("dvui");
const tokens = @import("../tokens.zig");

pub const LabelStyle = enum {
    primary,
    secondary,
    muted,
    weak,
    title,
    accent,
    danger,
};

pub const FontToken = enum {
    body,
    heading,
    title,
    mono,
};

pub fn label(src: std.builtin.SourceLocation, text: []const u8) Label {
    return .{ .src = src, .text = text };
}

pub const Label = struct {
    src: std.builtin.SourceLocation,
    text: []const u8,
    label_style: LabelStyle = .primary,
    override_color: ?dvui.Color = null,
    override_font: ?FontToken = null,
    do_padding: ?dvui.Rect = null,
    do_expand: ?dvui.Options.Expand = null,

    /// Set a predefined style (primary, secondary, muted, title, etc.).
    pub fn style(self: Label, val: LabelStyle) Label {
        var result = self;
        result.label_style = val;
        return result;
    }

    /// Override text color directly.
    pub fn color(self: Label, val: dvui.Color) Label {
        var result = self;
        result.override_color = val;
        return result;
    }

    /// Set font from a token name.
    pub fn font(self: Label, val: FontToken) Label {
        var result = self;
        result.override_font = val;
        return result;
    }

    /// Set uniform padding in pixels.
    /// Pass a token value: `label.padding(theme.space_md)`
    pub fn padding(self: Label, px: f32) Label {
        var result = self;
        result.do_padding = dvui.Rect.all(px);
        return result;
    }

    /// Set custom padding rect.
    /// Use ds helpers: `label.paddingRect(ds.paddingXY(16, 8))`
    pub fn paddingRect(self: Label, val: dvui.Rect) Label {
        var result = self;
        result.do_padding = val;
        return result;
    }

    /// Expand to fill available space.
    pub fn expand(self: Label, val: dvui.Options.Expand) Label {
        var result = self;
        result.do_expand = val;
        return result;
    }

    /// Materialize the label.
    pub fn draw(self: Label) void {
        dvui.label(self.src, "{s}", .{self.text}, self.labelOpts());
    }

    fn labelOpts(self: Label) dvui.Options {
        const theme = tokens.current;
        const dvui_theme = dvui.themeGet();

        // Resolve color: override > style preset
        const text_color = self.override_color orelse switch (self.label_style) {
            .primary => theme.text_primary,
            .secondary => theme.text_secondary,
            .muted => theme.text_muted,
            .weak => theme.text_ghost,
            .title => theme.text_primary,
            .accent => theme.accent,
            .danger => theme.destructive,
        };

        // Resolve font: override > style preset > null (dvui default)
        const resolved_font: ?dvui.Font = if (self.override_font) |f| resolveFontToken(f, dvui_theme) else switch (self.label_style) {
            .title => dvui_theme.font_title,
            else => null,
        };

        return .{
            .color_text = text_color,
            .font = resolved_font,
            .padding = self.do_padding,
            .expand = self.do_expand,
        };
    }
};

fn resolveFontToken(tok: FontToken, dvui_theme: dvui.Theme) ?dvui.Font {
    return switch (tok) {
        .body => dvui_theme.font_body,
        .heading => dvui_theme.font_heading,
        .title => dvui_theme.font_title,
        .mono => dvui_theme.font_mono,
    };
}
