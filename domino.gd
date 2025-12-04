extends Node2D
class_name Domino

@export var tile_pos1 : Vector2i
@export var tile_pos2 : Vector2i
@export var value_left : int = 0
@export var value_right : int = 0
@export var is_horizontal : bool = true

@onready var background : MeshInstance2D = $Background
@onready var shader_material : ShaderMaterial = background.material as ShaderMaterial

func _ready() -> void:
	update_pips()
	update_horizontal()

func init(pos1: Vector2i, pos2: Vector2i, left: int, right: int, horizontal: bool = true) -> void:
	tile_pos1 = pos1
	tile_pos2 = pos2
	value_left = left
	value_right = right
	is_horizontal = horizontal
	print("Domino init(): value_left={0}, value_right={1}".format([value_left, value_right]))

func update_pips() -> void:
	if shader_material:
		shader_material.set_shader_parameter("left_value", value_left)
		shader_material.set_shader_parameter("right_value", value_right)

func update_horizontal() -> void:
	if is_horizontal:
		rotation = 0
		# background.scale = Vector2(2.0, 1.0)
	else:
		rotation = deg_to_rad(-90.0)
		# background.scale = Vector2(1.0, 2.0)
