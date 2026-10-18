//! **A picture at its own size**: one image pixel to one physical pixel.
//!
//! `dvui.image` takes an image's pixel size as a size in LOGICAL pixels, so at
//! the owner's 175 % a 640-pixel screenshot covers 1,120 physical pixels — every
//! picture the chat showed was blown up and soft. A picture's natural size is
//! therefore its pixel size divided by the scale it is drawn at; a widget that
//! shows a raster image asks here first and then fits the answer into the room
//! it has, never past it (`fitWidth`: smaller only, never larger).
//!
//! This is the one place the rule lives — the chat's screenshot card, the
//! Markdown image, the engine's document sheet and the editor's thumbnails all
//! size a picture through it.
//!
//! Usage:
//!   const natural = ds.imageNaturalSize(source) catch fallback;
//!   const shown = ds.imageFitWidth(natural, room.w);
//!   _ = dvui.image(@src(), .{ .source = source }, .{ .min_size_content = shown });
const std = @import("std");
const dvui = @import("dvui");
const pixels = @import("pixels.zig");

/// The logical size at which an image of `pixel_size` covers exactly that many
/// physical pixels when one logical pixel is `scale` physical pixels. A scale of
/// zero or less (no window) leaves the size as it is.
///
/// `atScale(.{ .w = 350, .h = 175 }, 1.75)` → 200 × 100.
pub fn atScale(pixel_size: dvui.Size, scale: f32) dvui.Size {
    if (scale <= 0) return pixel_size;
    return .{ .w = pixel_size.w / scale, .h = pixel_size.h / scale };
}

/// The logical size at which `source` shows one image pixel per physical pixel
/// where it is drawn now: its pixel size over `ds.pixelScale()` — the window's
/// natural scale (`dvui.windowNaturalScale()`) times the interface size and any
/// enclosing scale, so a picture is never upscaled whatever the person zooms
/// the interface to. Fails as `dvui.imageSize` fails (bytes it cannot read).
pub fn naturalSize(source: dvui.ImageSource) !dvui.Size {
    return atScale(try dvui.imageSize(source), pixels.pixelScale());
}

/// `natural` narrowed to `max_width` keeping its aspect ratio; a picture already
/// narrower keeps its size — never upscaled. Degenerate sizes pass through.
///
/// `fitWidth(.{ .w = 1280, .h = 720 }, 320)` → 320 × 180.
pub fn fitWidth(natural: dvui.Size, max_width: f32) dvui.Size {
    if (natural.w <= 0 or natural.h <= 0 or max_width <= 0) return natural;
    if (natural.w <= max_width) return natural;
    const ratio = max_width / natural.w;
    return .{ .w = max_width, .h = natural.h * ratio };
}

/// `natural` fitted inside `room` (both sides) keeping its aspect ratio, never
/// upscaled: what a viewer that has a whole panel to fill shows.
///
/// `fitInside(.{ .w = 800, .h = 800 }, .{ .w = 400, .h = 200 })` → 200 × 200.
pub fn fitInside(natural: dvui.Size, room: dvui.Size) dvui.Size {
    if (natural.w <= 0 or natural.h <= 0) return natural;
    var ratio: f32 = 1;
    if (room.w > 0) ratio = @min(ratio, room.w / natural.w);
    if (room.h > 0) ratio = @min(ratio, room.h / natural.h);
    return .{ .w = natural.w * ratio, .h = natural.h * ratio };
}

test {
    _ = @import("image_size_tests.zig");
}
