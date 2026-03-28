# Ritz — A Procedural Domino Puzzle Game

> A logic puzzle game built with Godot 4.5 where you place dominoes on a procedurally generated grid to satisfy mathematical constraints.

🎮 **[Play Online on itch.io →](https://javen-w.itch.io/ritz)**

---

## Table of Contents

- [Play Online](#play-online)
- [Game Description](#game-description)
- [How to Play](#how-to-play)
- [Features](#features)
- [Technical Overview](#technical-overview)
- [Setup & Build](#setup--build)
- [Project Structure](#project-structure)
- [Credits](#credits)
- [License](#license)

---

## Play Online

Ritz runs entirely in the browser — no download or installation required.

**[▶ Play on itch.io](https://javen-w.itch.io/ritz)**

> **Browser requirements:** A modern browser with WebGL 2.0 and WebAssembly support (Chrome, Firefox, Edge, or Safari 16+).
> Click anywhere on the game canvas first to ensure keyboard input is captured.

---

## Game Description

Ritz is a single-player puzzle game centered around dominoes and constraint satisfaction. A grid of tiles is procedurally generated, each displaying a dot value between 0 and 6. Pairs of adjacent tiles are grouped into dominoes, and overlapping tile groups are given **constraints** — mathematical rules that must be satisfied when you place a domino on matching tiles.

Your goal is to place every domino on the board so that every constraint is satisfied at the same time.

<!-- TODO: Add a screenshot of the main game view here -->
<!-- ![Game Screenshot](docs/screenshots/game-overview.png) -->

---

## How to Play

### Rules

1. **The Board** — A grid of tiles is generated at the start of each game. Each tile displays a dot value (0–6), similar to a domino pip.

2. **Dominoes** — You are given a set of dominoes, each consisting of two halves. Each half has a dot value that matches a specific tile on the board.

3. **Placement** — Drag a domino from the panel on the right and drop it onto the board. The domino snaps to the pair of tiles whose values match its two halves.

4. **Rotation** — Double-click a domino to rotate it 90°, letting you place it horizontally or vertically.

5. **Constraints** — Coloured overlays on the board mark **constraint groups** — sets of one or more tiles governed by a rule. The rule indicator (a small badge at the bottom-right corner of each group) shows what condition must be met:

   | Indicator | Meaning |
   |-----------|---------|
   | `12`      | **SUM** — the tiles in this group must add up to exactly 12 |
   | `=`       | **EQUAL** — all tiles in this group must have the same value |
   | `!=`      | **NOT EQUAL** — no two tiles in this group may share the same value |
   | `<15`     | **LESS THAN** — the sum of tiles in this group must be less than 15 |
   | `>3`      | **GREATER THAN** — the sum of tiles in this group must be greater than 3 |

6. **Win Condition** — All tiles must be filled **and** every constraint must be satisfied simultaneously to win.

### Controls

| Action | Input |
|--------|-------|
| Pick up / drag a domino | Click and drag |
| Rotate a domino | Double-click |
| Pan the camera | Arrow keys |
| Reset camera | Space |
| Reset all dominos | Reset button (HUD) |
| Return to main menu | Escape |

> **Web / browser note:** Click anywhere on the game canvas first to ensure keyboard controls (arrow keys, Space, Escape) are captured by the game rather than the browser.

---

## Features

### Procedural Level Generation

Every puzzle is uniquely generated from a configurable seed:

- **Snake-path tile placement** — Tiles are placed along a random snake-like path from the centre of the grid outward. A branching probability parameter controls how winding the path is.
- **Noise-driven dot values** — Tile dot values (0–6) are sampled via Godot's `FastNoiseLite` (Simplex Smooth by default). Two sampling strategies are available:
  - *Pure random* — each new tile gets a random value.
  - *Noise-mapped* — noise output is mapped directly to a 0–6 range.
- **Equal-tile retention** — An independent probability controls how often a tile inherits the previous tile's value, producing natural runs of identical numbers.

### Constraint Generation

Constraints are generated after the tile grid is complete:

- Tiles are partitioned into non-overlapping groups using a randomised flood-fill, with group sizes drawn from a configurable normal distribution.
- Each group is assigned a constraint type (SUM, EQUAL, NOT_EQUAL, LESS_THAN, GREATER_THAN) based on tunable probability weights and the **actual generated values** of the tiles in that group — for example, a SUM constraint's target is the real sum of its tiles and a GREATER_THAN target is always below that sum — ensuring every generated puzzle is always solvable.
- Group colours are assigned in HSV space for clear visual separation.

### Fully Configurable Generation Panel

A built-in side panel exposes every generation parameter at runtime — no recompilation needed:

- Seed, grid size, domino count
- Tile path branching probability
- Dot-sampling algorithm and equal-tile probability
- Noise type, frequency, octaves, fractal type, lacunarity, and gain
- Constraint group size distribution (mean, std, min, max)
- Per-type constraint probabilities

<!-- TODO: Add a screenshot of the generation panel here -->
<!-- ![Generation Panel](docs/screenshots/gen-panel.png) -->

### Save & Resume

Progress is automatically saved after every domino placement and reset. When you return to the main menu and start again, the puzzle is restored exactly as you left it — board layout, domino positions, and elapsed time.

### Options

- Resolution presets (1280×720 up to 2560×1440)
- Fullscreen toggle
- VSync toggle
- Music volume
- Settings are persisted between sessions in `user://options.json`

### Background Music

Classical piano pieces from J.S. Bach's *The Well-Tempered Clavier* play continuously as background music. Tracks are drawn from a shuffled, endless queue (no immediate repeats). A brief "Now Playing" notification fades in at the top of the screen when each new track begins.

### Animated Generation

By default, generation happens incrementally — tiles and constraints appear one by one with per-frame delays, giving a satisfying build-up animation. When resuming a saved session, generation is performed instantly.

---

## Technical Overview

Ritz is built with **Godot 4.5** (GDScript, GL Compatibility renderer).

### Architecture

| File | Role |
|------|------|
| `game.gd` | Main game controller — tile/domino/constraint generation, win validation, camera, save/load |
| `game_config.gd` | Plain data object holding all generation parameters |
| `game_signalbus.gd` | Autoload event hub — all inter-system communication goes through signals here |
| `tile.gd` | Static grid cell; holds a `dots_value` (−1 when empty) |
| `domino.gd` | Draggable piece; handles picking, dragging, double-click rotation, and snap-to-tile logic |
| `constraint.gd` | Constraint node — stores a tile group and validates its rule |
| `domino_panel.gd` | Side panel UI that holds the player's domino stack |
| `gen_panel.gd` | Generation parameter panel, built entirely in code via Godot's Control API |
| `game_hud.gd` | In-game HUD — timer, reset button, win overlay |
| `save_manager.gd` | Autoload that reads/writes `user://save_state.json` and `user://options.json` |
| `music_manager.gd` | Autoload that manages background music playback and volume |
| `main_menu.gd` | Main menu scene |
| `options_menu.gd` | Options menu scene |

### Signal Flow

```
Game ──generates──▶ Domino ──domino_generated──▶ GameSignalbus ──▶ DominoPanel
                                                                  
Player drags domino  ──drop──▶ Domino ──domino_assigned──▶ GameSignalbus ──▶ Game
                                                                             │
                                                                    validate_win_conditions()
                                                                             │
                                                                    ──game_won──▶ GameHUD
```

### Coordinate System

- Grid positions: `Vector2i(col, row)`
- Screen positions: grid position × 64 px (each tile is 64×64 px)
- Domino snapping uses a 96 px search radius with an orientation penalty to prefer axis-aligned candidates

### Shader Rendering

Domino pip patterns are rendered entirely on the GPU via `domino.gdshader`. The shader receives `dots1_value` and `dots2_value` integer parameters and draws the corresponding pip layout without any sprite atlas.

---

## Setup & Build

### Prerequisites

| Requirement | Version |
|-------------|---------|
| [Godot Engine](https://godotengine.org/download) | 4.5 or later |

No additional dependencies, plugins, or package managers are required.

### Running the Game (Editor)

1. Clone the repository:
   ```bash
   git clone https://github.com/Javen-W/Ritz.git
   cd Ritz
   ```

2. Open the Godot Editor and import the project by selecting the `project.godot` file.

3. Press **F5** (or click the **Play** button ▶) to run the game from the editor.

### Exporting for Web (itch.io)

The repository includes a pre-configured Web export preset in `export_presets.cfg`.

1. Install the Godot Web export templates via **Editor → Manage Export Templates**.

2. Open **Project → Export…** — the **Web** preset will already be listed.

3. Click **Export Project** (or **Export All**). The output is written to `builds/web/`.

4. Zip the contents of `builds/web/` (all files, with `index.html` at the root):
   ```bash
   cd builds/web && zip -r ../../ritz-web.zip .
   ```

5. Upload `ritz-web.zip` to your itch.io project page, set **Kind of project** to **HTML**, and enable the **Embed in page** option.

> **Note:** `builds/` is excluded from version control (`.gitignore`). Export templates must be installed locally; they are not bundled with the project.

### Exporting for Desktop

1. In the Godot Editor, open **Project → Export…**
2. Add an export preset for your target platform (Windows, Linux, macOS).
3. Configure the export path and click **Export Project**.

> **Note:** The first export for a platform requires the matching Godot export templates. These can be downloaded inside the editor via **Editor → Manage Export Templates**.

### Default Game Settings

| Parameter | Default |
|-----------|---------|
| Grid size | 30 × 30 tiles |
| Domino count | 10 |
| Seed | 777 |
| Noise type | Simplex Smooth |
| Viewport | 1280 × 720 |

All parameters can be changed at runtime via the **Generation Panel** on the right side of the screen.

---

## Project Structure

```
Ritz/
├── project.godot          # Godot project configuration
├── export_presets.cfg     # Export presets (Web/HTML5 for itch.io)
├── game.tscn              # Main game scene
├── game.gd                # Game controller
├── game_config.gd         # Generation config data class
├── game_signalbus.gd      # Global signal hub (autoload)
├── save_manager.gd        # Save/load system (autoload)
├── music_manager.gd       # Music system (autoload)
├── tile.gd / tile.tscn    # Grid tile
├── tile.gdshader          # Tile shader
├── domino.gd / domino.tscn    # Draggable domino piece
├── domino.gdshader            # Pip-rendering shader
├── domino_panel.gd / .tscn    # Player domino stack panel
├── constraint.gd / .tscn      # Constraint node
├── gen_panel.gd               # Generation parameter panel
├── game_hud.gd                # HUD overlay
├── main_menu.gd / .tscn       # Main menu
└── options_menu.gd            # Options menu
```
---

## Credits

Background music is provided by **[Classicals.de](https://www.classicals.de/)** — royalty-free classical recordings released under the **Creative Commons Public Domain Mark 1.0**.
All tracks are from *J.S. Bach – The Well-Tempered Clavier, Book 1*, performed by **Kimiko Ishizaka**.

See [CREDITS.md](CREDITS.md) for the full track listing.

---

## License

This project is licensed under the [PolyForm Noncommercial License 1.0.0](LICENSE.md). The source is public for learning, feedback, and non-commercial use. Commercial publication rights are reserved exclusively by the author.
