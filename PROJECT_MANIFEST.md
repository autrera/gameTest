# Project Manifest: gameTest

This project is a 2D top-down auto-shooter (similar to Vampire Survivors) made in Lua using the LÖVE (Love2D) framework. The game ships under the title brand "SWARM PROTOCOL".

## Architecture & Entry Point
- **Entry Point**: `main.lua` contains the entire game loop (`love.load`, `love.update`, `love.draw` etc.).
- **Engine**: LÖVE (Love2D).
- **Window & Resolution**: The game launches in **desktop fullscreen** (`fullscreen = true`, `fullscreentype = "desktop"`). `window_width` / `window_height` are derived from `love.graphics.getDimensions()` at startup, and `love.resize(w, h)` keeps them in sync on any resolution change. Camera framing, enemy spawn boundaries, grid rendering, and every UI/HUD layout read these two globals, so the whole game scales automatically to any monitor size.
- **Screen States**: A lightweight state flag (`titleScreen`, `paused`, `levelUpActive`, `gameOver`) drives the overlay stack; all overlays are drawn from shared layout helpers so keyboard, gamepad, and mouse input stay in sync.

## Game Mechanics
- **Player & Movement**: The player can be moved using WASD or a gamepad/joystick. There is also a dash mechanic.
- **Combat**: 
  - The player starts with a pistol that automatically targets and shoots at the closest enemy within detection range.
  - Boomerangs are NOT automatic. They are unlocked and strengthened only by selecting the Boomerang upgrade at level-up.
  - **Shield Wave** (unlockable upgrade): an expanding circular wave (radius 0 → 200 over 1 second) emanates outward from the player. When the wave touches a normal or elite enemy, it pushes the enemy backward away from the player. Special (boss) enemies are immune. The wave triggers every 5.0 seconds at level 1, and each level-up reduces the cooldown by 0.5s (4.5s at level 2, 4.0s at level 3, etc.).
- **Progression**: 
  - Eliminating enemies grant the player experience points. Gathering enough XP triggers a level-up where the player chooses from up to 3 random upgrades from the `upgradePool`.
  - The `upgradePool` contains: Pistol (+1 bullet damage, +1 shot per second), Boomerang (first pick unlocks, further picks add +1 boomerang), Laser Gun (unlock / +1 damage), Missiles (unlock / +10 missile damage), and Shield Wave (first pick unlocks the wave, further picks reduce its cooldown by 0.5s).
  - Each upgrade in the `upgradePool` is capped at level 5. When fewer than 3 upgrades remain below their cap, the empty level-up slots are filled with a "Vitality" option granting +20 max HP (and healing 20).
  - The player's HP is tracked against a `maxHp` (starts at 100), which can be increased via the Vitality upgrade.
- **Enemies**: 
  - **Normal**: Basic melee enemies that spawn off-screen and swarm the player.
  - **Elite**: Tougher variants with more HP and XP drops that begin spawning at level 5+.
  - **Special**: Boss-like enemies that spawn after killing a set number of regular enemies. Defeating them drops chests which trigger the level-up upgrade selection. Special enemies are immune to the Shield Wave's pushback.
- **UI / HUD (Modern Redesign)**:
  - **Vitals panel** (top-left): glassmorphic panel with a circular Level badge, gradient HP bar, gradient XP bar, live HP/XP numbers, and TIME/KILLS readout.
  - **Arsenal panel** (top-right): per-weapon upgrade badges with colored icon tiles, weapon name, tier counter (LV n/5), tier pips, and live stat lines (damage, rate, cooldown).
  - **Level-up screen**: three selectable upgrade cards with category badges (WEAPON / SUPPORT), progression counters (NEW or LV n -> n+1), weapon icon tiles, tier pips with next-level highlight, and accent-colored selection glow.
  - **Pause / Game Over / Title overlays**: centered glass dialog panels with accent-highlighted menu buttons, run-stats summaries, dark translucent backdrops with edge vignette, and consistent hint text. The game opens on a title screen (Start Game / Quit) before the run begins.
  - All UI is drawn with Love2D primitives (rounded rectangles, gradient strips, translucent overlays) from the shared UI helper layer in `main.lua` (`drawPanel`, `drawProgressBar`, `drawGradientRounded`, `drawMenuButton`, etc.).
- **Optimization**: The game uses a spatial grid partitioning system (`buildGrid`, `getNearbyEnemies`) for efficient collision detection between numerous bullets and enemies.
