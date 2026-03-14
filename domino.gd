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
var is_from_panel : bool = false
var panel_origin_position : Vector2 = Vector2.ZERO
var panel_origin_parent: Node = null
var is_placed : bool = false

var _mouse_pressed: bool = false
var _press_world_pos: Vector2 = Vector2.ZERO
const DRAG_THRESHOLD_SQ: float = 64.0  # 8 px radius before drag begins

func _ready() -> void:
	update_pips()
	if self.is_horizontal:
		rotate_once()
	add_to_group("dominos")

func init(dots1_val: int, dots2_val: int, horizontal: bool = true) -> void:
	self.dots1_value = dots1_val
	self.dots2_value = dots2_val
	self.is_horizontal = horizontal

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
	if event is InputEventMouseMotion:
		# Start dragging only once the mouse has moved far enough from the press point
		if _mouse_pressed and not is_picked and Domino.selected_domino == self:
			var camera := get_viewport().get_camera_2d()
			if camera.get_global_mouse_position().distance_squared_to(_press_world_pos) > DRAG_THRESHOLD_SQ:
				domino_picked.emit()
		if is_picked:
			var camera := get_viewport().get_camera_2d()
			self.global_position = camera.get_global_mouse_position()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.is_pressed():
		if _mouse_pressed or is_picked:
			_mouse_pressed = false
			if is_picked:
				domino_released.emit()

func _on_mouse_area_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.double_click:
			_mouse_pressed = false  # cancel any pending drag from the first click
			if not is_placed:
				rotate_once()
		elif event.is_pressed():
			if Domino.selected_domino == self:
				_mouse_pressed = true
				_press_world_pos = get_viewport().get_camera_2d().get_global_mouse_position()
				if is_from_panel:
					panel_origin_position = self.position

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
	if self.tile2 == tile and not is_placed:
		self.tile2.remove_dots()
		self.tile2 = null

func _erase_entered_tile1(tile: Tile) -> void:
	entered_tile1s.erase(tile)
	if self.tile1 == tile and not is_placed:
		self.tile1.remove_dots()
		self.tile1 = null

func _find_best_tile_pair() -> Array[Tile]:
	# Union of both overlap lists so we consider all nearby tiles regardless of which
	# dots area detected them — covers slightly off-center and perpendicular drops.
	var candidates: Array[Tile] = entered_tile1s.duplicate()
	for t in entered_tile2s:
		if not candidates.has(t):
			candidates.append(t)

	var best_pair: Array[Tile] = []
	var best_score := INF
	for i in candidates.size():
		var ta := candidates[i]
		if ta.dots_value != -1:
			continue
		for j in candidates.size():
			if i == j:
				continue
			var tb := candidates[j]
			if tb.dots_value != -1:
				continue
			# Accept only grid-adjacent tiles (use tolerance against float rounding)
			if absf(ta.position.distance_to(tb.position) - 64.0) > 0.5:
				continue
			# Score: sum of distances from each dots area to its candidate tile.
			# Lower score = better alignment with the domino's current orientation.
			var score := (dots1_collision.global_position.distance_to(ta.global_position)
						+ dots2_collision.global_position.distance_to(tb.global_position))
			if score < best_score:
				best_score = score
				best_pair = [ta, tb]
	return best_pair

func _on_domino_picked() -> void:
	is_picked = true

	# If this domino is placed on the board, immediately unassign it and
	# convert it back to a panel domino so it returns to the panel on drop.
	if is_placed:
		is_placed = false
		is_from_panel = true
		print("Domino: Unassigned from board [%d|%d]" % [dots1_value, dots2_value])
		var panel := get_tree().root.get_node_or_null("Game/DominoPanel") as DominoPanel
		if panel:
			panel.add_domino_to_stack(self)
	else:
		print("Domino: Picked from panel [%d|%d]" % [dots1_value, dots2_value])

	if self.tile1 != null:
		self.tile1.remove_dots()
		self.tile1 = null
	if self.tile2 != null:
		self.tile2.remove_dots()
		self.tile2 = null

func _on_domino_released() -> void:
	is_picked = false

	var pair := _find_best_tile_pair()
	if pair.is_empty():
		if is_from_panel:
			_return_to_panel()
		return

	var t1 := pair[0]  # receives dots1_value
	var t2 := pair[1]  # receives dots2_value

	# Snap domino position to the center of the tile pair
	if not update_position_to_tiles(t1, t2, Vector2.ZERO):
		if is_from_panel:
			_return_to_panel()
		return

	# Force rotation to match the tile pair axis so domino always looks correct
	var pair_dx := absf(t1.position.x - t2.position.x)
	var pair_dy := absf(t1.position.y - t2.position.y)
	self.rotation = -PI/2 if pair_dy > pair_dx else 0.0

	# Clear overlap lists BEFORE placing dots to prevent area_exited from undoing placement
	entered_tile1s.clear()
	entered_tile2s.clear()

	self.tile1 = t1
	self.tile1.place_dots(self.dots1_value)
	self.tile2 = t2
	self.tile2.place_dots(self.dots2_value)

	is_placed = true
	self.scale = Vector2.ONE
	self.z_index = 3
	is_from_panel = false

	var panel := get_tree().root.get_node("Game/DominoPanel") as DominoPanel
	if panel:
		panel.remove_domino_from_stack(self)

	GameSignalbus.emit_domino_assigned(self)
	print("Domino: Placed [%d|%d] at tiles %s / %s" % [
		dots1_value, dots2_value,
		str(self.tile1.global_position / 64.0) if self.tile1 else "?",
		str(self.tile2.global_position / 64.0) if self.tile2 else "?"
	])

func _return_to_panel() -> void:
	if not is_from_panel:
		return

	entered_tile1s.clear()
	entered_tile2s.clear()
	is_placed = false

	# Restore to saved panel-local slot position
	self.position = panel_origin_position
	print("Domino: Returned to panel [%d|%d]" % [dots1_value, dots2_value])
	GameSignalbus.emit_domino_unassigned(self)

func _on_domino_selected(domino: Domino) -> void:
	if domino != self:
		mouse_collision.set_deferred("disabled", true)
	else:
		self.selected_domino = domino

func _on_domino_deselected() -> void:
	if self.selected_domino != self:
		mouse_collision.set_deferred("disabled", false)
	else:
		self.selected_domino = null

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
