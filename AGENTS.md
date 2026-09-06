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
│   ├── text_input.zig  # Themed text field: size, placeholder, label, helper, error, password; draw() reports Enter
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
_ = ds.textInput(@src(), &buffer).size(.lg).placeholder("Email").err(true).helper("Invalid").draw();
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
- **Accent surfaces are derived, not literal:** `accentSoft()`, `accentSoftHover()`,
  `accentOnSoft()`, `accentHover()`, `accentPressed()`. Never paint the accent at a
  low alpha over `surface_0` to get a tonal fill — see "The accent, and why a hex
  is not the decision".
- **Status surfaces have their own, calmer mix:** `statusSoft()` / `statusWash()` /
  `onStatusSoft()` and the `danger*` / `warning*` / `success*` wrappers. Reaching
  for `soft_mix` with a status colour is the bug that made error cards read as
  slabs — see "Status surfaces: a chip is not a panel".

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

### The accent, and why a hex is not the decision

The accent is **`#7CC0FF`** — a light azure. What a "selected row" or a "filled
button" actually looks like is *not* that hex, though: it is a **tonal surface**
derived from it, and that derivation is where the colour is really decided.

**The trap this replaced.** A tonal accent used to be the accent painted at a low
alpha over the app background. `#6EB5FF` at `40/255` over `#0C0E14` composites to
`#1B2839` — relative luminance **0.021**, contrast **1.30:1** against the
background it sits on. That is the "dark blue" that got flagged. And it is not
the hue's fault: `#3B9DFF`, `#4DA6FF` and `#5AB0FF` land at `#132439`, `#162639`
and `#182739` under the same construction — every candidate blue turns into the
same murky navy, because near-black dominates the mix. **Never build an accent
surface out of alpha over the background.**

**What replaced it.** Five derived surfaces on `tokens.Theme`, each a *mix* (not
an alpha) and each overridable, so a downstream theme still only names one blue:

| Method | Mix | Value | Used by |
| --- | --- | --- | --- |
| `accentSoft()` | `mix(accent, surface_0, 0.56)` | `#3D5C7B` | selected tree/sheet row, `badge(.accent)`, the approval card's tint |
| `accentSoftHover()` | `mix(accent, surface_0, 0.50)` | `#44678A` | the same, under the pointer |
| `accentOnSoft()` | `mix(accent, white, 0.60)` | `#CBE6FF` | text and glyphs on those surfaces |
| `accentHover()` | `mix(accent, white, 0.18)` | `#94CBFF` | a solid accent control, hovered |
| `accentPressed()` | `mix(accent, surface_0, 0.18)` | `#68A0D5` | a solid accent control, held |

`soft_mix` is the load-bearing number: it is *how far the tonal surface sits from
the background*, and it decides whether a selected row reads "blue" or "dark
blue" far more than the accent hex does. At `0.64` the row was `#344E69`
(luminance 0.072, 2.24:1 over the background); at **`0.56`** it is `#3D5C7B`
(0.102, **2.78:1**) — a 41 % luminance lift with the same hue.

**Why `#7CC0FF` and not the darker candidates.** `#3B9DFF` / `#4DA6FF` /
`#5AB0FF` are all *less* luminous than the blue they would have replaced (0.323 /
0.361 / 0.404 vs 0.436), so they push the surfaces the wrong way; the picture
shows it — their rows are deeper navy. `#7CC0FF` is 0.492, **+13 %** on the old
accent, and stays in the blue family: `#38BDF8` (sky) matches it for luminance
but shifts the hue to teal, which reads as a different product next to the
red/amber/green trio. Danger, warning and success are untouched.

**Two tiers, and the rule that picks one.** A *control* — something you click,
that is small and wants to be found — is painted with the **solid accent and
dark ink**: `button(.filled)`, `chip(.active)`, `chip(.current)`, `pill(.accent)`.
That is the Material 3 / iOS filled convention and it is what makes a Send button
or a held tool the loudest thing on the page. A *background* — something that
sits behind a row of content you have to read — stays **tonal**: the selected
tree row, the selected sheet row, `badge(.accent)`, the approval card's tint. The
test is "does text sit *on* it or *next to* it": solid for the former, tonal for
the latter. `chip(.current)` keeps its ring, and the ring is stroked in
`surface_0` — an accent ring on an accent chip is invisible.

