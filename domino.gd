extends Node2D
class_name Domino

var tile_pos1 : Vector2i
var tile_pos2 : Vector2i
var value_left : int = 0
var value_right : int = 0
var is_horizontal : bool = true

@onready var label_left : Label = $LabelLeft
@onready var label_right : Label = $LabelRight
@onready var background : MeshInstance2D = $Background

func init(pos1: Vector2i, pos2: Vector2i, left: int, right: int, horizontal: bool = true) -> void:
	tile_pos1 = pos1
	tile_pos2 = pos2
	value_left = left
	value_right = right
	is_horizontal = horizontal
	
	label_left.text = str(left)
	label_right.text = str(right)
	
	if not horizontal:
		rotation = deg_to_rad(90)
		# background.scale = Vector2(1.0, 2.0)  # vertical domino
		label_left.rotation = deg_to_rad(-90)
		label_right.rotation = deg_to_rad(-90)
