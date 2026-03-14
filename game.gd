extends Node2D
class_name Game

enum GameState { GENERATING, ACTIVE, FINISHED }

@export var MAP_SIZE := 30
@export var NUMBER_DOMINOS := 10
@export var SEED := 777

var rng := RandomNumberGenerator.new()
@export var dot_noise := FastNoiseLite.new()
var last_value := 0
var config: GameConfig

# Packed scenes — preload to avoid errors
@export var tile_scene: PackedScene = preload("res://tile.tscn")
@export var domino_scene: PackedScene = preload("res://domino.tscn")
@export var constraint_scene: PackedScene = preload("res://constraint.tscn")

# Child nodes
@onready var camera2d : Camera2D = $Camera2D
@onready var tile_nodes : Node2D = $Tiles
@onready var constraint_nodes : Node2D = $Constraints
@onready var assigned_dominos : Node2D = $AssignedDominos

# Grid storage
var grid : Dictionary = {} # Vector2i -> Tile
# var assigned_dominos : Array[Domino] = []
var constraints : Array[Constraint] = []

# Constants
const directions = [
	Vector2i(1, 0), Vector2i(-1, 0),
	Vector2i(0, 1), Vector2i(0, -1)
]

# Camera control variables
var camera_center: Vector2
const CAMERA_SPEED: float = 200.0  # pixels per second

# Game state
var current_state: GameState = GameState.GENERATING
var elapsed_time: float = 0.0

func _ready() -> void:
	# Use GameConfig defaults so the initial game matches a fresh regenerate()
	config = GameConfig.new()
	_apply_config(config)

	# Position camera at board center; refined to tile centroid after generation
	var board_center = Vector2(config.map_size / 2.0, config.map_size / 2.0) * 64.0
	camera2d.global_position = board_center
	camera_center = camera2d.global_position

	# Connect signals.
	GameSignalbus.domino_assigned.connect(_on_domino_assigned)
	GameSignalbus.domino_unassigned.connect(_on_domino_unassigned)

	# Kick off async game generation.
	_generate_game_async()

# --------------------------------------------------------------
# Game state FSM
# --------------------------------------------------------------
func _set_state(state: GameState) -> void:
	current_state = state
	match state:
		GameState.GENERATING:
			GameSignalbus.interaction_blocked = true
		GameState.ACTIVE:
			GameSignalbus.interaction_blocked = false
			elapsed_time = 0.0
		GameState.FINISHED:
			GameSignalbus.interaction_blocked = true
	GameSignalbus.emit_game_state_changed(state)
	const STATE_NAMES := ["GENERATING", "ACTIVE", "FINISHED"]
	print("Game: State → %s" % STATE_NAMES[state])

# --------------------------------------------------------------
# Config & regeneration
# --------------------------------------------------------------
func _apply_config(cfg: GameConfig) -> void:
	config        = cfg
	SEED           = cfg.seed
	MAP_SIZE       = cfg.map_size
	NUMBER_DOMINOS = cfg.number_dominos
	rng.seed       = hash(cfg.seed)
	dot_noise.noise_type      = cfg.noise_type
	dot_noise.frequency       = cfg.noise_frequency
	dot_noise.fractal_octaves = cfg.noise_octaves
	dot_noise.fractal_type    = cfg.fractal_type
	dot_noise.fractal_lacunarity = cfg.fractal_lacunarity
	dot_noise.fractal_gain    = cfg.fractal_gain
	dot_noise.seed = rng.seed
	last_value = 0
	print("Game: Config applied — seed=%d, map=%d, dominos=%d, algo=%d, p_equal_tile=%.2f" % [
		cfg.seed, cfg.map_size, cfg.number_dominos, cfg.dot_sampling_algorithm, cfg.p_equal_tile
	])