**Disabled drops the colour; it does not dim it.** The generic disabled path
multiplies a variant's own colours by `opacity_disabled`. That works for a
variant whose rest fill is already a wash. It does **not** work for a solid
accent: `#7CC0FF` at 40 % over the composer background composites to `#3C5976` —
within a hair of the *enabled tonal* fill this design just moved away from — and
the dark ink on top falls to **1.57:1**. So `.filled` names its own opaque,
neutral pair (`surface_3` fill, `text_muted` label, 2.93:1), which is also what
M3 specifies. Off and on are then 8.21:1 apart and 30.7x in luminance, which is
what "reads at a glance" means as a number. `ds.buttonDisabledColors`,
`ds.chipStateColors`, `ds.pillToneColors` and `ds.chipCurrentRingColor` expose all
of it, so an app drawing its own control matches exactly.

**The evidence.** `ds-screenshots/colors_candidates.png` — six accents, the same
real widgets, at 1.75. `ds-screenshots/colors_soft_mix.png` — the chosen accent at
four values of `soft_mix`. Both are rendered by `test/accent_candidates.zig`.

**The contrast table** (WCAG 2.1, dark theme; body ≥ 4.5, captions/icons/
decoration ≥ 3.0). Asserted in `src/tokens_contrast_tests.zig`, pair by pair, so
re-tuning a mix constant cannot quietly push a real pairing under:

