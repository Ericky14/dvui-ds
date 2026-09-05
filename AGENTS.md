# dvui-ds

## Project Overview

Design system widget library for [dvui](https://github.com/david-vanderson/dvui).
Provides themed, chainable **builder** widgets that eliminate hard-coded styling
from application code. Standalone Zig package (dvui + zig-sdl3 + zwgpu as
dependencies) with a runnable **storybook** for visual development.

Consumed by the parent `zigame` engine as a package; also builds and runs on its
own. This is the active development area of the engine right now.

## Architecture

```
src/
├── ds.zig              # Root module: re-exports all widgets/helpers/types + init()
├── tokens.zig          # Theme struct, Variant/Size enums, `current` theme, default_theme, dvuiTheme()
├── widgets/
│   ├── button.zig      # Unified button (text / icon / icon+text), variants, sizes, states
│   ├── label.zig       # Themed label (LabelStyle, FontToken)
│   ├── icon.zig        # Non-interactive icon display (IconStyle), iconTvg
│   ├── text_input.zig  # Themed text field: size, placeholder, label, helper, error, password
│   ├── row.zig         # Horizontal box layout (.gap, .expand, .padding) → draw() handle
│   ├── column.zig      # Vertical box layout
│   ├── panel.zig       # Panel + panelHeader
│   ├── menu_bar.zig    # Menu bar wrapper
│   ├── menu_item.zig   # Menu item + floatingMenu
│   ├── toolbar.zig     # Horizontal toolbar
│   ├── glass.zig       # Blurred-backdrop surface + glassScene (see "The Look")
│   ├── window_frame.zig # The window's double border
│   ├── preview_frame.zig # Frame + vignette + slots around a picture
│   ├── chip.zig        # Square icon chip for dense strips
│   ├── pill.zig        # Rounded status / selection readout
│   ├── loader.zig      # Spinner / loading indicator
│   ├── spacer.zig      # gap / gapH spacers
│   └── router.zig      # Router(PageEnum): sidebar nav for the storybook / app shells
├── helpers/            # padding.zig, fonts.zig, color.zig, svg.zig, pixels.zig (snapPx/hairline)
├── anim/               # animation primitives (anim.zig, color, float, options, utils)
├── icons/lucide/       # Lucide icon set (TVG)
├── icons.zig           # icon byte re-exports (ds.icons.save, ...)
├── fonts/              # Geist (Regular/Medium/Bold) + Geist Mono (Regular/Medium), SIL OFL
├── platform/           # app.zig, backend.zig (SDL3), gpu.zig (wgpu), runner.zig
├── focus.zig           # focus helper module (ds_focus)
├── motion.zig          # motion tokens
└── log.zig             # timestamped log handler for the storybook

example/
├── main.zig            # Storybook app: Router(Page) sidebar + content switch
└── pages/              # One file per showcased component, registered in pages.zig
```

## Key patterns

### Builder pattern (value types, copy-on-set)

Every widget is a stack-only value type. Setters take `self` **by value**, copy
it, mutate the copy, and return it. A terminal `draw()` renders. Use `@src()` for
dvui identity:

```zig
ds.button(@src(), "Save").variant(.filled).size(.lg).draw();
ds.button(@src(), "Save").variant(.filled).icon("save", ds.icons.save).iconFirst().draw();
ds.label(@src(), "Hello").style(.muted).draw();
ds.textInput(@src(), &buffer).size(.lg).placeholder("Email").err(true).helper("Invalid").draw();
```

Setter shape (copy, don't mutate `self` in place):
```zig
pub fn size(self: Widget, val: tokens.Size) Widget {
    var copy = self;
    copy.input_size = val;
    return copy;
}
```

Layout widgets return a handle you `deinit()`:
```zig
var r = ds.row(@src()).gap(theme.space_sm).draw();
defer r.deinit();
```

### Each widget owns its styling

A widget file contains its own `opts()` / resolver functions that read
`tokens.current`. `tokens.zig` only holds the `Theme` struct + shared enums
(`Variant`, `Size`) — **no per-widget logic**.

### Runtime theme

```zig
ds.init(my_theme);   // sets tokens.current; widgets read it at draw time
```
Default is the **Cosmic Teal** dark theme (`tokens.default_theme`) — no `init()`
needed to get a working look. `tokens.dvuiTheme()` maps tokens onto a `dvui.Theme`
so dvui-native widgets match.

### Tokens

- **Variants:** `filled`, `outlined`, `ghost`, `danger`, `accent_ghost`
- **Sizes:** `sm`, `md`, `lg`
- Theme fields: surfaces (`surface_0..4`), text (`text_primary/secondary/muted/ghost`),
  `accent`/`accent_muted`, `destructive`/`destructive_muted`, borders, `space_*`,
  `radius_*`, `icon_*`, `font_size_*`, opacity tokens. See `tokens.zig`.

## Storybook (the dev loop)

```bash
cd vendor/dvui-ds
zig build example       # launch the visual showcase (GPU window)
zig build test          # widget unit tests (verified green)
zig build screenshots   # render each component to ds-screenshots/*.png (headless CPU, no GPU)
```

## Component screenshots (visual verification)

Fixtures live in `test/screenshots.zig` and, per area, `test/chat_screenshots.zig`,
`test/card_screenshots.zig` and `test/chrome_screenshots.zig`. `shots.capture`
renders at scale 2.0; `shots.captureAt` takes an explicit scale, which is how the
editor-chrome page is published at both 1.0 and 1.75.

`zig build screenshots` renders each DS component to a PNG under `ds-screenshots/`
with **no GPU or window** — it builds against dvui's testing backend, which
rasterizes on the CPU. Deterministic, so the PNGs double as visual-regression
fixtures. Add a component by adding a `test` to [test/screenshots.zig](test/screenshots.zig):

```zig
test "my widget" {
    const Local = struct {
        fn frame() !dvui.App.Result {
            var bg = background(@src());
            defer bg.deinit();
            _ = ds.button(@src(), "Save").variant(.filled).draw();
            return .ok;
        }
    };
    try capture("my_widget.png", 320, 90, Local.frame);
}
```

Components must be rendered at a real size (a widget given only a width collapses
to zero height and its text won't show — see the dvui CLAUDE.md gotcha).

`example/main.zig` defines a `Page` enum, a `Router(Page)` for the sidebar, and a
`switch (router.active)` that dispatches to a page's `draw()`. Each page is
`example/pages/<name>.zig` exposing `pub fn draw() void`, registered in
`example/pages/pages.zig`.

## The Look

The chrome language the design system draws windows in. Dark first.

### Glass

`ds.glass` is a translucent surface floating over a blurred copy of what is
behind it — CSS `backdrop-filter: blur()`, via dvui's `BlurBackdrop`. Three
layers, and all three matter: the blurred capture, a **tint** over it, and a
**1 px inner highlight along the top edge**. The highlight is the layer that
sells it; without it a translucent panel reads as a weak fill rather than as a
pane of glass.

- **Use glass** for a surface that floats over *content*: a drawer or sheet over
  a live view, a toolbar over a picture, a popover over a document.
- **Do not use glass** over an opaque column — a blur of a flat fill is the flat
  fill. `ds.glass` without a `.rect()` gives you the inline version (tint +
  hairline + highlight, no blur), which is the right call for a composer or a
  bar that wants the family look without pretending to be transparent.
- **Text on glass uses `.secondary` or `.primary`**, never `.muted` / `.weak`.
  Those are tuned for an opaque dark surface and disappear over a bright blur.
- `glass_alpha` is 214 (≈84 %) on purpose. Prettier values exist; they cost
  legibility over a bright render, which an inspector does not get to trade.
  `.solid(true)` (or a backend with no render targets) falls back to
  `glass_alpha_opaque`.

**The bracket.** A backdrop must be captured *before* the surface draws, so
glass is two calls, not one:

```zig
// one panel
var drawer = ds.glass(@src()).rect(r).witness(frame_no).behind();
drawPreview();
var surface = drawer.draw();
defer surface.deinit();

// several panels over the same content — one capture, one blur per frame
var scene = ds.glassScene(@src()).rect(viewport).witness(frame_no).begin();
drawPreview();
var bar = ds.glass(@src()).rect(bar_rect).scene(scene).draw();
bar.deinit();
scene.end();   // AFTER the panels
```

⚠ **The panels go inside the bracket.** An open bracket is what makes dvui defer
the background's drawing, and only draws made while it is open land in their own
subwindow queue and therefore *above* that background. Close the scene first and
the panels are painted straight onto the target, then the deferred background
replays over them and they vanish — no error, just nothing.

**Cost.** Measured, with `zig build blur-cost -Doptimize=ReleaseFast`: over a
1400×860 logical viewport at 1.75 (2450×1505 physical), a *cached* capture costs
0.02 ms/frame — one textured quad, indistinguishable from drawing nothing — and
a *re-capture* costs 0.96 s/frame **on dvui's CPU testing backend**, which is a
software rasteriser and not the wgpu path the app runs. Take the ratio, not the
number: cached is free, re-capturing is not, on any backend, because it replays
the background's render commands (real glyph shaping and path triangulation, not
a blit) and then resamples the whole area ~2·log2(radius) times.

The capture is cached and only redone when `rect` or `witness` change.
Over a live 3-D preview that means the caller passes the preview's frame counter
**only while it is playing**, and a constant while it is paused; pass a constant
and the glass keeps showing the last frame it captured, at the price of one
textured quad per panel per frame. While it *is* changing, every frame costs one
replay of the background's render commands plus ~2·log2(radius) half-resolution
passes — real CPU work in dvui's deferred renderer, not a GPU blit, so measure it
against your frame budget before blurring a 4K viewport every frame.

### The double border

`ds.windowFrame` draws two hairlines, not one: a near-black outer ring that
separates the app from the desktop, and a white inner ring at ~10 % that lifts
the app off that separation. Either alone reads badly — the dark one as a smudge,
the light one as a cheap outline. `focused(false)` dims the inner ring so an
unfocused window recedes.

### The preview frame

`ds.previewFrame` is what stops a render from looking like a hole in the app:
a gutter, a rounded corner from the same radius family as the panels, an inner
vignette so a bright render stops bleeding into the chrome, and a hairline drawn
*over* the picture's edge so the boundary is a deliberate line. `toolbarRect` /
`statusRect` hand out the slots along the edges; `reserve(.right, px)` shrinks
those slots when a drawer is docked over part of the picture.

### Pixel snapping

Chrome is where fractional scaling shows. Every ds length is authored in logical
pixels and multiplied by the window scale; at 1.0 and 2.0 that lands on whole
physical pixels by accident, at **1.75** it does not, and a 1 px hairline becomes
a 1.75 px smear. `src/helpers/pixels.zig` is the arithmetic:

- `ds.pixelScale()` — the scale in force right now.
- `ds.snapPx(logical, scale)` — a length that lands on whole physical pixels.
- `ds.hairline(scale)` — the thinnest line the display can draw un-antialiased.

A widget owns its **size** and its internal insets; where it is *placed* is the
parent's business, so both halves have to keep the discipline. `test/layout_tests.zig`
asserts it numerically at 1.0 / 1.75 / 2.0 (part of `zig build test`, not
`screenshots` — a PNG cannot claim a widget is centred, only that it looks it).

### Spacing

Gaps between siblings are on the **4 px grid**: `space_2xs` 4, `space_sm` 8,
`space_md` 12, `space_lg` 16, `space_xl` 20, `space_2xl` 24. `space_3xs` (2) and
`space_xs` (6) are **off-grid on purpose and are for a control's own internals**
(the gap between an icon and its label inside one chip, a 6 px inset inside a
toolbar) — never for the gap *between* siblings in a row or column.

### The geometry gate

`test/lint_tests.zig` runs the same four rules the engine's `zigame ui lint`
runs over an editor pane — `snapped`, `grid`, `row_centre`, `hit_target`, at the
same tolerances (`test/ds_lint.zig`) — over one ds widget at a time, at 1.0,
1.75 and 2.0. It is part of `zig build test`.

It exists because the engine can only see this repo through a pinned commit: a
finding it reports against `plan_card.zig:63` has to be reproducible and fixable
*here*, before any pin moves, or the fix is a guess.

Where a widget still reports something, the test records the exact count with the
reason written beside it and asserts **equality** — fixing one more fails the
test as loudly as breaking one, so the number only moves on purpose. Today the
whole residual is one cause: a widget whose *top* edge inherits a fraction from
text stacked above it. Font metrics are fractional, dvui does not round a
resolved rect to physical pixels, and a design system cannot round a multi-line
text block's height without owning text layout — pinning it would cap the
composer at one line.

What the ds *is* responsible for, and does keep exact: its own paddings, margins,
borders, gaps, control sizes, hit targets and centre lines. `ds.padding` /
`paddingXY` / `paddingEach` / `border` all snap; `ds.button` is the height its
size names whatever variant and padding it wears; `ds.iconButton` and `ds.chip`
share `pixels.squareMetrics`, which leaves no remainder for `gravity` to split.

### Chrome metrics

Shared so the title bar, the floating toolbar, the status strip and the history
strip line up instead of each picking its own number: `chrome_titlebar_height`
36, `chrome_toolbar_height` 40, `chrome_status_height` 28, `chrome_chip_size` 28
(matches the `sm` button, comfortably over the 24 px minimum hit target),
`chrome_pill_height` 24.

### Elevation

One three-step scale (`elevation_1..3_offset` / `_fade`) shared by every raised
surface, so a card, a dialog and a popover agree. Glass casts no shadow: over a
live view a cast shadow on a translucent panel is physically wrong and reads as
dirt — the blur and the hairline are the separation.

## Adding a widget (checklist)

1. Create `src/widgets/<name>.zig`: a builder fn `pub fn <name>(@src(), ...) <Name>`
   returning a `<Name>` value type with copy-on-set setters and a terminal `draw()`.
   Keep all styling in this file's `opts()` resolver, reading `tokens.current`.
2. Add `_ = @import("<name>_tests.zig");` at the bottom and write
   `src/widgets/<name>_tests.zig`.
3. Re-export in `src/ds.zig` (`pub const <name> = @import("widgets/<name>.zig").<name>;`)
   and add the test import to the `test {}` block in `ds.zig` if it isn't picked up.
4. Add a storybook page `example/pages/<name>.zig` + register it in `pages.zig`,
   the `Page` enum, the sidebar `router.link(...)`, and the content `switch`.
5. `zig build test` then `zig build example` to verify.

## Conventions

- **No single-letter variables** — descriptive names (`btn`, `theme`, `variant`, `padding`).
- **No unsafe code.**
- **One concept per file** — widgets own their `opts()` resolvers.
- **Builder return type matches the struct name** — `pub fn button() Button`.
- **`pub` only for cross-file usage** — internal resolvers stay private (`fn`, not `pub fn`).
- **Copy-on-set** — setters return a modified copy; never mutate `self` in place.
- **Comptime branch quota** — `@setEvalBranchQuota(...)` when `fromHex()` calls exceed the default.
- **Doc comment (`///`)** every public widget/builder with a usage example.
