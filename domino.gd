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

static var selected_domino : Domino = null

var is_picked : bool = false
var is_from_panel : bool = false
var panel_origin_position : Vector2 = Vector2.ZERO
var is_placed : bool = false

var _mouse_pressed: bool = false
var _press_world_pos: Vector2 = Vector2.ZERO
const DRAG_THRESHOLD_SQ: float = 64.0  # 8 px radius before drag begins

# Assignment: search whole grid within this world-space radius of the domino centre.
const ASSIGN_SEARCH_RADIUS: float = 96.0
# Extra distance cost added per 90° of rotation needed to match a candidate pair.
# Keeps same-axis pairs preferred when they are within this many px further away.
const ASSIGN_ORIENT_PENALTY: float = 32.0

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
			rotate_once()           # cosmetic; tile assignments are unaffected
		elif event.is_pressed():
			if Domino.selected_domino == self:
				_mouse_pressed = true
				_press_world_pos = get_viewport().get_camera_2d().get_global_mouse_position()
				if is_from_panel:
					panel_origin_position = self.position

func _on_dots_1_area_2d_area_entered(_area: Area2D) -> void: pass
func _on_dots_1_area_2d_area_exited(_area: Area2D) -> void: pass
func _on_dots_2_area_2d_area_entered(_area: Area2D) -> void: pass
func _on_dots_2_area_2d_area_exited(_area: Area2D) -> void: pass

# Search the whole game grid for the nearest valid adjacent empty tile pair.
# Scores by distance to pair centre + orientation mismatch penalty.
# Correctly handles 180° assignment (rot=0 vs rot=PI, rot=PI/2 vs rot=-PI/2).
func _try_assign_to_nearest_tiles() -> bool:
	var game := get_tree().root.get_node("Game") as Game
	if not game:
		return false

	var domino_center := self.global_position
	var current_rot  := self.rotation

	var best_t1: Tile  = null
	var best_t2: Tile  = null
	var best_rot: float = 0.0
	var best_score     := INF

	for raw_pos in game.grid.keys():
		var gpos := raw_pos as Vector2i
		# Only check right (+x) and down (+y) neighbours — avoids duplicate pairs.
		for dir in [Vector2i(1, 0), Vector2i(0, 1)]:
			var gpos2 := gpos + dir
			if not game.grid.has(gpos2):
				continue
			var ta: Tile = game.grid[gpos]
			var tb: Tile = game.grid[gpos2]
			if ta.dots_value != -1 or tb.dots_value != -1:
				continue  # already occupied

			var pair_center := (ta.position + tb.position) * 0.5
			var dist := domino_center.distance_to(pair_center)
			if dist > ASSIGN_SEARCH_RADIUS:
				continue

			# Two ordered assignments per pair, each implying a distinct rotation:
			#   Horizontal (dir=(1,0)):  ta=LEFT,  tb=RIGHT
			#     rot= 0   → dots1 points LEFT  → ta receives dots1_value
			#     rot= PI  → dots1 points RIGHT → tb receives dots1_value
			#   Vertical   (dir=(0,1)):  ta=TOP,   tb=BOTTOM
			#     rot= PI/2  → dots1 points UP   → ta receives dots1_value
			#     rot=-PI/2  → dots1 points DOWN → tb receives dots1_value
			var options: Array
			if dir == Vector2i(1, 0):
				options = [[ta, tb, 0.0], [tb, ta, PI]]
			else:
				options = [[ta, tb, PI/2.0], [tb, ta, -PI/2.0]]

			for opt in options:
				var req_rot: float = opt[2]
				# angle_difference returns the shortest signed delta in (-PI, PI]
				var rot_delta := absf(angle_difference(current_rot, req_rot))
				# Score: distance is primary; orientation mismatch adds a small penalty
				# (one 90° step costs ASSIGN_ORIENT_PENALTY px of "virtual distance")
				var score := dist + rot_delta / (PI / 2.0) * ASSIGN_ORIENT_PENALTY
				if score < best_score:
					best_score = score
					best_t1    = opt[0]
					best_t2    = opt[1]
					best_rot   = req_rot

	if best_t1 == null:
		print("Domino: No valid tile pair within %.0fpx" % ASSIGN_SEARCH_RADIUS)
		return false

	# Snap position and orientation
	update_position_to_tiles(best_t1, best_t2, Vector2.ZERO)
	self.rotation = best_rot

	self.tile1 = best_t1
	self.tile1.place_dots(self.dots1_value)
	self.tile2 = best_t2
	self.tile2.place_dots(self.dots2_value)

	is_placed    = true
	self.scale   = Vector2.ONE
	self.z_index = 3
	is_from_panel = false

	var panel := get_tree().root.get_node("Game/DominoPanel") as DominoPanel
	if panel:
		panel.remove_domino_from_stack(self)

	GameSignalbus.emit_domino_assigned(self)
	print("Domino: Placed [%d|%d] → %s / %s (rot=%.0f°)" % [
		dots1_value, dots2_value,
		str(best_t1.position / 64.0), str(best_t2.position / 64.0),
		rad_to_deg(best_rot)
	])
	return true

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
	if not _try_assign_to_nearest_tiles():
		if is_from_panel:
			_return_to_panel()

func _return_to_panel() -> void:
	if not is_from_panel:
		return
	is_placed = false
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
