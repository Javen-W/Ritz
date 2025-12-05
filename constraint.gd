extends Node2D
class_name Constraint

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

func generate(rng: RandomNumberGenerator) -> void:
	if group.is_empty():
		return
		
	# Group metrics
	var group_sum = 0
	for t in group:
		print("Constraint Tile: position={0}, value={1}".format([t.position / 64.0, t.value]))
		group_sum += t.value
	
	# Determine constraint type
	if group.size() > 1 and is_equal() and rng.randf() > 0.15:
		type = Constraint.Type.EQUAL
	elif group.size() > 1 and is_notequal() and rng.randf() < 0.15:
		type = Constraint.Type.NOT_EQUAL
	elif group_sum <= 10 and rng.randf() < 0.10:
		type = Constraint.Type.LESS_THAN
		target_value = rng.randi_range(group_sum + 1, group_sum + 6)
	elif group_sum > 0 and rng.randf() < 0.10:
		type = Constraint.Type.GREATER_THAN
		target_value = rng.randi_range(0, group_sum - 1)
	else:
		type = Constraint.Type.SUM
		target_value = group_sum
	
	# Determine color
	color = Color.from_hsv(rng.randf(), 0.95, 1.0, 0.35)

func is_equal() -> bool:
	var vals = []
	for t in group:
		vals.append(t.value)
	return vals.min() == vals.max()

func is_notequal() -> bool:
	var t_group = group.duplicate()
	var first_val = t_group.pop_front().value
	for t in t_group:
		if t.value == first_val:
			return false
	return true
		
