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
	rotate(deg_to_rad(90.0)) # (Negative -> CCW).

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
			_mouse_pressed = false
			if is_placed:
				_rotate_placed_domino()
			else:
				rotate_once()
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

# Returns the rotation that places dots1 visually over t1 and dots2 over t2.
# Derived from: dots1 local (-48,0) rotated by r gives offset (-48·cos r, -48·sin r).
# For that to point toward t1: (-cos r, -sin r) ∝ (t1 - t2).
func _rotation_for_pair(t1_pos: Vector2, t2_pos: Vector2) -> float:
	var dx := t1_pos.x - t2_pos.x
	var dy := t1_pos.y - t2_pos.y
	if absf(dx) > absf(dy):
		return 0.0 if dx < 0 else PI       # t1 left → 0°; t1 right → 180°
	else:
		return PI/2.0 if dy < 0 else -PI/2.0  # t1 above → 90°; t1 below → -90°

# Called on double-click when the domino is already placed on a tile pair.
# Phase 1: try to pivot to a perpendicular adjacent pair that shares one current tile.
# Phase 2: if none available, flip 180° on the same pair (swap dots1↔dots2 assignment).
func _rotate_placed_domino() -> void:
	var game := get_tree().root.get_node("Game") as Game
	if not game or tile1 == null or tile2 == null:
		rotate_once()
		return

	var is_h := absf(tile1.position.x - tile2.position.x) > absf(tile1.position.y - tile2.position.y)
	var pos1  := Vector2i(roundi(tile1.position.x / 64.0), roundi(tile1.position.y / 64.0))
	var pos2  := Vector2i(roundi(tile2.position.x / 64.0), roundi(tile2.position.y / 64.0))

	# Directions perpendicular to the current pair axis
	var perp_dirs: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, -1)] if is_h \
	                               else [Vector2i(1, 0), Vector2i(-1, 0)]

	# Find the closest valid perpendicular pair that shares one current tile.
	# anchor = the tile that stays; new_tile = the incoming neighbour.
	var best_t1: Tile = null
	var best_t2: Tile = null
	var best_dist := INF

	for anchor_pos in [pos1, pos2]:
		var anchor_tile: Tile = game.grid.get(anchor_pos)
		var anchor_is_t1 := (anchor_tile == tile1)
		for dir in perp_dirs:
			var new_pos := anchor_pos + dir
			if not game.grid.has(new_pos):
				continue
			var new_tile: Tile = game.grid[new_pos]
			if new_tile.dots_value != -1:
				continue  # occupied by another domino
			# Build the candidate (t1, t2) so tile1 always carries dots1_value
			var cand_t1: Tile = anchor_tile if anchor_is_t1 else new_tile
			var cand_t2: Tile = new_tile    if anchor_is_t1 else anchor_tile
			var pair_center := (cand_t1.position + cand_t2.position) * 0.5
			var dist := self.global_position.distance_to(pair_center)
			if dist < best_dist:
				best_dist = dist
				best_t1   = cand_t1
				best_t2   = cand_t2

	if best_t1 != null:
		# ── Phase 1: pivot to perpendicular pair ──────────────────────────────
		tile1.remove_dots()
		tile2.remove_dots()
		tile1 = best_t1
		tile2 = best_t2
		tile1.place_dots(dots1_value)
		tile2.place_dots(dots2_value)
		update_position_to_tiles(tile1, tile2, Vector2.ZERO)
		self.rotation = _rotation_for_pair(tile1.position, tile2.position)
		print("Domino: Pivoted to perpendicular pair [%d|%d] → %s / %s" % [
			dots1_value, dots2_value,
			str(tile1.position / 64.0), str(tile2.position / 64.0)
		])
	else:
		# ── Phase 2: 180° flip — swap dots assignment on the same pair ────────
		tile1.place_dots(dots2_value)
		tile2.place_dots(dots1_value)
		var old_t1 := tile1
		tile1 = tile2   # tile1 now points to what was tile2
		tile2 = old_t1  # tile2 now points to what was tile1
		# Position is unchanged (same two tiles); only rotation needs updating
		self.rotation = _rotation_for_pair(tile1.position, tile2.position)
		print("Domino: Flipped 180° [%d|%d] → %s / %s" % [
			dots1_value, dots2_value,
			str(tile1.position / 64.0), str(tile2.position / 64.0)
		])

	# Re-emit so game.gd re-checks win conditions
	GameSignalbus.emit_domino_assigned(self)

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
			var gpos2 : Vector2i = gpos + dir
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

			var options: Array
			if dir == Vector2i(1, 0):
				options = [[ta, tb], [tb, ta]]
			else:
				options = [[ta, tb], [tb, ta]]

			for opt in options:
				var t1_cand: Tile = opt[0]
				var t2_cand: Tile = opt[1]
				var req_rot := _rotation_for_pair(t1_cand.position, t2_cand.position)
				# angle_difference returns the shortest signed delta in (-PI, PI]
				var rot_delta := absf(angle_difference(current_rot, req_rot))
				# Score: distance is primary; orientation mismatch adds a small penalty
				# (one 90° step costs ASSIGN_ORIENT_PENALTY px of "virtual distance")
				var score := dist + rot_delta / (PI / 2.0) * ASSIGN_ORIENT_PENALTY
				if score < best_score:
					best_score = score
					best_t1    = t1_cand
					best_t2    = t2_cand
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
