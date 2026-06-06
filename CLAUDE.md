# CLAUDE.md

Guidance for Claude Code when working in the **dvui-ds** design system. Full
conventions live in **@AGENTS.md** — read it for the widget architecture, builder
pattern, tokens, and the storybook dev loop.

## Quick reference

- This is a standalone Zig package (its own `build.zig` / submodule remote),
  consumed by the parent `zigame` engine. Build/test from **this** directory.
- `zig build test` — widget unit tests. `zig build example` — run the storybook.
- `zig build screenshots` — render each component to `ds-screenshots/*.png`
  headlessly (CPU, no GPU/window) for visual verification; add a component by
  adding a `test` to [test/screenshots.zig](test/screenshots.zig). See AGENTS.md
  → "Component screenshots". This is how to visually check a component's render.
- New widget? Follow the **"Adding a widget" checklist** in AGENTS.md, or use the
  `/ds-widget` skill from the parent repo — it scaffolds widget + tests + `ds.zig`
  export + storybook page in one pass.
- Widgets are **value-type builders**: setters copy `self`, mutate the copy,
  return it; styling lives in the widget's own `opts()` reading `tokens.current`.
- `zig fmt` is the linter; format-on-save is enabled for `.zig`.