func regenerate(new_config: GameConfig) -> void:
	if current_state == GameState.GENERATING:
		print("Game: Already generating — ignoring regenerate request")
		return
	_set_state(GameState.GENERATING)
	GameSignalbus.emit_generation_update("Clearing previous game...")
	_apply_config(new_config)
	_clear_game()
	var board_center := Vector2(MAP_SIZE / 2.0, MAP_SIZE / 2.0) * 64.0
	camera2d.global_position = board_center
	camera_center = board_center
	_generate_game_async()

func _clear_game() -> void:
	# Clear DominoPanel stack before freeing dominos to avoid stale references
	var panel := $DominoPanel as DominoPanel
	if panel:
		panel.domino_stack.clear()
		panel.current_index = 0
		panel._shuffle_pending = false

	# Free all dominos wherever they live (panel, AssignedDominos, etc.)
	for domino in get_tree().get_nodes_in_group("dominos"):
		domino.queue_free()

	# Free tiles
	for child in tile_nodes.get_children():
		child.queue_free()
	grid.clear()

	# Free constraints
	for child in constraint_nodes.get_children():
		child.queue_free()
	constraints.clear()

	print("Game: Cleared previous game state")

# --------------------------------------------------------------
# Async game generation
# --------------------------------------------------------------
func _generate_game_async() -> void:
	if current_state != GameState.GENERATING:
		_set_state(GameState.GENERATING)
	GameSignalbus.emit_generation_update("Starting generation...")
	await get_tree().process_frame
	
	await _generate_tiles_async()
	
	# Refine camera center to the actual centroid of generated tiles,
	# shifted right so the centroid appears centered in the area left of the GenPanel.
	if grid.size() > 0:
		var centroid := Vector2.ZERO
		for tile_pos: Vector2i in grid.keys():
			centroid += Vector2(tile_pos) * 64.0
		centroid /= float(grid.size())
		var vp_w := get_viewport().get_visible_rect().size.x
		var gen_panel_w := float(GenPanel.PANEL_WIDTH)
		# Usable area center is (vp_w - gen_panel_w)/2 from the left edge,
		# while camera center is vp_w/2 — shift right by the difference.
		var offset_x := gen_panel_w * 0.5 / camera2d.zoom.x
		camera_center = centroid + Vector2(offset_x, 0.0)
		camera2d.global_position = camera_center
		print("Game: Camera set to %s (centroid %s + panel offset %.0fpx)" % [camera_center, centroid, gen_panel_w * 0.5])
	
	GameSignalbus.emit_generation_update("Generating constraints...")
	await get_tree().process_frame
	
	await _generate_constraints_async()
	
	GameSignalbus.emit_generation_update("Generation complete!")
	await get_tree().process_frame
	
	print("Game: Generated %d tiles, %d dominos, %d constraints (seed=%d)" % [
		grid.size(), NUMBER_DOMINOS, constraints.size(), SEED
	])
	_set_state(GameState.ACTIVE)

func _process(delta: float) -> void:
	# Advance the play timer only while the game is active.
	if current_state == GameState.ACTIVE:
		elapsed_time += delta
	
	var camera_input = Vector2.ZERO

	# Don't pan camera while a UI control (e.g. a gen-panel spinbox) has keyboard focus
	if get_viewport().gui_get_focus_owner() == null:
		if Input.is_action_pressed("ui_up"):
			camera_input.y -= 1
		if Input.is_action_pressed("ui_down"):
			camera_input.y += 1
		if Input.is_action_pressed("ui_left"):
			camera_input.x -= 1
		if Input.is_action_pressed("ui_right"):
			camera_input.x += 1
	
	# Move camera if input detected
	if camera_input != Vector2.ZERO:
		# Normalize to prevent diagonal boost
		camera_input = camera_input.normalized()
		var new_pos = camera2d.global_position + camera_input * CAMERA_SPEED * delta
		
		# Apply bounds constraint
		new_pos = _constrain_camera_position(new_pos)
		camera2d.global_position = new_pos
	
	# Reset camera on space
	if Input.is_action_just_pressed("ui_select"):
		camera2d.global_position = camera_center

