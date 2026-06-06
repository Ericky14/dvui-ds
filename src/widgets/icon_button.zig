/// IconButton — square, icon-only button for dvui-ds.
///
/// A thin builder over `button` with an empty label, so it reuses all of the
/// button's rendering (variants, sizes, states, hover animation) but is padded
/// to a square that matches the DS button heights (sm 28, md 32, lg 40).
///
/// Usage:
///   if (ds.iconButton(@src(), "settings", ds.icons.cog).draw()) { ... }
///   if (ds.iconButton(@src(), "delete", ds.icons.delete).variant(.danger).size(.md).draw()) { ... }
///   _ = ds.iconButton(@src(), "copy", ds.icons.copy).disabled(true).draw();
///   _ = ds.iconButton(@src(), "save", ds.icons.save).loading(true).draw();
const std = @import("std");
const dvui = @import("dvui");
const tokens = @import("../tokens.zig");
const button_mod = @import("button.zig");
const icon_mod = @import("icon.zig");

pub const Source = button_mod.Source;

/// Create an icon button from a named ds icon (SVG bytes resolved to TVG at
/// draw time, cached automatically).
pub fn iconButton(src: std.builtin.SourceLocation, comptime name: [:0]const u8, svg_bytes: []const u8) IconButton {
    return .{ .src = src, .icon_source = Source.namedIcon(name, svg_bytes) };
}

/// Create an icon button from any visual Source (pre-made TVG, raster image, …).
pub fn iconButtonSource(src: std.builtin.SourceLocation, asset: Source) IconButton {
    return .{ .src = src, .icon_source = asset };
}

pub const IconButton = struct {
    src: std.builtin.SourceLocation,
    icon_source: Source,
    btn_variant: tokens.Variant = .ghost,
    btn_size: tokens.Size = .sm,
    is_disabled: bool = false,
    is_loading: bool = false,

    pub fn variant(self: IconButton, val: tokens.Variant) IconButton {
        var btn = self;
        btn.btn_variant = val;
        return btn;
    }

    pub fn size(self: IconButton, val: tokens.Size) IconButton {
        var btn = self;
        btn.btn_size = val;
        return btn;
    }

    /// Mark as disabled (reduced opacity, no interaction).
    pub fn disabled(self: IconButton, val: bool) IconButton {
        var btn = self;
        btn.is_disabled = val;
        return btn;
    }

    /// Mark as loading (shows spinner, no interaction).
    pub fn loading(self: IconButton, val: bool) IconButton {
        var btn = self;
        btn.is_loading = val;
        return btn;
    }

    /// Square padding so the icon button matches the DS button height for its
    /// size: width = icon + 2·pad = height.
    fn squarePadding(btn_size: tokens.Size) f32 {
        const target_height: f32 = switch (btn_size) {
            .sm => 28,
            .md => 32,
            .lg => 40,
        };
        return (target_height - icon_mod.iconSize(btn_size)) / 2;
    }

    pub fn draw(self: IconButton) bool {
        const pad = squarePadding(self.btn_size);
        return button_mod.button(self.src, "")
            .source(self.icon_source)
            .variant(self.btn_variant)
            .size(self.btn_size)
            .disabled(self.is_disabled)
            .loading(self.is_loading)
            .padding(dvui.Rect.all(pad))
            .draw();
    }
};

test {
    _ = @import("icon_button_tests.zig");
}
