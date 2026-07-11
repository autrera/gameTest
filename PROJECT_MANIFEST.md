# Project Manifest: gameTest

This project is a 2D top-down auto-shooter (similar to Vampire Survivors) made in Lua using the LÖVE (Love2D) framework.

## Architecture & Entry Point
- **Entry Point**: `main.lua` contains the entire game loop (`love.load`, `love.update`, `love.draw` etc.).
- **Engine**: LÖVE (Love2D).

## Game Mechanics
- **Player & Movement**: The player can be moved using WASD or a gamepad/joystick. There is also a dash mechanic.
- **Combat**: 
  - The player automatically targets and shoots at the closest enemy within detection range.
  - At level 4 and above, boomerangs are automatically fired in a circular spread around the player.
- **Progression**: 
  - Eliminating enemies grant the player experience points. Gathering enough XP triggers a level-up where the player can choose from random upgrades (Fire Rate, Move Speed, Detection Range, Bullet Damage).
- **Enemies**: 
  - **Normal**: Basic melee enemies that spawn off-screen and swarm the player.
  - **Elite**: Tougher variants with more HP and XP drops that begin spawning at level 5+.
  - **Special**: Boss-like enemies that spawn after killing a set number of regular enemies. Defeating them drops chests which provide "power bullets" (a spread shot).
- **Optimization**: The game uses a spatial grid partitioning system (`buildGrid`, `getNearbyEnemies`) for efficient collision detection between numerous bullets and enemies.
