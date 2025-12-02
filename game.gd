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

# Camera
@onready var camera2d : Camera2D = $Camera2D

# Grid storage
var grid : Dictionary = {}                    # Vector2i -> Tile
var dominoes : Array[Dictionary] = []         # Just data
var constraints : Array[Constraint] = []

func _ready() -> void:
	rng.seed = hash(SEED)
	camera2d.position = Vector2(MAP_SIZE / 2, MAP_SIZE / 2) * 64
	
	generate_domino_path()
	place_domino_instances()
	# generate_constraints()

# --------------------------------------------------------------
# 1. Generate snake-like path of dominoes (2 tiles each)
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
			
		# Place tiles
		var tile1 := tile_scene.instantiate() as Tile
		var tile2 := tile_scene.instantiate() as Tile
		
		tile1.position = pos1 * 64
		tile2.position = pos2 * 64
		
		add_child(tile1)
		add_child(tile2)
		
		grid[pos1] = tile1
		grid[pos2] = tile2
		
		# Store domino info
		var left := rng.randi_range(0, 6)
		var right := rng.randi_range(0, 6)
		dominoes.append({
			"pos1": pos1,
			"pos2": pos2,
			"left": left,
			"right": right,
			"horizontal": horizontal
		})
		
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
# 2. Place actual Domino nodes
# --------------------------------------------------------------
func place_domino_instances() -> void:
	for data in dominoes:
		var dom := domino_scene.instantiate() as Domino
		var center = (grid[data.pos1].position + grid[data.pos2].position) * 0.5
		dom.position = center + Vector2(500.0, 0.0)
		add_child(dom)
		dom.init(data.left, data.right, data.horizontal)

# --------------------------------------------------------------
# 3. Generate non-overlapping constraints
# --------------------------------------------------------------
func generate_constraints() -> void:
	# Extract all tiles into a generic Array first
	var remaining_tiles : Array = grid.values().duplicate()
	remaining_tiles.shuffle()
	
	const MIN_SIZE := 2
	const MAX_SIZE := 7
	
	while remaining_tiles.size() >= MIN_SIZE:
		var size := rng.randi_range(MIN_SIZE, min(MAX_SIZE, remaining_tiles.size()))
		var group : Array[Tile] = []
		
		# Take `size` tiles
		for i in size:
			if remaining_tiles.is_empty():
				break
			group.append(remaining_tiles.pop_back() as Tile)
		
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
		c.tiles = group
		c.color = Color.from_hsv(rng.randf(), 0.85, 1.0, 0.35)
		
		if group.size() == 1:
			c.type = Constraint.Type.LESS_THAN if rng.randf() < 0.5 else Constraint.Type.GREATER_THAN
			c.target_value = rng.randi_range(0, 6)
		elif rng.randf() < 0.3:
			c.type = Constraint.Type.EQUAL
			c.target_value = rng.randi_range(0, 6)
		else:
			c.type = Constraint.Type.SUM
			# Optional: pre-calculate real sum for real hints later
			c.target_value = 0
		
		add_child(c)
		constraints.append(c)
		
		# Rebuild overlay (calls _ready again indirectly)
		c._ready()
