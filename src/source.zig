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
    /// Raster image from in-memory bytes (png, jpg, gif, etc.)
    image: dvui.ImageSource,
};

pub const Tvg = struct {
    name: [:0]const u8,
    bytes: []const u8,
};

kind: Kind,

/// Create a vector icon source from TVG bytes.
pub fn tvg(name: [:0]const u8, bytes: []const u8) Source {
    return .{ .kind = .{ .tvg = .{ .name = name, .bytes = bytes } } };
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
