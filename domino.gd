extends Node2D
class_name Domino

signal domino_released
signal domino_picked

@export var tile1 : Tile = null
@export var tile2 : Tile = null

@export var dots1_value : int = 0
@export var dots2_value : int = 0
@export var is_horizontal : bool = true

@onready var background : MeshInstance2D = $Background
@onready var shader_material : ShaderMaterial = background.material as ShaderMaterial
@onready var mouse_collision : CollisionShape2D = $MouseArea2D/CollisionShape2D
@onready var dots1_collision : CollisionShape2D = $Dots1Area2D/CollisionShape2D
@onready var dots2_collision : CollisionShape2D = $Dots2Area2D/CollisionShape2D

static var selected_domino : Domino = null

var is_picked : bool = false
var entered_tile1s : Array[Tile] = []
var entered_tile2s : Array[Tile] = []

func _ready() -> void:
	update_pips()
	if self.is_horizontal:
		rotate_once()
	add_to_group("dominos")

func init(dots1_val: int, dots2_val: int, horizontal: bool = true) -> void:
	self.dots1_value = dots1_val
	self.dots2_value = dots2_val
	self.is_horizontal = horizontal
	print("Domino init(): dots1_value{0}, dots2_value{1}".format([dots1_val, dots2_val]))

func update_position_to_tiles(t1: Tile, t2: Tile, offset: Vector2) -> bool:
	if t1 != null and t2 != null and t1 != t2:
		var center = (t1.position + t2.position) * 0.5
		self.position = center + offset
		return true
	return false

func update_pips() -> void:
	if shader_material:
		shader_material.set_shader_parameter("dots1_value", self.dots1_value)
		shader_material.set_shader_parameter("dots2_value", self.dots2_value)

func rotate_once() -> void:
	rotate(deg_to_rad(-90.0))

func _unhandled_input(event: InputEvent) -> void:
	if is_picked and event is InputEventMouseMotion:
		var camera = get_viewport().get_camera_2d()
		self.position = camera.get_global_mouse_position() + event.relative

func _on_mouse_area_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	# Mouse in viewport coordinates.
	if event is InputEventMouseButton:
		if event.double_click:
			rotate_once()
		elif event.is_pressed():
			domino_picked.emit()
			# print("Mouse pressed.")
		elif event.is_released() and is_picked:
			domino_released.emit()
			# print("Mouse released.")

func _on_dots_1_area_2d_area_entered(area: Area2D) -> void:
	var tile = area.owner as Tile
	if !entered_tile1s.has(tile):
		entered_tile1s.append(tile)
		# print("Domino dots1 area entered: ", tile)

func _on_dots_2_area_2d_area_entered(area: Area2D) -> void:
	var tile = area.owner as Tile
	if !entered_tile2s.has(tile):
		entered_tile2s.append(tile)
		# print("Domino dots2 area entered: ", tile)

func _on_dots_1_area_2d_area_exited(area: Area2D) -> void:
	var tile = area.owner as Tile
	# call_deferred("_erase_entered_tile1", tile)
	_erase_entered_tile1(tile)

func _on_dots_2_area_2d_area_exited(area: Area2D) -> void:
	var tile = area.owner as Tile
	# call_deferred("_erase_entered_tile2", tile)
	_erase_entered_tile2(tile)

func _erase_entered_tile2(tile: Tile) -> void:
	entered_tile2s.erase(tile)
	if self.tile2 == tile:
		self.tile2.remove_dots()
		self.tile2 = null
	# print("Domino dots2 area exited: ", tile)

func _erase_entered_tile1(tile: Tile) -> void:
	entered_tile1s.erase(tile)
	if self.tile1 == tile:
		self.tile1.remove_dots()
		self.tile1 = null
	# print("Domino dots1 area exited: ", tile)

func _find_nearest_tile(tiles: Array[Tile], dots_pos: Vector2) -> Tile:
	var min_dist = INF
	var min_tile = null
	for t in tiles:
		var new_dist = t.position.distance_to(dots_pos)
		if new_dist <= min_dist:
			min_dist = new_dist
			min_tile = t
	return min_tile

func _on_domino_picked() -> void:
	is_picked = true
	if self.tile1 != null:
		self.tile1.remove_dots()
		self.tile1 = null
	if self.tile2 != null:
		self.tile2.remove_dots()
		self.tile2 = null

func _on_domino_released() -> void:
	is_picked = false
	
	# Select & validate candidate tile1.
	var candidate_tile1 = _find_nearest_tile(entered_tile1s, dots1_collision.global_position)
	if candidate_tile1 == null:
		return
	
	# Select & validate candidate tile2.
	var temp_tile2s = entered_tile2s.duplicate()
	temp_tile2s.erase(candidate_tile1)
	var candidate_tile2 = _find_nearest_tile(temp_tile2s, candidate_tile1.position)
	if candidate_tile2 == null:
		return
	
	# Validate candidate tile distance.
	var tile_dist = candidate_tile1.position.distance_to(candidate_tile2.position)
	if tile_dist != 64.0:
		return
	
	# Validate tile domino emptiness.
	if candidate_tile1.dots_value != -1:
		return
	if candidate_tile2.dots_value != -1:
		return 
	
	# Attempt domino position update.
	var pos_updated = update_position_to_tiles(candidate_tile1, candidate_tile2, Vector2i.ZERO)
	if !pos_updated:
		return
	
	# Successful candidate tile selections.
	self.tile1 = candidate_tile1
	self.tile1.place_dots(self.dots1_value)
	
	self.tile2 = candidate_tile2
	self.tile2.place_dots(self.dots2_value)
	
	# Signal global bus.
	GameSignalbus.emit_domino_assigned(self)
	
	# Debug.
	print("Domino placement successful: ", self.tile1.global_position.snappedf(64.0) / 64.0, " ", self.tile2.global_position.snappedf(64.0) / 64.0)

func _on_domino_selected(domino: Domino) -> void:
	if domino != self:
		mouse_collision.set_deferred("disabled", true)
	else:
		self.selected_domino = domino
		print("Domino selected: ", domino.name)

func _on_domino_deselected() -> void:
	if self.selected_domino != self:
		mouse_collision.set_deferred("disabled", false)
	else:
		self.selected_domino = null
		print("Domino deselected.")

func _on_mouse_area_2d_mouse_entered() -> void:
	if self.selected_domino != null:
		return
	get_tree().call_group("dominos", "_on_domino_selected", self)
	# print("Mouse area2d entered.")

func _on_mouse_area_2d_mouse_exited() -> void:
	if self.selected_domino != self:
		return
	get_tree().call_group("dominos", "_on_domino_deselected")
	# print("Mouse area2d exited.")
