extends Node2D
class_name Constraint

## Constraint – a win condition applied to a group of adjacent Tiles.
##
## Each constraint covers 1–6 tiles and enforces one of five relationship types
## (SUM, EQUAL, LESS_THAN, GREATER_THAN, NOT_EQUAL) on the player-placed dot
## values.  The constraint is generated procedurally based on the tiles'
## generated_values, then checked at runtime via is_constraint_satisfied().
##
## Visually, each constraint draws a coloured overlay across its tiles and an
## indicator diamond (Polygon2D) that shows the type/target to the player.

enum Type { SUM, EQUAL, LESS_THAN, GREATER_THAN, NOT_EQUAL }

@export var type : Type = Type.SUM
@export var group : Array[Tile] = []
@export var color : Color = Color(1, 0.5, 0.5, 0.3)
@export var target_value : int = -1

@onready var indicator : Polygon2D = $Indicator
@onready var label : Label = $Indicator/Label

func _ready() -> void:
	if group.is_empty():
		return
	
	# Populate tile overlays	
	for t in group:
		var overlay = MeshInstance2D.new()
		overlay.mesh = QuadMesh.new()
		overlay.material = CanvasItemMaterial.new()
		overlay.modulate = color
		overlay.scale = Vector2(64, 64)
		overlay.position = t.position
		add_child(overlay)
	
	# Indicator
	var max_pos := Vector2(-INF, -INF)
	for t in group:
		if t.position.y >= max_pos.y:
			if t.position.x >= max_pos.x:
				max_pos = t.position
	indicator.position = max_pos + Vector2(32, 32)
	indicator.color = color * Color(0.75, 0.75, 0.75, 255)
	
	# Indicator label
	if type == Type.SUM:
		label.text = "" + str(target_value)
	elif type == Type.EQUAL:
		label.text = "="
	elif type == Type.NOT_EQUAL:
		label.text = "!="
	elif type == Type.LESS_THAN:
		label.text = "<" + str(target_value)
	elif type == Type.GREATER_THAN:
		label.text = ">" + str(target_value)
	else:
		label.text = ""

func generate(rng: RandomNumberGenerator, cfg: GameConfig = null) -> void:
	if group.is_empty():
		return

	# Pull thresholds from config or fall back to defaults
	var p_equal    := cfg.prob_equal       if cfg else 0.85
	var p_neq      := cfg.prob_not_equal   if cfg else 0.15
	var p_less     := cfg.prob_less_than   if cfg else 0.10
	var p_greater  := cfg.prob_greater_than if cfg else 0.10

	# Group metrics
	var group_sum := 0
	for t in group:
		group_sum += t.generated_value

	# Determine constraint type (evaluated in priority order)
	if group.size() > 1 and is_group_equal(true) and rng.randf() < p_equal:
		type = Constraint.Type.EQUAL
	elif group.size() > 1 and is_group_notequal(true) and rng.randf() < p_neq:
		type = Constraint.Type.NOT_EQUAL
	elif group_sum <= 10 and rng.randf() < p_less:
		type = Constraint.Type.LESS_THAN
		target_value = rng.randi_range(group_sum + 1, group_sum + 6)
	elif group_sum > 0 and rng.randf() < p_greater:
		type = Constraint.Type.GREATER_THAN
		target_value = rng.randi_range(0, group_sum - 1)
	else:
		type = Constraint.Type.SUM
		target_value = group_sum

	# Determine color
	color = Color.from_hsv(rng.randf(), 0.95, 1.0, 0.35)

func is_constraint_satisfied() -> bool:
	# Calculate group sum value.
	var group_sum = 0
	for tile in self.group:
		# Verify every tile is assigned a domino.
		if tile.dots_value == -1:
			return false
		group_sum += tile.dots_value
	
	# Check group sum against constraint type requirements.
	if type == Type.SUM:
		return group_sum == self.target_value
	elif type == Type.EQUAL:
		return is_group_equal(false)
	elif type == Type.NOT_EQUAL:
		return is_group_notequal(false)
	elif type == Type.LESS_THAN:
		return group_sum < self.target_value
	elif type == Type.GREATER_THAN:
		return group_sum > self.target_value
	else:
		# Error
		return false

func is_group_equal(use_gen: bool = true) -> bool:
	var vals = []
	for t in group:
		if use_gen:
			vals.append(t.generated_value)
		else:
			vals.append(t.dots_value)
	return vals.min() == vals.max()

func is_group_notequal(use_gen: bool = true) -> bool:
	var t_group = group.duplicate()
	var first_tile : Tile = t_group.pop_front()
	var first_val = first_tile.dots_value
	if use_gen:
		first_val = first_tile.generated_value
	for t in t_group:
		if use_gen:
			if t.generated_value == first_val:
				return false
		else:
			if t.dots_value == first_val:
				return false
	return true
