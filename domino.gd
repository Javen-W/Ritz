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
	
func init(pos1: Vector2i, pos2: Vector2i, left_value: int, right_value: int, horizontal: bool = true) -> void:
	self.tile_pos1 = pos1
	self.tile_pos2 = pos2
	self.value_left = left_value
	self.value_right = right_value
	self.is_horizontal = horizontal
	print("Domino init(): value_left={0}, value_right={1}, pos1={2}, pos2={3}".format([value_left, value_right, tile_pos1, tile_pos2]))

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

var is_pressed : bool = false

func _unhandled_input(event: InputEvent) -> void:
	if is_pressed and event is InputEventMouseMotion:
		var camera = get_viewport().get_camera_2d()
		self.position = camera.get_global_mouse_position() + event.relative

func _on_area_2d_mouse_entered() -> void:
	# print("Domino mouse_entered()")
	pass

func _on_area_2d_mouse_exited() -> void:
	# is_pressed = false
	# print("Domino mouse_exited()")
	pass

func _on_area_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	# Mouse in viewport coordinates.
	if event is InputEventMouseButton:
		if event.is_pressed():
			is_pressed = true
			print("Mouse pressed.")
		if event.is_released() and is_pressed:
			is_pressed = false
			print("Mouse released.")
	