func _constrain_camera_position(target_pos: Vector2) -> Vector2:
	var board_size = MAP_SIZE * 64.0
	var viewport_size = get_viewport().get_visible_rect().size / camera2d.zoom
	var half_vp_x = viewport_size.x / 2.0
	var half_vp_y = viewport_size.y / 2.0
	
	# Constrain camera so it doesn't go too far off-board
	# Allow panning but prevent showing only empty space
	# Camera should stay within reasonable bounds where at least some board is visible
	
	# Simple approach: just allow full panning from 0 to board_size for camera position
	target_pos.x = clampf(target_pos.x, 0, board_size)
	target_pos.y = clampf(target_pos.y, 0, board_size)
	
	return target_pos

# --------------------------------------------------------------
# Handle signals
# --------------------------------------------------------------
func _on_domino_assigned(domino: Domino) -> void:
	if domino.get_parent():
		domino.get_parent().remove_child(domino)
	assigned_dominos.add_child(domino)
	var placed_count := assigned_dominos.get_child_count()
	print("Game: Domino assigned (%d/%d placed)" % [placed_count, NUMBER_DOMINOS])
	
	# Check if all conditions have been met for a game win.
	var all_conditions_met := validate_win_conditions()
	if all_conditions_met:
		print("Game: 🎉 All constraints satisfied — you win!")
		_set_state(GameState.FINISHED)
		GameSignalbus.emit_game_won()
	elif placed_count == NUMBER_DOMINOS:
		print("Game: All dominos placed but constraints not yet satisfied")

func _on_domino_unassigned(domino: Domino) -> void:
	pass

func validate_win_conditions() -> bool:
	# No empty tiles.
	for tile : Tile in self.grid.values():
		if tile.dots_value == -1:
			return false
	# Constraints.
	for constraint in self.constraints:
		if !constraint.is_constraint_satisfied():
			return false
	# Pass.
	return true

# --------------------------------------------------------------
# Generate snake-like path of dominoes (2 tiles each) — async
# --------------------------------------------------------------
func _generate_tiles_async() -> void:
	var pos := Vector2i(MAP_SIZE / 2, MAP_SIZE / 2)
	var domino_count := 0
	
	while grid.size() < NUMBER_DOMINOS * 2:
		# Set position-1
		var pos1 = pos
		if out_bounds(pos1):
			# Restart position to center of map
			pos = Vector2i(MAP_SIZE / 2, MAP_SIZE / 2)
			continue
		
		# Generate position-2 candidates
		var pos2_candidates : Array[Vector2i] = []
		for d in directions:
			var next = pos1 + d
			if in_bounds(next) and !grid.has(next):
				pos2_candidates.append(next)
		
		# Check conditions of position-1 and position-2 candidates
		if grid.has(pos1) or pos2_candidates.is_empty():
			# Try a random direction instead of failing
			pos += directions[rng.randi() % directions.size()]
			continue
		
		# Set position-2
		var pos2 := pos2_candidates[rng.randi() % pos2_candidates.size()]
		
		# Generate tiles
		var tile1 := generate_tile(pos1)
		var tile2 := generate_tile(pos2)
		
		# Generate domino
		var is_horizontal = abs(pos2 - pos1) == Vector2i(1, 0)
		var domino := generate_domino(tile1, tile2, is_horizontal)
		
		domino_count += 1
		GameSignalbus.emit_generation_update(
			"Generated domino %d / %d..." % [domino_count, NUMBER_DOMINOS]
		)
		# Yield a frame so the overlay updates and tiles become visible incrementally.
		await get_tree().process_frame
		
		# Update next position
		if rng.randf() < config.tile_path_branch_prob:
			pos = pos2 + directions[rng.randi() % directions.size()]
		else:
			pos = pos1 + directions[rng.randi() % directions.size()]

func in_bounds(v: Vector2i) -> bool:
	return v.x >= 0 and v.y >= 0 and v.x < MAP_SIZE and v.y < MAP_SIZE

