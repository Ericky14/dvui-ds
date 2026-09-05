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
const pixels = @import("../helpers/pixels.zig");

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
    id_extra: ?usize = null,

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

    /// Disambiguate this instance when icon buttons share a `@src()` (loops/toolbars).
    pub fn idExtra(self: IconButton, val: usize) IconButton {
        var btn = self;
        btn.id_extra = val;
        return btn;
    }

    /// Square geometry so the icon button matches the DS button height for its
    /// size (sm 28 / md 32 / lg 40) — and so both the inset and what is left in
    /// the middle are whole physical pixels at the display's scale.
    ///
    /// The naive `(height - icon) / 2` is a *logical* number: at 175 % a 7 px
    /// inset is 12.25 physical px, the icon centred in the remainder lands on a
    /// half pixel, and every icon in the chrome renders a half-pixel blurry.
    /// `squareMetrics` gives an inset and a content box that both land whole
    /// and leave no remainder for `gravity` to split.
    pub fn metrics(btn_size: tokens.Size, scale: f32) pixels.Square {
        const target_height: f32 = switch (btn_size) {
            .sm => 28,
            .md => 32,
            .lg => 40,
        };
        return pixels.squareMetrics(target_height, icon_mod.iconSize(btn_size), scale);
    }

    pub fn draw(self: IconButton) bool {
        const square = metrics(self.btn_size, pixels.pixelScale());
        var btn = button_mod.button(self.src, "")
            .source(self.icon_source)
            .variant(self.btn_variant)
            .size(self.btn_size)
            .disabled(self.is_disabled)
            .loading(self.is_loading)
            .iconSize(square.content)
            .padding(dvui.Rect.all(square.inset));
        if (self.id_extra) |ie| btn = btn.idExtra(ie);
        return btn.draw();
    }
};

test {
    _ = @import("icon_button_tests.zig");
}
