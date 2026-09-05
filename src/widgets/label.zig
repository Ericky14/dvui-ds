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

/// The same text style, one rung brighter — the rule for text drawn *on glass*.
///
/// A glass surface is a tint over a blurred copy of whatever is behind it, so
/// the effective background is lighter and less predictable than an opaque
/// panel's, and the quiet end of the ladder stops being readable: `.weak` is
/// tuned to disappear against `surface_1`, and over a bright render it does
/// exactly that. Moving every style up one rung keeps the *hierarchy* — a
/// caption still reads quieter than a title — which a flat "use .secondary on
/// glass" rule throws away by collapsing two rungs into one.
///
///   ds.label(@src(), "Position").style(ds.onGlass(.muted)).draw();
///
/// `title`, `accent` and `danger` are already at full strength and unchanged.
pub fn onGlass(style: LabelStyle) LabelStyle {
    return switch (style) {
        .weak => .muted,
        .muted => .secondary,
        .secondary => .primary,
        .primary, .title, .accent, .danger => style,
    };
}

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
    grav_y: ?f32 = null,

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

    /// Set the vertical gravity (0 = top, 0.5 = center, 1 = bottom). Use 0.5 to
    /// center the text against taller siblings (e.g. buttons) in a horizontal row.
    pub fn gravityY(self: Label, val: f32) Label {
        var result = self;
        result.grav_y = val;
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
            .color_text = .{ .color = text_color },
            .font = resolved_font,
            .padding = self.do_padding,
            .expand = self.do_expand,
            .gravity_y = self.grav_y,
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

test "on glass, every style moves one rung up and the ladder keeps its order" {
    const std_testing = @import("std").testing;
    try std_testing.expectEqual(LabelStyle.muted, onGlass(.weak));
    try std_testing.expectEqual(LabelStyle.secondary, onGlass(.muted));
    try std_testing.expectEqual(LabelStyle.primary, onGlass(.secondary));
    // The top of the ladder has nowhere to go.
    try std_testing.expectEqual(LabelStyle.primary, onGlass(.primary));
    // Colour-carrying styles mean something other than "how loud"; leave them.
    try std_testing.expectEqual(LabelStyle.title, onGlass(.title));
    try std_testing.expectEqual(LabelStyle.accent, onGlass(.accent));
    try std_testing.expectEqual(LabelStyle.danger, onGlass(.danger));
    // The order survives the shift: two styles that differed still differ.
    try std_testing.expect(onGlass(.weak) != onGlass(.muted));
    try std_testing.expect(onGlass(.muted) != onGlass(.secondary));
}
