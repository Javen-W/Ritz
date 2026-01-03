extends Node2D
class_name Game

@export var MAP_SIZE := 30
@export var NUMBER_DOMINOS := 10
@export var SEED := 777

var rng := RandomNumberGenerator.new()
@export var dot_noise := FastNoiseLite.new()
var last_value := 0

# Packed scenes — preload to avoid errors
@export var tile_scene: PackedScene = preload("res://tile.tscn")
@export var domino_scene: PackedScene = preload("res://domino.tscn")
@export var constraint_scene: PackedScene = preload("res://constraint.tscn")

# Child nodes
@onready var camera2d : Camera2D = $Camera2D
@onready var tile_nodes : Node2D = $Tiles
@onready var domino_nodes : Node2D = $Dominos
@onready var constraint_nodes : Node2D = $Constraints

# Grid storage
var grid : Dictionary = {} # Vector2i -> Tile
var dominos : Array[Domino] = []
var constraints : Array[Constraint] = []

# Constants
const directions = [
	Vector2i(1, 0), Vector2i(-1, 0),
	Vector2i(0, 1), Vector2i(0, -1)
]

func _ready() -> void:
	# Init game.
	rng.seed = hash(SEED)
	dot_noise.seed = rng.seed
	camera2d.offset = Vector2(MAP_SIZE / 2.0, MAP_SIZE / 2.0) * 64.0
	
	# Connect signals.
	GameSignalbus.domino_assigned.connect(_on_domino_assigned)
	
	# Generate game.
	generate_tiles()
	generate_constraints()

# --------------------------------------------------------------
# Handle signals
# --------------------------------------------------------------
func _on_domino_assigned(domino: Domino) -> void:
	print("Game: Domino assigned.")
	# Check if all conditions have been met for a game win.
	var all_conditions_met = validate_win_conditions()
	print("Game: All conditions met? ", all_conditions_met)
	if all_conditions_met:
		# Game won!
		print("Game: Win!")
		GameSignalbus.emit_game_won()

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
# Generate snake-like path of dominoes (2 tiles each)
# --------------------------------------------------------------
func generate_tiles() -> void:
	var pos := Vector2i(MAP_SIZE / 2, MAP_SIZE / 2)
	
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
		
		# Update next position
		if rng.randf() < 0.5:
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
	tile.generated_value = dot_sample1(pos)
	tile_nodes.add_child(tile)
	grid[pos] = tile
	return tile

func dot_sample1(pos: Vector2i) -> int:
	var noise_sample = 0.5 * (dot_noise.get_noise_2d(pos.x, pos.y) + 1.0) # [-1, 1] -> [0, 1]
	var v := last_value
	if noise_sample < 0.5:
		v = rng.randi_range(0, 6)
	last_value = v
	print(noise_sample, "\t", v)
	return v

func dot_sample2(pos: Vector2i) -> int:
	var noise_sample = 3.5 * (dot_noise.get_noise_2d(pos.x, pos.y) + 1.0) # [-1, 1] -> [0, 7]
	var v = floori(clampf(noise_sample, 0, 6))
	print(noise_sample, "\t", v)
	return v

# --------------------------------------------------------------
# Generate domino
# --------------------------------------------------------------
func generate_domino(tile1: Tile, tile2: Tile, is_horizontal: bool) -> Domino:
	var domino := domino_scene.instantiate() as Domino
	domino.init(tile1.generated_value, tile2.generated_value, is_horizontal)
	domino_nodes.add_child(domino)
	dominos.append(domino)
	domino.update_position_to_tiles(tile1, tile2, Vector2(750.0, 0.0))
	return domino

# --------------------------------------------------------------
# Generate non-overlapping constraints
# --------------------------------------------------------------
func generate_constraints() -> void:
	var remaining_tiles : Array = grid.keys().duplicate()
	
	const MIN_SIZE := 1
	const MAX_SIZE := 6
	
	# Populate constraints
	while remaining_tiles.size() >= MIN_SIZE:
		# print(len(remaining_tiles))
		var size := clampi(roundi(rng.randfn(2.5, 1.5)), MIN_SIZE, MAX_SIZE)
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
		
		if group.size() < MIN_SIZE:
			break
		
		# Occasionally skip singles
		if group.size() == 1:
			if rng.randf() < 0.25:
				continue
		
		# Create constraint
		var c := constraint_scene.instantiate() as Constraint
		c.group = group
		c.generate(rng)
		constraint_nodes.add_child(c)
		constraints.append(c)

func shuffle_array(a: Array) -> Array:
	var t = a.duplicate()
	var b : Array = []
	while !t.is_empty():
		var element = t.pop_at(rng.randi() % t.size())
		b.append(element)
	return b
