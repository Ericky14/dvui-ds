# dvui-ds

## Project Overview

Design system widget library for [dvui](https://github.com/david-vanderson/dvui). Provides themed, chainable builder widgets that eliminate hard-coded styling from application code. Standalone Zig package with dvui as a dependency.

## Architecture

```
src/
├── ds.zig          # Root module: re-exports all widgets + init()
├── tokens.zig      # Theme struct, Variant/Size enums, runtime theme state
├── button.zig      # Unified button (text, icon, icon+text)
├── menu_bar.zig    # Menu bar wrapper
├── menu_item.zig   # Menu item + floating menu
├── panel.zig       # Panel + panel header
├── label.zig       # Themed label with styles
├── icon.zig        # Non-interactive icon display + iconSize()
├── toolbar.zig     # Horizontal toolbar
└── spacer.zig      # Horizontal spacer
```

## Key Patterns

### Builder Pattern
All widgets use chainable builders with `@src()` for dvui identity:
```zig
ds.button(@src(), "Save").variant(.filled).size(.lg).draw()
ds.button(@src(), "").icon("close", bytes).variant(.danger).draw()
ds.label(@src(), "Hello").style(.muted).draw()
```

### Each Widget Owns Its Styling
Widget files contain their own `opts()` / resolver functions. `tokens.zig` only holds the `Theme` struct and shared types — no per-widget logic.

### Runtime Theme
```zig
ds.init(my_theme);  // sets tokens.current
```
Widgets read `tokens.current` at draw time.

## Build

```bash
# From consumer project
zig build

# Standalone (example)
cd vendor/dvui-ds && zig build
```

## Conventions

- **No single-letter variables** — use descriptive names (`btn`, `theme`, `variant`, `padding`, not `b`, `t`, `v`, `s`)
- **No unsafe code**
- **One concept per file** — widgets own their opts resolvers
- **Builder return type matches struct name** — `pub fn button() Button`
- **`pub` only for cross-file usage** — internal resolvers are private (`fn`, not `pub fn`)
- **Comptime branch quota** — use `@setEvalBranchQuota` when `fromHex()` calls exceed default