| Pair | Ratio | Needs |
| --- | --- | --- |
| `accentOnSoft` on `accentSoft` | 5.37 | 4.5 |
| `accentOnSoft` on `accentSoftHover` | 4.58 | 4.5 |
| `text_primary` on `accentSoft` | 5.76 | 4.5 |
| `text_primary` on `chip(.current)` fill | 9.81 | 4.5 |
| `accent` on `surface_0` | 9.96 | 4.5 |
| `accent` on `surface_2` | 8.90 | 4.5 |
| `accentOnSoft` on `surface_0` | 14.95 | 4.5 |
| `text_secondary` on the approval card's fill | 5.09 | 4.5 |
| `accent` on `chip(.current)` fill | 6.09 | 3.0 (ring) |
| `surface_0` on `accent` | 9.96 | 3.0 (checkbox tick) |
| `accentSoft` on `surface_0` | 2.78 | — (surface lift, min 2.5) |
| `surface_0` on `accent` (solid control, rest) | 9.96 | 4.5 |
| `surface_0` on `accentHover` | 11.27 | 4.5 |
| `surface_0` on `accentPressed` | 6.95 | 4.5 |
| `accent` on `surface_1` (the control's own edge) | 9.50 | 4.5 |
| `accent` on `accentSoft` (a pill on a selected row) | 3.58 | 3.0 |
| `text_muted` on `surface_3` (disabled `.filled`) | 2.93 | — (inactive; exempt) |
| `accent` vs `surface_3` (on vs off fill) | 8.21 | — (states must not be confusable) |
| `onDangerSoft` on `dangerSoft` | 4.90 | 4.5 |
| `onDangerSoft` on `dangerSoftHover` | 4.51 | 4.5 |
| `onDangerSoft` on the approval card's fill (fill-less Deny) | 5.24 | 4.5 |
| `onWarningSoft` / `onSuccessSoft` on their own tints | 5.82 / 5.72 | 4.5 |
| `text_primary` on `dangerWash` (an error card's message) | 13.14 | 4.5 |
| `text_secondary` on `dangerWash` (its path line) | 6.40 | 4.5 |
| `destructive` on `dangerWash` (the card's border and glyph) | 5.26 | 3.0 |
| `dangerSoft` on `surface_0` (chip lift) | 1.64 | 1.6–2.2 |
| `warningSoft` / `successSoft` on `surface_0` | 2.06 / 2.02 | 1.6–2.2 |
| `dangerWash` on `surface_0` (panel lift) | 1.22 | 1.15–1.45 |

The last row is not a WCAG rule — it is the "reads as a lit surface, not as a
shadow" rule, and 2.5 is the floor because 2.12 is what the version that got
flagged measured.

### Status surfaces: a chip is not a panel

Danger, warning and success get tonal surfaces built exactly like the accent's —
**mixed** towards `surface_0`, never the colour at a low alpha — but with their
own, larger mixes. The accent marks the one thing you are meant to reach for. A
script error is not that, and reusing `soft_mix` for it is how a chat column ends
up with two saturated red slabs shouting over the blue control the user is
actually supposed to press.

There are **two size classes**, and the difference is not taste — it is area:

| Method | Mix | destructive | warning | success | For |
| --- | --- | --- | --- | --- | --- |
| `statusSoft(base)` | `mix(base, surface_0, 0.68)` | `#522D31` | `#524430` | `#2C4C3E` | a chip: `pill(.danger)`, `badge(.danger)`, `button(.danger)` |
| `statusSoftHover(base)` | `…, 0.64` | `#5E3336` | — | — | the same, under the pointer |
| `statusWash(base)` | `mix(base, surface_0, 0.84)` | `#2F1E23` | `#2F2922` | `#1C2D29` | a **panel**: the error card, a banner |
| `onStatusSoft(base)` | `mix(base, white, 0.20)` | `#ED8D8D` | `#EDC68A` | `#8CD9AC` | text and glyphs on either |

Named wrappers exist for all of them: `dangerSoft()`, `dangerSoftHover()`,
`onDangerSoft()`, `dangerWash()`, `warningSoft()`, `warningWash()`,
`onWarningSoft()`, `successSoft()`, `successWash()`, `onSuccessSoft()`. `warning`
and `success` are theme tokens now, so the chat's tool-card dots, an error card's
tint and a status pill all come from one place.

**The lift bands**, asserted in `tokens_contrast_tests.zig`:

- a chip-sized tint lifts **1.6–2.2:1** off `surface_0` (it has to be found);
- a panel-sized tint lifts **1.15–1.45:1** (it has to stay a tint).

`danger_soft_mix` is 0.68, not the 0.70 it was drafted at: at 0.70 `destructive`
lifts only 1.58:1, a hair under the floor, while 0.68 puts all three of
danger/warning/success inside 1.64–2.06. `danger_wash_mix` 0.84 lands
`destructive` at 1.22:1 — where the old alpha wash sat — but mixed, so it no
longer takes its hue from whatever is behind it.

**Status ink is not the status colour.** `destructive` on its own tint is
**3.90:1**, under the body bar, so `onStatusSoft` lifts it 20 % towards white.
0.20 is the *smallest* lift that clears 4.5:1 in all three places the ink is
really drawn — on the tint (4.90), on the tint under the pointer (4.51), and on
the approval card, where a fill-less danger button sits on a blue-tinted panel
(5.24). The base red only reaches 4.18 there, so "just use `destructive`" was
never right either. Smallest, because every step towards white is a step away
from reading as red.

**The evidence.** `ds-screenshots/colors_status.png` shows the swatches and, at
the bottom, the same tint at panel size both ways: `statusSoft` reads as a brick,
`statusWash` as a tint. That picture is why the second constant exists.

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

### Text on glass

**One rung brighter than the same text on an opaque panel** — `ds.onGlass(style)`
returns it, so the rule is applied rather than remembered:

```zig
ds.label(@src(), "Position").style(ds.onGlass(.weak)).draw();
```

`weak → muted → secondary → primary`; `title`, `accent` and `danger` already run
at full strength and are unchanged. A glass surface is a tint over a blurred copy
of whatever is behind it, so the effective background is lighter and far less
predictable than a panel's, and the quiet end of the ladder stops being
readable — `.weak` is tuned to disappear against `surface_1` and over a bright
render it does exactly that. Shifting the *whole* ladder keeps the hierarchy: a
caption still reads quieter than a title, which the flatter rule ("use
`.secondary` on glass") throws away by collapsing two rungs into one.

### Drawing through raw dvui

`ds.labelColor(style)` resolves a `LabelStyle` to its colour, for a consumer
handing `dvui.Options` straight to a dvui widget the design system does not
have — a `dvui.textLayout` run, a custom widget, a third-party one:

```zig
dvui.labelNoFmt(@src(), text, .{}, .{
    .color_text = .{ .color = ds.labelColor(ds.onGlass(.muted)) },
});
```

Exported rather than left private because the alternative is a copy of the
switch on the consumer's side, and that copies the *ladder* as well as the
colours: it goes stale the moment a theme adds a rung, and then `ds.onGlass`
and the copy quietly disagree about what "one rung up" means.

### The two edges: structure and decoration

`ds.hairline(scale)` rounds **up** — 2 physical px at 1.75 — so a structural
edge never disappears: a window's two rings, a picture frame's line.
`ds.thinLine(scale)` is **exactly one** physical pixel at every scale, for
decoration: a glass panel's border and its top highlight. Over a dark scene a
2 px white line at 8 % is twice the ink of a 1 px one, which is the difference
between a hint and a ring — measured on a black backdrop, where every white
alpha reads at full contrast (`test/glass_render_tests.zig` pins the profile:
one pixel of border, one pixel of highlight inside it along the top only,
interior everywhere else).

### Rounding a height you had to measure

The one fraction arithmetic cannot snap is a **measured** one: a block of text
is n × a font's line box, and the line box is fractional. Everything under it
then starts on a fraction, and snapping the thing that inherits it cannot help.

`ds.snapHeightBox(@src(), id_extra)` is a container that rounds its own height
to whole physical pixels using the height it had last frame. Wrap a text block
in it and what follows starts on a pixel. `ds.chat.markdown` does this for
itself; `ds.chat.planCard` wraps its eyebrow and title the same way, which is
what finally closed that card's inherited-fraction findings.

Height only, never width, so it can never change how text wraps and therefore
can never oscillate. It rounds to nearest, so it can clip by up to half a
physical pixel — sub-pixel, invisible — and content that grows is one frame late
before the pin catches up. ⚠ If you use `ds.snapHeightOpts` directly, pass the
**same** `@src()` you create the box with, or the id is not the box's and the
pin silently does nothing; `snapHeightBox` cannot be called wrong.

### Where a `snapped` finding actually comes from

A widget owns its **size** and its internal insets; its **origin** it inherits.
So a `snapped` finding on a leaf usually names the wrong file. Two ds widgets
now round on the way through, because they are the boundaries where a fraction
would otherwise be handed on: `ds.glass` rounds **its own rect** (a sheet's rect
comes from a pane split or a percentage, and a panel that keeps that fraction
gives it to every row inside), and `ds.snapHeightBox` rounds a measured height. The pinned case
is `test/lint_tests.zig` → "a button's edges follow its container": the same
button, at the same scale, is clean inside a container padded with `ds.padding(5)`
and reports a half-pixel edge inside one padded with a raw `dvui.Rect.all(5)`
— 5 logical px is 8.75 physical at 175 %, and nothing inside can land on a pixel
after that. Before chasing the widget, check what positioned it, and use
`ds.padding` / `ds.paddingXY` / `ds.paddingEach` / `ds.border` for every inset.

### Borderless window

`ds.windowFrame`'s double ring only means anything on a **borderless** window —
inside an OS-decorated one it is drawn under somebody else's title bar and the
app's own caption row stacks below the OS one. `ds.App` creates its window
borderless by default (`AppConfig.borderless`).

Borderless costs dragging, the resize edges and double-click-to-maximise;
`ds.windowChrome` gives all three back through SDL's hit test. The app declares,
once per frame, where its title bar and caption buttons are:

```zig
ds.windowChrome.declare(.{
    .drag = title_bar_rect,                       // logical window coords
    .buttons = &.{ minimise, maximise, close },   // holes in the drag region
    .resize_margin = 6,                           // logical px, the default
});
```

Order inside the classifier, and the reason for it: resize borders beat the
title bar (or a corner can be dragged but never resized), buttons beat the drag
region (or close moves the window instead of closing it), everything else is
normal so the widgets keep their clicks. It is a pure function
(`ds.windowChrome.classify`) with its own tests. Declare nothing and the window
simply has no drag region — the resize borders still work, so a missed frame
never leaves a window stuck at one size.

`minimise()` and `toggleMaximise()` are the caption actions; closing stays the
app's, since it owns the frame loop and whatever has to be saved first.
`example/title_bar.zig` is the worked example, and the storybook runs it.

On Windows a borderless window loses the rounded corners, so `App` asks DWM for
them back (`DWMWA_WINDOW_CORNER_PREFERENCE`, looked up at runtime rather than
linked — a design system cannot make every consumer add `dwmapi` to its build).

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

**`chrome_control_height` (28) is the one that governs a control *row*.** Every
control on one line takes it — a composer's attach button, its text entry and
its Send button; a toolbar's buttons and its readouts — so they share a top and
a bottom edge without anyone padding anything by hand. A container built around
such a row is that height plus one `space_sm` of inset (border *plus* padding)
on each side: `ds.chat.composer` is 28 + 16 = **44 logical px** on one line, and
whole physical pixels at 1.0, 1.75 and 2.0.

The composer is what named the rule. It used to be 50.50 px tall for one line of
text, holding three controls of three different heights — 28.00, 32.50, 26.11 —
each dropped to the bottom by a spacer, so their tops were ragged. That is what
"too tall and not uniform" looks like, and it is what a row with no agreed height
always looks like eventually.

Growth is the other half: when the entry runs to several lines the buttons take
`gravity_y = 1` and stay on the bottom edge beside its last line. A spacer above
each one does the same thing on paper and none of it on one line, because each
control starts falling from a different height.

### Icons in buttons

`icon_button_ratio` (0.5) sizes the glyph inside an icon-*only* button or a chip
as a fraction of that control: 14 px in a 28 px button. The thing being matched
is the button, not the type beside it — `icon_sm` (11) in a 28 px button is a
0.39 ratio, which reads as a small mark adrift in a big empty square, and modern
chrome sits at 0.5–0.6.

`icon_sm` keeps its own job: a glyph standing next to caption text — a pill's
leading icon, a status strip, and the icon inside an icon **plus label** button,
where 11 beside 11 px type is right and 14 would tower over it. So the two paths
are sized by different rules on purpose, and `ds.chip` and an `sm`
`ds.iconButton` come out as the same square by construction.

### Elevation

One three-step scale (`elevation_1..3_offset` / `_fade`) shared by every raised
surface, so a card, a dialog and a popover agree. Glass casts no shadow: over a
live view a cast shadow on a translucent panel is physically wrong and reads as
dirt — the blur and the hairline are the separation.

### A control's height is measured, never guessed

⚠ **`dvui` sizes a single-line `TextEntryWidget` in the THEME's body font, not
in the caller's.** `TextEntryWidget.init` runs `defaults.min_sizeM(defaultMWidth,
1)` and then, for a single-line field, caps it (`max_size_content =
min_size_content`) — both before `options.override(opts)`, and `defaults` carries
no font. So the box was `themeGet().font_body`'s line box while the glyphs were
drawn in `ds.font(12|13|14)`, and dvui's cap took the difference off the bottom
of every descender. On the engine's theme (an 11 px body font, 14.30 px of line)
all three sizes clipped; on the storybook's own (13 px) only `lg` did, which is
why it went unseen. The owner reported it as a placeholder "cut off on the
bottom" (2026-09-06).

`TextInput.inputOpts` states the box now, and the shape generalises to any
fitted control:

- the CSS table keeps the **height**, the **horizontal** padding and the font
  size — those are the spec;
- the **vertical padding is derived**: half of what the spec height has left
  after the measured line box and the two borders, snapped DOWN
  (`ds.snapDownPx`) so the total stays exactly the spec height and lands on a
  whole physical pixel at 1.75 as well as at 1 and 2;
- the content height is `height - 2·pad_y - 2·border`, floored at the line box,
  so a face too tall for its spec grows the control instead of cutting the text.

`test/lint_tests.zig` measures it with the real font cache at all three scales,
and holds the "can say no" case: the box dvui would have measured for an `lg`
field is shorter than the line an `lg` field draws.
`ds-screenshots/text_input_sizes.png` is the picture — `C:\games\MyGame` at
sm/md/lg, 175 %, descenders whole.

**`TextInput.draw()` returns a `Result`** (`enter_pressed`, `focused`,
`changed`), so a form does not hand-roll a `dvui.TextEntryWidget` beside this one
to read Enter — which is how a second copy of the sizing above gets written and
drifts. Callers that only want pixels write `_ = ds.textInput(…).draw();`.

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
