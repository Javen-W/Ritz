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

func _ready() -> void:
	rng.seed = hash(SEED)
	camera2d.position = Vector2(MAP_SIZE / 2.0, MAP_SIZE / 2.0) * 64.0
	
	generate_domino_path()
	generate_constraints()

# --------------------------------------------------------------
# Generate snake-like path of dominoes (2 tiles each)
# --------------------------------------------------------------
func generate_domino_path() -> void:
	var directions = [
		Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(0, 1), Vector2i(0, -1)
	]
	
	var pos := Vector2i(MAP_SIZE / 2, MAP_SIZE / 2)
	var placed := 0
	
	while placed < NUMBER_DOMINOS and grid.size() < NUMBER_DOMINOS * 2:
		var horizontal := rng.randi_range(0, 1) == 0
		var dir := Vector2i(1, 0) if horizontal else Vector2i(0, 1)
		
		var pos1 = pos
		var pos2 = pos + dir
		
		# Bounds & collision check
		if not _in_bounds(pos1) or not _in_bounds(pos2):
			break
		if grid.has(pos1) or grid.has(pos2):
			# Try a random direction instead of failing
			pos += directions[rng.randi() % directions.size()]
			continue
			
		# Generate tiles
		var tile1 := generate_tile(pos1)
		var tile2 := generate_tile(pos2)
		
		# Generate domino
		var domino := domino_scene.instantiate() as Domino
		var left := rng.randi_range(0, 6)
		var right := rng.randi_range(0, 6)
		domino.init(tile1.position, tile2.position, left, right, horizontal)
		domino_nodes.add_child(domino)
		dominos.append(domino)
		var center = (tile1.position + tile2.position) * 0.5
		domino.position = center + Vector2(500.0, 0.0)
		
		# Increment placed dominos
		placed += 1
		
		# Choose next direction intelligently
		var candidates : Array[Vector2i] = []
		for d in directions:
			var next = pos2 + d
			var next2 = next + dir
			if _in_bounds(next) and _in_bounds(next2) and !grid.has(next) and !grid.has(next2):
				candidates.append(d)
		
		if candidates.is_empty():
			# Fallback: any free adjacent cell
			for d in directions:
				var next = pos2 + d
				if _in_bounds(next) and !grid.has(next):
					candidates.append(d)
		
		if not candidates.is_empty():
			pos = pos2 + candidates[rng.randi() % candidates.size()]
		else:
			break

func _in_bounds(v: Vector2i) -> bool:
	return v.x >= 0 and v.y >= 0 and v.x < MAP_SIZE and v.y < MAP_SIZE

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
		while len(group) < size and !remaining_tilestates.is_empty():
			group.append(remaining_tilestates.pop_back())
		
		if group.size() < MIN_SIZE:
			break
			
		# Occasionally skip singles
		if group.size() == 1:
			if rng.randf() < 0.7:
				continue
			else:
				group = []  # skip
				continue
		
		# Create constraint
		var c := constraint_scene.instantiate() as Constraint
		c.group = group
		c.generate(rng)
		
		# Add constraint node
		constraint_nodes.add_child(c)
		constraints.append(c)
