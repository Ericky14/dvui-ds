/// Physical-pixel snapping — the arithmetic behind the design system's
/// alignment discipline.
///
/// Every ds length is authored in *logical* pixels and multiplied by the
/// window scale before it reaches the rasteriser. At 1.0 and 2.0 that lands on
/// whole physical pixels by accident; at 1.75 (the owner's display) it does
/// not, and a 1 px hairline becomes a 1.75 px smear that antialiases to grey on
/// one edge and to nothing on the other. Chrome — window borders, frame
/// hairlines, the glass edge highlight — is exactly the thing that shows it.
///
/// So chrome asks for a length that is guaranteed to come out whole:
///
/// ```zig
/// const scale = ds.pixelScale();
/// var frame = ds.windowFrame(@src()).draw(); // uses ds.hairline(scale) internally
/// const gutter = ds.snapPx(theme.space_sm, scale); // 8 logical px, whole physical
/// ```
const std = @import("std");
const dvui = @import("dvui");

/// The scale that turns logical pixels into physical pixels for whatever is
/// being drawn right now (window scale × any enclosing `dvui.ScaleWidget`).
///
/// Returns 1 outside a frame, so a widget's `opts()` resolver stays callable
/// from a plain unit test — the tests that check "what options does this
/// variant produce" run with no window at all, and a token helper has no
/// business crashing them.
pub fn pixelScale() f32 {
    if (dvui.current_window == null) return 1;
    return dvui.parentGet().screenRectScale(dvui.Rect{}).s;
}

/// Round a logical length so it lands on a whole number of physical pixels.
/// Zero stays zero — a gap the designer asked to remove must not become 1 px.
///
/// `ds.snapPx(6, 1.75)` → 6.2857…, i.e. exactly 11 physical pixels.
pub fn snapPx(logical: f32, scale: f32) f32 {
    if (scale <= 0) return logical;
    const physical = @round(logical * scale);
    return physical / scale;
}

/// The logical length of a **1 physical pixel minimum** hairline at `scale`:
/// the thinnest line the display can draw without antialiasing it into a
/// gradient. Used for every border in the chrome language.
///
/// `ds.hairline(1.0)` → 1 (1 px) · `ds.hairline(1.75)` → 1.142… (2 px) ·
/// `ds.hairline(2.0)` → 1 (2 px)
pub fn hairline(scale: f32) f32 {
    if (scale <= 0) return 1;
    return @max(1, @round(scale)) / scale;
}

/// A border of `logical` px, rounded to whole physical pixels and never thinner
/// than one — the value every `Options.border` in the design system is built
/// from.
///
/// A border is not just a line: it is an inset, so an unrounded one puts the
/// widget's *content* — and everything laid out inside it — on a half pixel.
/// A 1 px card border at 175 % is 1.75 physical px, and that single unrounded
/// value was what pushed every button in a chat card's action row off the pixel
/// grid.
pub fn borderPx(logical: f32, scale: f32) f32 {
    if (logical <= 0) return 0;
    return @max(hairline(scale), snapPx(logical, scale));
}

test "a border is whole physical pixels and never disappears" {
    for ([_]f32{ 1.0, 1.25, 1.5, 1.75, 2.0 }) |scale| {
        for ([_]f32{ 1, 2, 3 }) |logical| {
            const width = borderPx(logical, scale);
            try std.testing.expect(isSnapped(width, scale));
            try std.testing.expect(width * scale >= 1);
        }
        try std.testing.expectEqual(@as(f32, 0), borderPx(0, scale));
    }
}

/// The logical length of a line that is **exactly one physical pixel** at
/// `scale` — never rounded up.
///
/// The difference from `hairline` is weight, and it matters for anything
/// *decorative*. `hairline` rounds up so a structural edge — a window's rings, a
/// picture's frame — never disappears, which makes it 2 physical px at 1.75.
/// Over a dark scene a 2 px white line at 8 % is twice the ink of a 1 px one,
/// and a glass panel's edge stops reading as a hint and starts reading as a
/// ring. Decoration takes the thin one; structure takes `hairline`.
pub fn thinLine(scale: f32) f32 {
    if (scale <= 0) return 1;
    return 1 / scale;
}

test "a thin line is one physical pixel at every scale, a hairline is at least one" {
    for ([_]f32{ 1.0, 1.25, 1.5, 1.75, 2.0, 3.0 }) |scale| {
        try std.testing.expectApproxEqAbs(@as(f32, 1), thinLine(scale) * scale, 0.0001);
        // …and it is never thicker than the structural one, which is the whole
        // reason to have both.
        try std.testing.expect(thinLine(scale) <= hairline(scale) + 0.0001);
    }
    // At a whole scale they agree; at 1.75 they do not, which is the case that
    // made the difference visible.
    try std.testing.expectApproxEqAbs(hairline(1.0), thinLine(1.0), 0.0001);
    try std.testing.expect(hairline(1.75) > thinLine(1.75));
}

