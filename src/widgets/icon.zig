/// Icon — themed icon/image display (non-interactive).
///
/// Usage:
///   ds.icon(@src(), Source.tvg("outliner", icons.outliner)).draw();
///   ds.icon(@src(), Source.tvg("camera", icons.camera)).style(.accent).size(.md).draw();
///   ds.icon(@src(), Source.imageBytes(logo_png)).size(.lg).draw();
///
/// Legacy convenience (TVG shorthand):
///   ds.iconTvg(@src(), "outliner", icons.outliner).draw();
const std = @import("std");
const dvui = @import("dvui");
const tokens = @import("../tokens.zig");
pub const Source = @import("../source.zig");

pub const IconStyle = enum { primary, secondary, muted, accent, danger };

/// Create an icon from a Source (TVG, raster image, etc.)
pub fn icon(src: std.builtin.SourceLocation, asset: Source) Icon {
    return .{ .src = src, .asset = asset };
}

/// Convenience: create a TVG icon directly from name + bytes.
pub fn iconTvg(src: std.builtin.SourceLocation, name: [:0]const u8, tvg_bytes: []const u8) Icon {
    return .{ .src = src, .asset = Source.tvg(name, tvg_bytes) };
}

pub fn iconSize(sz: tokens.Size) f32 {
    const theme = tokens.current;
    return switch (sz) {
        .sm => theme.icon_sm,
        .md => theme.icon_md,
        .lg => theme.icon_lg,
    };
}

pub const Icon = struct {
    src: std.builtin.SourceLocation,
    asset: Source,
    icon_style: IconStyle = .muted,
    icon_size: tokens.Size = .sm,

    pub fn style(self: Icon, val: IconStyle) Icon {
        var result = self;
        result.icon_style = val;
        return result;
    }

    pub fn size(self: Icon, val: tokens.Size) Icon {
        var result = self;
        result.icon_size = val;
        return result;
    }

    pub fn draw(self: Icon) void {
        const theme = tokens.current;
        const color = switch (self.icon_style) {
            .primary => theme.text_primary,
            .secondary => theme.text_secondary,
            .muted => theme.text_muted,
            .accent => theme.accent,
            .danger => theme.destructive,
        };
        const sz = iconSize(self.icon_size);

        switch (self.asset.kind) {
            .tvg => |tvg| {
                dvui.icon(self.src, tvg.name, tvg.bytes, .{
                    .fill_color = color,
                    .stroke_color = color,
                }, .{
                    .min_size_content = .{ .w = sz, .h = sz },
                });
            },
            .image => |image_source| {
                _ = dvui.image(self.src, .{ .source = image_source }, .{
                    .min_size_content = .{ .w = sz, .h = sz },
                });
            },
        }
    }
};
