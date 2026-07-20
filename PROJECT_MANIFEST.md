# Project Manifest: gameTest

This project is a 2D top-down auto-shooter (similar to Vampire Survivors) made in Lua using the LÖVE (Love2D) framework.

## Architecture & Entry Point
- **Entry Point**: `main.lua` contains the entire game loop (`love.load`, `love.update`, `love.draw` etc.).
- **Engine**: LÖVE (Love2D).

## Game Mechanics
- **Player & Movement**: The player can be moved using WASD or a gamepad/joystick. There is also a dash mechanic.
- **Combat**: 
  - The player starts with a pistol that automatically targets and shoots at the closest enemy within detection range.
  - Boomerangs are NOT automatic. They are unlocked and strengthened only by selecting the Boomerang upgrade at level-up.
- **Progression**: 
  - Eliminating enemies grant the player experience points. Gathering enough XP triggers a level-up where the player chooses from up to 3 random upgrades from the `upgradePool`.
  - The `upgradePool` contains: Move Speed (+16 speed), Pistol (+1 bullet damage and +1 shot per second), and Boomerang (first pick unlocks, further picks add +1 boomerang).
  - Each upgrade in the `upgradePool` is capped at level 5. When fewer than 3 upgrades remain below their cap, the empty level-up slots are filled with a "Vitality" option granting +20 max HP (and healing 20).
  - The player's HP is tracked against a `maxHp` (starts at 100), which can be increased via the Vitality upgrade.
- **Enemies**: 
  - **Normal**: Basic melee enemies that spawn off-screen and swarm the player.
  - **Elite**: Tougher variants with more HP and XP drops that begin spawning at level 5+.
  - **Special**: Boss-like enemies that spawn after killing a set number of regular enemies. Defeating them drops chests which provide "power bullets" (a spread shot).
- **Optimization**: The game uses a spatial grid partitioning system (`buildGrid`, `getNearbyEnemies`) for efficient collision detection between numerous bullets and enemies.