/// Options that round a container's height to whole physical pixels, using the
/// height it had last frame.
///
/// The one fraction a widget cannot snap by arithmetic is the one it *measures*:
/// a block of text is n × a font's line box, the line box is fractional, and
/// everything laid out under it then starts on a fraction — which is what a
/// chat card's action row inherited, and no amount of snapping the row could
/// move. dvui already remembers what a widget measured last frame, so the block
/// can round *itself*: read that, snap it, and pin the height to it.
///
/// Rounding to nearest can clip by up to half a physical pixel — sub-pixel, so
/// nothing visible — and content that grows is one frame late before the pin
/// catches up. Height only, never width, so it can never change how text wraps
/// and therefore can never oscillate.
///
/// ⚠ The `src` here must be the **same** `@src()` the box is created with, or
/// the id will not be the box's and the pin silently does nothing. Prefer
/// `ds.snapHeightBox`, which cannot be called wrong; reach for the options
/// directly only when the box needs its own init options too (a direction, a
/// gap), and then pass one `src` to both.
///
///   var block = ds.snapHeightBox(@src(), 0);
///   defer block.deinit();
pub fn snapHeightOpts(src: std.builtin.SourceLocation, id_extra: usize) dvui.Options {
    var options: dvui.Options = .{
        .id_extra = id_extra,
        .expand = .horizontal,
        .padding = dvui.Rect.all(0),
        .margin = dvui.Rect.all(0),
        .border = dvui.Rect.all(0),
    };
    if (dvui.current_window == null) return options;
    const id = dvui.parentGet().extendId(src, id_extra);
    const measured = dvui.minSizeGet(id) orelse return options;
    const snapped = snapPx(measured.h, pixelScale());
    if (!(snapped > 0)) return options;
    options.min_size_content = .{ .w = 0, .h = snapped };
    options.max_size_content = .height(snapped);
    return options;
}

/// A container that rounds its own height to whole physical pixels. Wrap a
/// block of text in it so what follows starts on a pixel. See
/// `snapHeightOpts` for why, and `deinit()` the result.
pub fn snapHeightBox(src: std.builtin.SourceLocation, id_extra: usize) *dvui.BoxWidget {
    return dvui.box(src, .{}, snapHeightOpts(src, id_extra));
}

/// True when `logical` × `scale` is a whole number of physical pixels (within
/// float tolerance). The assertion the alignment tests make.
pub fn isSnapped(logical: f32, scale: f32) bool {
    const physical = logical * scale;
    return @abs(physical - @round(physical)) < 0.001;
}

/// Geometry for a square control (an icon button, a chip): an outer size and an
/// inset that are each a whole number of physical pixels, with the content
/// filling exactly what is left.
///
/// The reason it is one helper and not two `snapPx` calls: snapping the outer
/// size and the icon size independently leaves a remainder, and a remainder
/// split by `gravity 0.5` lands the icon on a half pixel — which is exactly the
/// `snapped` finding the engine's UI lint reports at 175 %. Deriving the content
/// from `outer - 2·inset` means there is no remainder to split.
pub const Square = struct {
    /// Outer size of the control, whole physical pixels.
    outer: f32,
    /// Inset on each side, whole physical pixels.
    inset: f32,
    /// What is left in the middle: `outer - 2·inset`, whole physical pixels.
    content: f32,
};

/// `outer_logical` is the control's nominal size, `content_logical` the nominal
/// size of the thing in the middle (an icon).
pub fn squareMetrics(outer_logical: f32, content_logical: f32, scale: f32) Square {
    const outer = snapPx(outer_logical, scale);
    const inset = snapPx(@max(0, (outer_logical - content_logical) / 2), scale);
    return .{ .outer = outer, .inset = inset, .content = @max(0, outer - 2 * inset) };
}

test "square metrics leave no remainder to land on a half pixel" {
    for ([_]f32{ 1.0, 1.25, 1.5, 1.75, 2.0 }) |scale| {
        for ([_][2]f32{ .{ 28, 14 }, .{ 32, 18 }, .{ 40, 18 }, .{ 24, 11 } }) |pair| {
            const square = squareMetrics(pair[0], pair[1], scale);
            try std.testing.expect(isSnapped(square.outer, scale));
            try std.testing.expect(isSnapped(square.inset, scale));
            try std.testing.expect(isSnapped(square.content, scale));
            try std.testing.expectApproxEqAbs(square.outer, square.content + 2 * square.inset, 0.0001);
            try std.testing.expect(square.content > 0);
        }
    }
}

test "snapPx lands on whole physical pixels at every scale" {
    for ([_]f32{ 1.0, 1.25, 1.5, 1.75, 2.0 }) |scale| {
        for ([_]f32{ 1, 2, 4, 6, 8, 12, 16, 20, 24, 28, 40 }) |logical| {
            try std.testing.expect(isSnapped(snapPx(logical, scale), scale));
        }
    }
}

test "snapPx leaves zero alone" {
    try std.testing.expectEqual(@as(f32, 0), snapPx(0, 1.75));
    try std.testing.expectEqual(@as(f32, 0), snapPx(0, 2.0));
}

test "hairline is one whole physical pixel or more, never zero" {
    try std.testing.expectEqual(@as(f32, 1), hairline(1.0) * 1.0);
    try std.testing.expectEqual(@as(f32, 2), hairline(1.75) * 1.75);
    try std.testing.expectEqual(@as(f32, 2), hairline(2.0) * 2.0);
    // A sub-1 scale still cannot ask for less than one physical pixel.
    try std.testing.expectEqual(@as(f32, 1), hairline(0.5) * 0.5);
}

test "a degenerate scale never divides by zero" {
    try std.testing.expectEqual(@as(f32, 8), snapPx(8, 0));
    try std.testing.expectEqual(@as(f32, 1), hairline(0));
}
