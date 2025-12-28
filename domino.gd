extends Node2D
class_name Domino

signal domino_released

@export var tile1 : Tile = null
@export var tile2 : Tile = null

@export var dots1_value : int = 0
@export var dots2_value : int = 0
@export var is_horizontal : bool = true

@onready var background : MeshInstance2D = $Background
@onready var shader_material : ShaderMaterial = background.material as ShaderMaterial

func _ready() -> void:
	update_pips()
	update_horizontal()
	
func init(dots1_val: int, dots2_val: int, horizontal: bool = true) -> void:
	self.dots1_value = dots1_val
	self.dots2_value = dots2_val
	self.is_horizontal = horizontal
	print("Domino init(): dots1_value{0}, dots2_value{1}".format([dots1_val, dots2_val]))

func update_position_to_tiles(t1: Tile, t2: Tile, offset: Vector2) -> void:
	if t1 != null and t2 != null and t1 != t2:
		print(t1.position.distance_to(t2.position))
		var center = (t1.position + t2.position) * 0.5
		self.position = center + offset

func update_pips() -> void:
	if shader_material:
		shader_material.set_shader_parameter("dots1_value", self.dots1_value)
		shader_material.set_shader_parameter("dots2_value", self.dots2_value)

func update_horizontal() -> void:
	if is_horizontal:
		rotation = 0
		# background.scale = Vector2(2.0, 1.0)
	else:
		rotation = deg_to_rad(-90.0)
		# background.scale = Vector2(1.0, 2.0)

var is_pressed : bool = false
var entered_tile1s : Array[Tile] = []
var entered_tile2s : Array[Tile] = []

func _unhandled_input(event: InputEvent) -> void:
	if is_pressed and event is InputEventMouseMotion:
		var camera = get_viewport().get_camera_2d()
		self.position = camera.get_global_mouse_position() + event.relative

func _on_mouse_area_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	# Mouse in viewport coordinates.
	if event is InputEventMouseButton:
		if event.is_pressed():
			is_pressed = true
			print("Mouse pressed.")
		if event.is_released() and is_pressed:
			is_pressed = false
			domino_released.emit()
			print("Mouse released.")

func _on_dots_1_area_2d_area_entered(area: Area2D) -> void:
	var tile = area.owner as Tile
	if !entered_tile1s.has(tile):
		entered_tile1s.append(tile)
		print("Domino dots1 area entered: ", tile)
		
func _on_dots_2_area_2d_area_entered(area: Area2D) -> void:
	var tile = area.owner as Tile
	if !entered_tile2s.has(tile):
		entered_tile2s.append(tile)
		print("Domino dots2 area entered: ", tile)

func _on_dots_1_area_2d_area_exited(area: Area2D) -> void:
	var tile = area.owner as Tile
	call_deferred("_erase_entered_tile1", tile)

func _on_dots_2_area_2d_area_exited(area: Area2D) -> void:
	var tile = area.owner as Tile
	call_deferred("_erase_entered_tile2", tile)

func _erase_entered_tile2(tile: Tile) -> void:
	entered_tile2s.erase(tile)
	if tile == self.tile2:
		self.tile2 = null
	print("Domino dots2 area exited: ", tile)

func _erase_entered_tile1(tile: Tile) -> void:
	entered_tile1s.erase(tile)
	if tile == self.tile1:
		self.tile1 = null
	print("Domino dots1 area exited: ", tile)

func _find_nearest_tile(tiles: Array[Tile], dots_pos: Vector2) -> Tile:
	var min_dist = INF
	var min_tile = null
	for t in tiles:
		var new_dist = t.position.distance_to(dots_pos)
		if new_dist <= min_dist:
			min_dist = new_dist
			min_tile = t
	return min_tile

func _on_domino_released() -> void:
	self.tile1 = _find_nearest_tile(entered_tile1s, $Dots1Area2D/CollisionShape2D.global_position)
	if self.tile1 != null:
		entered_tile2s.erase(self.tile1)
		self.tile2 = _find_nearest_tile(entered_tile2s, self.tile1.position)
	
	if self.tile1 != null and self.tile2 != null and self.tile1.position.distance_to(self.tile2.position) == 64.0:
		update_position_to_tiles(self.tile1, self.tile2, Vector2i.ZERO)
	print(self.tile1, self.tile2)
