extends Node2D
class_name Constraint

enum Type { SUM, EQUAL, LESS_THAN, GREATER_THAN }

var type : Type = Type.SUM
var group : Array[Dictionary] = []
var color : Color = Color(1, 0.5, 0.5, 0.3)
var target_value : int = 0

@onready var indicator : Polygon2D = $Indicator

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
		overlay.position = to_local(t["position"])
		add_child(overlay)
	
	# Indicator
	var max_pos := Vector2(-INF, -INF)
	for t in group:
		max_pos = max_pos.max(t.position)
	indicator.position = max_pos + Vector2(32, 32)
	indicator.color = color * Color(0.75, 0.75, 0.75, 255)
