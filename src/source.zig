/// Source — unified asset reference for icons and images.
///
/// Abstracts over vector icons (TVG), raster image bytes, and file paths.
/// Used by button, icon, and any future widget that displays visual assets.
///
/// Usage:
///   const save_icon = Source.tvg("save", @embedFile("save.tvg"));
///   const logo = Source.imageBytes(@embedFile("logo.png"));
///   const avatar = Source.filePath("/path/to/avatar.png");
const dvui = @import("dvui");

const Source = @This();

pub const Kind = union(enum) {
    /// TigerVG vector icon (embedded bytes)
    tvg: Tvg,
    /// Named icon from the ds icon set (SVG bytes, resolved to TVG at draw time)
    named_icon: NamedIcon,
    /// Raster image from in-memory bytes (png, jpg, gif, etc.)
    image: dvui.ImageSource,
};

pub const Tvg = struct {
    name: [:0]const u8,
    bytes: []const u8,
};

pub const NamedIcon = struct {
    name: [:0]const u8,
    svg_bytes: []const u8,
};

kind: Kind,

/// Create a vector icon source from TVG bytes.
pub fn tvg(name: [:0]const u8, bytes: []const u8) Source {
    return .{ .kind = .{ .tvg = .{ .name = name, .bytes = bytes } } };
}

/// Create a named icon source from the ds icon set. SVG→TVG conversion
/// happens at draw time and is cached automatically.
///
/// Usage:
///   ds.Source.namedIcon("save", ds.icons.save)
pub fn namedIcon(comptime name: [:0]const u8, svg_bytes: []const u8) Source {
    return .{ .kind = .{ .named_icon = .{ .name = name, .svg_bytes = svg_bytes } } };
}

/// Resolve a named icon to TVG at draw time. Returns a Tvg source or null
/// if conversion fails. Uses dvui's data cache keyed by the SVG pointer.
pub fn resolveToTvg(self: Source) ?Tvg {
    return switch (self.kind) {
        .tvg => |t| t,
        .named_icon => |ni| {
            if (!dvui.useTvg) return null;
            const id = dvui.Id.extendId(null, @src(), @as(usize, @intFromPtr(ni.svg_bytes.ptr)));
            if (dvui.dataGetSlice(null, id, "_tvg", []u8)) |cached| {
                return .{ .name = ni.name, .bytes = cached };
            }
            const cw = dvui.currentWindow();
            const tvg_bytes = dvui.svgToTvg(cw.arena(), ni.svg_bytes) catch return null;
            defer cw.arena().free(tvg_bytes);
            dvui.dataSetSlice(null, id, "_tvg", tvg_bytes);
            return if (dvui.dataGetSlice(null, id, "_tvg", []u8)) |stored|
                .{ .name = ni.name, .bytes = stored }
            else
                null;
        },
        .image => null,
    };
}

/// Create a raster image source from in-memory file bytes (png, jpg, gif, etc).
pub fn imageBytes(bytes: []const u8) Source {
    return .{ .kind = .{ .image = .{ .imageFile = .{ .bytes = bytes } } } };
}

/// Create a raster image source from in-memory file bytes with a debug name.
pub fn imageBytesNamed(name: []const u8, bytes: []const u8) Source {
    return .{ .kind = .{ .image = .{ .imageFile = .{ .bytes = bytes, .name = name } } } };
}

/// Create a raster image source from raw RGBA pixel data.
pub fn pixels(rgba: []const u8, width: u32, height: u32) Source {
    return .{ .kind = .{ .image = .{ .pixels = .{ .rgba = rgba, .width = width, .height = height } } } };
}

/// Create a raster image source from a pre-existing dvui texture.
pub fn texture(tex: dvui.Texture) Source {
    return .{ .kind = .{ .image = .{ .texture = tex } } };
}

/// Check if this source is a vector icon.
pub fn isTvg(self: Source) bool {
    return self.kind == .tvg;
}

/// Check if this source is a raster image.
pub fn isImage(self: Source) bool {
    return self.kind == .image;
}