func out_bounds(v: Vector2i) -> bool:
	return !in_bounds(v)

# --------------------------------------------------------------
# Generate tile
# --------------------------------------------------------------
func generate_tile(pos: Vector2i) -> Tile:
	var tile := tile_scene.instantiate() as Tile
	tile.position = pos * 64.0

	# Equal-tile retention: independent of the sampling algorithm
	if rng.randf() < config.p_equal_tile:
		tile.generated_value = last_value
	else:
		# Sample a new value via the chosen algorithm
		match config.dot_sampling_algorithm:
			GameConfig.DotSamplingAlgorithm.DOT_SAMPLE_2:
				tile.generated_value = _dot_sample_noise(pos)
			_:  # DOT_SAMPLE_1: pure random
				tile.generated_value = rng.randi_range(0, 6)
		last_value = tile.generated_value

	tile_nodes.add_child(tile)
	grid[pos] = tile
	return tile

## DOT_SAMPLE_2: map noise value directly onto 0–6.
func _dot_sample_noise(pos: Vector2i) -> int:
	var n := 3.5 * (dot_noise.get_noise_2d(pos.x, pos.y) + 1.0) # [-1,1] → [0,7]
	return floori(clampf(n, 0, 6))

# --------------------------------------------------------------
# Generate domino
# --------------------------------------------------------------
func generate_domino(tile1: Tile, tile2: Tile, is_horizontal: bool) -> Domino:
	var domino := domino_scene.instantiate() as Domino
	domino.init(tile1.generated_value, tile2.generated_value, is_horizontal)
	GameSignalbus.emit_domino_generated(domino)
	return domino

# --------------------------------------------------------------
# Generate non-overlapping constraints — async
# --------------------------------------------------------------
func _generate_constraints_async() -> void:
	var remaining_tiles : Array = grid.keys().duplicate()

	var grp_min := config.constraint_group_min
	var grp_max := config.constraint_group_max

	var constraint_count := 0

	# Populate constraints
	while remaining_tiles.size() >= grp_min:
		var size := clampi(
			roundi(rng.randfn(config.constraint_group_mean, config.constraint_group_std)),
			grp_min, grp_max
		)
		var group : Array[Tile] = []

		var _search = func(pos: Vector2i, func_ref: Callable) -> void:
			# End cases.
			if len(group) >= size or !remaining_tiles.has(pos):
				return

			# Add tile to group.
			var idx = remaining_tiles.find(pos)
			var tile : Tile = grid[remaining_tiles.pop_at(idx)]
			group.append(tile)

			# Recursive step.
			var shuffled_dirs = shuffle_array(directions)
			for dir in shuffled_dirs:
				var next_pos = pos + dir
				func_ref.call(next_pos, func_ref)

		# Populate group
		var init_pos : Vector2i = remaining_tiles[rng.randi() % remaining_tiles.size()]
		_search.call(init_pos, _search)

		if group.size() < grp_min:
			break

		# Skip small groups with configured probability
		if group.size() <= config.constraint_skip_max_size and rng.randf() < config.constraint_skip_prob:
			print("Game: Skipped constraint group of size %d (skip_prob=%.2f)" % [group.size(), config.constraint_skip_prob])
			continue

		# Create constraint — pass config so thresholds are applied
		var c := constraint_scene.instantiate() as Constraint
		c.group = group
		c.generate(rng, config)
		constraint_nodes.add_child(c)
		constraints.append(c)

		constraint_count += 1
		GameSignalbus.emit_generation_update(
			"Generated constraint %d (%d tiles remaining)..." % [constraint_count, remaining_tiles.size()]
		)
		await get_tree().process_frame

func shuffle_array(a: Array) -> Array:
	var t = a.duplicate()
	var b : Array = []
	while !t.is_empty():
		var element = t.pop_at(rng.randi() % t.size())
		b.append(element)
	return b
