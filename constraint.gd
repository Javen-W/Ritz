extends Node2D
class_name Constraint

enum Type { SUM, EQUAL, LESS_THAN, GREATER_THAN }

var type : Type = Type.SUM
var tiles : Array[Tile] = []
var color : Color = Color(1, 0.5, 0.5, 0.3)
var target_value : int = 0

# In constraint.gd — add this at the top
@onready var overlay : ColorRect = $Overlay
@onready var indicator : Polygon2D = $Indicator

func _ready() -> void:
	if not overlay or not indicator:
		return
		
	overlay.color = color
	indicator.position = Vector2(44, 44)
	
	match type:
		Type.SUM:           indicator.color = Color.WHITE
		Type.EQUAL:         indicator.color = Color.YELLOW
		Type.LESS_THAN:     indicator.color = Color.CYAN
		Type.GREATER_THAN:  indicator.color = Color.MAGENTA
	
	if tiles.is_empty():
		return
	
	var min_pos := Vector2(INF, INF)
	var max_pos := Vector2(-INF, -INF)
	
	for t in tiles:
		min_pos = min_pos.min(t.position)
		max_pos = max_pos.max(t.position)
	
	var size := (max_pos - min_pos) + Vector2(64, 64)
	overlay.size = size
	overlay.position = min_pos
