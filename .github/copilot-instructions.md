# Copilot Instructions for Ritz

## Project Overview

**Ritz** is a Godot 4.5 puzzle game based on dominoes. The game:
- Generates a grid of tiles (default 30×30) with random dot values (0–6)
- Pairs adjacent tiles into dominoes (10 dominoes by default)
- Provides constraints (SUM, EQUAL, LESS_THAN, GREATER_THAN, NOT_EQUAL) on tile groups
- Requires players to place dominoes on matching tiles to satisfy all constraints
- Declares victory when all tiles are filled and all constraints are satisfied

The game is fully contained in the root directory (no `src/` subdirectories). Key classes are defined as GDScript classes with `class_name`.

## Development Setup

Godot 4.5 with GL Compatibility renderer. Open `project.godot` in the Godot Editor.

**No external build/test commands exist.** Play the game through the Godot Editor's Play button.

## Architecture Overview

### Core Game Flow

1. **Game** (`game.gd`) - Main game controller
   - Generates the tile grid using a procedural snake-like path algorithm
   - Pairs adjacent tiles into dominoes with random dot values (sampled via Perlin noise)
   - Generates non-overlapping constraint groups on the grid
   - Listens for domino placements and validates win conditions

2. **GameSignalbus** (`game_signalbus.gd`) - Autoload signal hub
   - Centralized event emitter for all game events
   - Signals: `domino_generated`, `domino_assigned`, `domino_unassigned`, `game_won`
   - Added to project as an autoload in `project.godot` (line 20)

3. **Domino** (`domino.gd`) - Interactive draggable piece
   - Represents a pair of tiles (each side holds 0–6 pips/dots)
   - Renders dot values via shader (`domino.gdshader`)
   - Handles user interactions: picking, dragging, double-click rotation
   - Tracks overlapping tiles via Area2D collision detection
   - On release, snaps to the nearest valid tile pair (if conditions met)
   - Emits `domino_assigned` signal to global bus on successful placement

4. **Tile** (`tile.gd`) - Static grid cell
   - Has two states: empty (`dots_value == -1`) or filled with pips
   - Receives `place_dots(value)` calls from placed dominoes
   - Emits `dots_placed` signal when filled

5. **Constraint** (`constraint.gd`) - Win condition for tile groups
   - Manages a group of adjacent tiles and a constraint type (enum)
   - Generates constraint type and target value based on group sum
   - `is_constraint_satisfied()` validates the constraint when checking win conditions

### Coordinate System

- Grid positions use `Vector2i` (e.g., `Vector2i(5, 3)`)
- Screen positions are grid positions × 64 pixels (tile size is 64×64)
- Directions array: `[(1,0), (-1,0), (0,1), (0,-1)]` for adjacency checks

### Layer System (Physics)

Defined in `project.godot` [layer_names]:
- **Layer 1**: "mouse" - domino mouse detection
- **Layer 2**: "tile" - tile collision shapes
- **Layer 3**: "dots" - dots Area2D collision detection

### Noise Sampling

Game uses `FastNoiseLite` for semi-random tile value generation:
- `dot_sample1()` - Primary sampling (default): returns previous value if noise < 0.5, else random 0–6
- `dot_sample2()` - Alternative: maps noise directly to 0–6
- Noise seeded from `SEED` export variable (default 777)

## Key Conventions

### Class Names and Types
- Use `class_name` declarations (all main game classes follow this pattern)
- Use typed exports: `@export var tile_scene: PackedScene`
- Use `@onready` for node references instead of manual `_ready()` assignments

### Node Organization (Scene Tree)

Game scene structure:
- **Game** (root)
  - Camera2D
  - **Tiles** (Node2D) - Container for all Tile instances
  - **Constraints** (Node2D) - Container for all Constraint instances
  - **AssignedDominos** (Node2D) - Container for placed dominoes (dynamically populated)

Dominoes are instantiated during game generation and reparented to AssignedDominos on placement.

### Signal Pattern
- Use `GameSignalbus` for all inter-system communication
- Never call methods directly between Game, Domino, and Constraint
- Emit signals via explicit `emit_*` methods on GameSignalbus (not `signal.emit()` directly)

### Validation Pattern
Win condition validation (in `Game.validate_win_conditions()`):
1. Check all tiles are filled (`dots_value != -1`)
2. Check all constraints are satisfied (`constraint.is_constraint_satisfied()`)
3. If both pass, emit `game_won` signal

### Shader Usage
- `domino.gdshader` receives `dots1_value` and `dots2_value` parameters
- Updated via `shader_material.set_shader_parameter()` calls in `update_pips()`

## Debugging Tips

- **Print statements** are used liberally throughout (`print()` calls in most functions)
- Check Godot's Output panel to trace game flow
- Use `GameSignalbus` signal connections to trace event order
- Grid state is stored in `Game.grid: Dictionary[Vector2i, Tile]`
- All constraints accessible via `Game.constraints: Array[Constraint]`

## Common Tasks

### Adding a New Constraint Type
1. Add enum variant to `Constraint.Type`
2. Update `Constraint.generate()` to set the new type (add probability check)
3. Update `Constraint._ready()` to render the label text
4. Implement validation logic in `Constraint.is_constraint_satisfied()`

### Modifying Tile Generation
- Edit `Game.generate_tiles()` to change the snake-like path algorithm
- Or replace the entire generation with a different approach
- Remember to track positions in `Game.grid` and update `MAP_SIZE` if needed

### Adjusting Difficulty/Randomness
- `Game.SEED` - Change for different random layouts
- `Game.MAP_SIZE` - Grid dimensions
- `Game.NUMBER_DOMINOS` - Domino count
- `Constraint.generate()` - Adjust probability thresholds (e.g., `rng.randf() < 0.15`)

### Changing Domino Placement Rules
- Edit `Domino._on_domino_released()` validation logic
- Key checks: tile distance (currently 64.0), empty tile state, unique tiles
- Modify Area2D overlap tracking if you change collision detection

### Documentation
"When working with Godot game development questions, always search for the latest available documentation using the godot-mcp-docs tools. Start with get_documentation_tree() to understand the documentation structure, then use get_documentation_file() to retrieve specific information about classes, tutorials, or features. Prioritize official Godot documentation over general knowledge when providing Godot-related assistance."