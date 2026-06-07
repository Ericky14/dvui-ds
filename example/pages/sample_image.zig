/// A small procedurally-generated RGBA gradient, used by the storybook pages to
/// demo raster-image sources (image buttons / image icons) without shipping a
/// binary asset.
const ds = @import("dvui_ds");

const w = 28;
const h = 28;
var buf: [w * h * 4]u8 = undefined;
var filled = false;

// A diagonal two-colour gradient (accent blue → violet) so it reads as an
// intentional thumbnail rather than a full-spectrum rainbow.
const from = [3]u32{ 110, 181, 255 };
const to = [3]u32{ 168, 120, 245 };

/// A `ds.Source` backed by the gradient (built once, then cached).
pub fn source() ds.Source {
    if (!filled) {
        const span = (w - 1) + (h - 1);
        var y: usize = 0;
        while (y < h) : (y += 1) {
            var x: usize = 0;
            while (x < w) : (x += 1) {
                const i = (y * w + x) * 4;
                const t = x + y; // 0..span along the diagonal
                inline for (0..3) |c| {
                    buf[i + c] = @intCast((from[c] * (span - t) + to[c] * t) / span);
                }
                buf[i + 3] = 255;
            }
        }
        filled = true;
    }
    return ds.Source.pixels(&buf, w, h);
}
