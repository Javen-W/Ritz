extends Node2D
class_name Constraint

enum Type { SUM, EQUAL, LESS_THAN, GREATER_THAN }

@export var type : Type = Type.SUM
@export var group : Array[Dictionary] = []
@export var color : Color = Color(1, 0.5, 0.5, 0.3)
@export var target_value : int = 0

var rng : RandomNumberGenerator = null

@onready var indicator : Polygon2D = $Indicator
@onready var label : Label = $Indicator/Label

func _ready() -> void:
	if group.is_empty():
		return
	
	# Group metrics
	var group_sum = 0
	var group_min = INF
	var group_max = -INF
	
	# Populate tile overlays	
	for t in group:
		var overlay = MeshInstance2D.new()
		overlay.mesh = QuadMesh.new()
		overlay.material = CanvasItemMaterial.new()
		overlay.modulate = color
		overlay.scale = Vector2(64, 64)
		overlay.position = to_local(t["position"])
		add_child(overlay)
		
		group_sum += t["value"]
		group_min = min(group_min, t["value"])
		group_max = max(group_max, t["value"])
	
	# Indicator
	var max_pos := Vector2(-INF, -INF)
	for t in group:
		max_pos = max_pos.max(t.position)
	indicator.position = max_pos + Vector2(32, 32)
	indicator.color = color * Color(0.75, 0.75, 0.75, 255)
	
	# Indicator label
	if type == Type.SUM:
		target_value = group_sum
		label.text = "" + str(target_value)
	elif type == Type.EQUAL:
		label.text = "="
	elif type == Type.LESS_THAN:
		target_value = rng.randi_range(group_sum + 1, group_sum + 7)
		label.text = "<" + str(target_value)
	elif type == Type.GREATER_THAN:
		target_value = rng.randi_range(0, group_sum - 1)
		label.text = ">" + str(target_value)
	else:
		label.text = ""
