# Project agent memory

This file is the project's committed home for project-intrinsic agent knowledge: build, test, release, architecture, and sharp-edge notes that should travel with the code.

- Add durable project-specific notes here as they are discovered through real work.

## Maintaining this file

Keep this file for knowledge useful to almost every future agent session in this project.
Do not repeat what the codebase already shows; point to the authoritative file or command instead.
Prefer rewriting or pruning existing entries over appending new ones.
When updating this file, preserve this bar for all agents and keep entries concise.

## Project notes

- **Single-file game**: all game logic and UI live in `main.lua` (LÖVE 11).
- **Fullscreen & resolution**: the game launches in desktop fullscreen; `window_width`/`window_height` come from `love.graphics.getDimensions()` and `love.resize(w, h)` keeps them current. Any new screen-space code must read those two globals (never hardcode 1280x720) or it will misplace on other monitors. Viewport-derived game logic already exists: `updateMissileRange()` (missile range/age, re-run from `love.resize`) and the angle-based spawn projection in `spawnEnemies()`.
- **UI layer**: modern glassmorphic UI helpers (`drawPanel`, `drawProgressBar`, `drawGradientRounded`, `drawMenuButton`, overlay draw fns) sit just above `love.draw()` in `main.lua`. Overlay layout helpers (`getPauseMenuLayout`, `getLevelUpLayout`, ...) are shared with input handlers — keep hit-testing in sync with them when changing layouts.
- **Fonts**: `font16`/`font18`/`font20`/`font24`/`font28`/`font48`/`font64` are created in `love.load`. LÖVE's default font lacks non-Latin-1 glyphs (e.g. →, ▸) — stick to ASCII or Latin-1 characters (·, × are safe) in UI strings.
- **Verification**: `luajit -b main.lua /tmp/out` for a syntax gate; run `/Applications/love.app/Contents/MacOS/love .` to play. Screenshots of any UI state can be captured with a temporary harness calling `love.graphics.captureScreenshot` (writes land in `~/Library/Application Support/LOVE/<game>/`).
