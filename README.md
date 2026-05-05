# dvui-ds

Design system widget library for [dvui](https://github.com/david-vanderson/dvui). Provides themed, chainable builder widgets that eliminate hard-coded styling from application code.

## Features

- **Builder pattern API** — chain `.variant()`, `.size()`, `.style()` then `.draw()`
- **Runtime theming** — call `ds.init(theme)` once; all widgets read tokens automatically
- **Batteries included** — default dark theme ships out of the box
- **Zero allocations** — all builders are stack-only value types

## Widgets

| Widget | Usage |
|--------|-------|
| `button` | `ds.button(@src(), "Save").variant(.filled).draw()` |
| `iconButton` | `ds.iconButton(@src(), "close", icon).variant(.danger).draw()` |
| `menuBar` | `var bar = ds.menuBar(@src()).draw(); defer bar.deinit();` |
| `menuItem` | `if (ds.menuItem(@src(), "File").submenu().draw()) \|r\| { ... }` |
| `floatingMenu` | `var fw = ds.floatingMenu(@src(), rect); defer fw.deinit();` |
| `panel` | `var p = ds.panel(@src()).draw(); defer p.deinit();` |
| `panelHeader` | `var h = ds.panelHeader(@src()).draw(); defer h.deinit();` |
| `toolbar` | `var tb = ds.toolbar(@src()).draw(); defer tb.deinit();` |
| `label` | `ds.label(@src(), "Hello").style(.muted).draw();` |
| `icon` | `ds.icon(@src(), "name", bytes).style(.accent).draw();` |
| `spacer` | `ds.spacer(@src());` |

## Variants & Sizes

**Variants:** `filled`, `outlined`, `ghost`, `danger`
**Sizes:** `sm`, `md`, `lg`

## Setup

### As a Zig dependency

```zig
// build.zig.zon
.dvui_ds = .{ .path = "vendor/dvui-ds" },
```

```zig
// build.zig
const dvui_ds_dep = b.dependency("dvui_ds", .{ .target = target, .optimize = optimize });
const dvui_ds_mod = dvui_ds_dep.module("dvui_ds");
dvui_ds_mod.addImport("dvui", your_dvui_module);
your_app_mod.addImport("dvui_ds", dvui_ds_mod);
```

### Theme initialization

```zig
const ds = @import("dvui_ds");

// Use default dark theme (no init needed), or provide custom tokens:
ds.init(.{
    .bg_base = .fromHex("#0D0D0D"),
    .bg_surface = .fromHex("#161616"),
    .bg_elevated = .fromHex("#222222"),
    // ... see tokens.zig Theme struct for all fields
});
```

## License

MIT
