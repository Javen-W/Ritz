extends Node2D
class_name Game

@export var MAP_SIZE := 30
@export var NUMBER_DOMINOS := 10
@export var SEED := 777

var rng := RandomNumberGenerator.new()

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
	rng.seed = hash(SEED)
	camera2d.position = Vector2(MAP_SIZE / 2.0, MAP_SIZE / 2.0) * 64.0
	
	generate_tiles()
	generate_constraints()

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
	tile_nodes.add_child(tile)
	grid[pos] = tile
	return tile

# --------------------------------------------------------------
# Generate domino
# --------------------------------------------------------------
func generate_domino(tile1: Tile, tile2: Tile, is_horizontal: bool) -> Domino:
	var domino := domino_scene.instantiate() as Domino
	
	var left_value := rng.randi_range(0, 6)
	var right_value := rng.randi_range(0, 6)
	
	domino.init(tile1.position, tile2.position, left_value, right_value, is_horizontal)
	domino_nodes.add_child(domino)
	dominos.append(domino)
	
	var center = (tile1.position + tile2.position) * 0.5
	domino.position = center + Vector2(500.0, 0.0)
	
	return domino

# --------------------------------------------------------------
# Generate non-overlapping constraints
# --------------------------------------------------------------
func generate_constraints() -> void:
	# Extract all dominos into a tile-state array first
	var remaining_tilestates : Array[Dictionary] = []
	for domino in dominos:
		remaining_tilestates.append({"position": domino.tile_pos1, "value": domino.value_left})
		remaining_tilestates.append({"position": domino.tile_pos2, "value": domino.value_right})
	
	const MIN_SIZE := 1
	const MAX_SIZE := 6
	
	# Populate constraints
	while remaining_tilestates.size() >= MIN_SIZE:
		print(len(remaining_tilestates))
		var size := rng.randi_range(MIN_SIZE, min(MAX_SIZE, remaining_tilestates.size()))
		var group : Array[Dictionary] = []
		
		# Take `size` tiles
		while len(group) < size:
			if remaining_tilestates.is_empty():
				break
			var next_tilestate = remaining_tilestates.pop_back()
			print(next_tilestate["position"] / 64.0)
			group.append(next_tilestate)
		
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
