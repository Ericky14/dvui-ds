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
│   ├── loader.zig      # Spinner / loading indicator
│   ├── spacer.zig      # gap / gapH spacers
│   └── router.zig      # Router(PageEnum): sidebar nav for the storybook / app shells
├── helpers/            # padding.zig, fonts.zig (font/fontMedium/...), color.zig, svg.zig (cachedTvg)
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
