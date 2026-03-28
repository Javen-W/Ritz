extends Node2D

## MainMenu – default scene shown before entering the game.
##
## Features:
##  • Live 2D background: procedurally generated tiles + constraints with a
##    slowly-panning camera.  No DominoPanel or GenPanel visible.
##  • Play / Options / Exit buttons.
##  • Version + author label.
##  • Background music via MusicManager (autoload).
##  • Visual button highlighting + SFX via MusicManager.setup_button().
##  • Save-state aware: resumes last game if a save exists.

const VERSION: String = "v0.1.0"
const AUTHOR: String  = "Javen W."

# Background generation settings
const BG_MAP_SIZE:     int   = 35
const BG_NUM_DOMINOS:  int   = 250
const BG_TILE_SIZE:    float = 64.0

# Camera pan
const CAM_SPEED_MIN:   float = 18.0
const CAM_SPEED_MAX:   float = 32.0
const CAM_RESET_DELAY: float = 18.0   # seconds between full resets

# Preloaded scenes used for the background
var _tile_scene:       PackedScene = preload("res://scenes/tile.tscn")
var _constraint_scene: PackedScene = preload("res://scenes/constraint.tscn")

# Background world nodes
var _bg_camera:      Camera2D
var _bg_tiles:       Node2D
var _bg_constraints: Node2D

# Background generation state
var _bg_rng:       RandomNumberGenerator
var _bg_config:    GameConfig
var _bg_grid:      Dictionary   # Vector2i -> Tile
var _bg_last_val:  int = 0
var _bg_generating: bool = false
# Set to true when leaving the scene so in-flight coroutines abort cleanly.
var _bg_stop: bool = false

# Camera pan state
var _cam_dir:      Vector2 = Vector2.RIGHT
var _cam_speed:    float   = 24.0
var _cam_reset_t:  float   = 0.0
var _cam_center:   Vector2 = Vector2.ZERO

# UI overlay (CanvasLayer) and options panel
var _ui_layer:      CanvasLayer
var _options_menu:  OptionsMenu

const _directions: Array = [
	Vector2i(1, 0), Vector2i(-1, 0),
	Vector2i(0, 1), Vector2i(0, -1)
]


func _ready() -> void:
	# Background world (tiles + constraints rendered by the Node2D camera)
	_bg_camera = Camera2D.new()
	_bg_camera.zoom = Vector2(0.75, 0.75)
	add_child(_bg_camera)

	_bg_tiles = Node2D.new()
	add_child(_bg_tiles)

	_bg_constraints = Node2D.new()
	add_child(_bg_constraints)

	# Build CanvasLayer UI on top
	_build_ui_layer()

	# Start first background generation cycle
	_start_new_bg_cycle()


# ── Background Generation ───────────────────────────────────────────────────

func _start_new_bg_cycle() -> void:
	_clear_bg()
	_bg_rng = RandomNumberGenerator.new()
	_bg_rng.randomize()

	_bg_config = GameConfig.new()
	_bg_config.seed          = _bg_rng.randi()
	_bg_config.map_size      = BG_MAP_SIZE
	_bg_config.number_dominos = BG_NUM_DOMINOS
	_bg_config.p_equal_tile  = _bg_rng.randf_range(0.2, 0.7)
	_bg_config.tile_path_branch_prob = _bg_rng.randf_range(0.3, 0.7)

	_bg_rng.seed = hash(_bg_config.seed)
	_bg_grid = {}
	_bg_last_val = 0

	# Pick random starting camera position near board center
	var board_px := float(BG_MAP_SIZE) * BG_TILE_SIZE
	_cam_center = Vector2(board_px * 0.5, board_px * 0.5)
	_bg_camera.global_position = _cam_center

	# Random pan direction and speed
	var angle := _bg_rng.randf_range(0.0, TAU)
	_cam_dir   = Vector2(cos(angle), sin(angle))
	_cam_speed = _bg_rng.randf_range(CAM_SPEED_MIN, CAM_SPEED_MAX)
	_cam_reset_t = 0.0

	_bg_generating = true
	_bg_stop = false
	_generate_bg_async()


func _clear_bg() -> void:
	for child in _bg_tiles.get_children():
		child.queue_free()
	for child in _bg_constraints.get_children():
		child.queue_free()
	_bg_grid.clear()


func _generate_bg_async() -> void:
	if _bg_stop or not is_inside_tree():
		return
	await get_tree().process_frame
	if _bg_stop or not is_inside_tree():
		return
	await _generate_bg_tiles_async()
	if _bg_stop or not is_inside_tree():
		return
	await get_tree().process_frame
	if _bg_stop or not is_inside_tree():
		return
	await _generate_bg_constraints_async()
	_bg_generating = false
	print("MainMenu: Background generation complete (%d tiles)" % _bg_grid.size())


func _generate_bg_tiles_async() -> void:
	var pos := Vector2i(BG_MAP_SIZE / 2, BG_MAP_SIZE / 2)
	var placed := 0
	while placed < BG_NUM_DOMINOS:
		var pos1 := pos
		if not _bg_in_bounds(pos1):
			pos = Vector2i(BG_MAP_SIZE / 2, BG_MAP_SIZE / 2)
			continue

		var candidates: Array[Vector2i] = []
		for d in _directions:
			var next: Vector2i = pos1 + d
			if _bg_in_bounds(next) and not _bg_grid.has(next):
				candidates.append(next)

		if _bg_grid.has(pos1) or candidates.is_empty():
			pos += _directions[_bg_rng.randi() % _directions.size()]
			continue

		var pos2: Vector2i = candidates[_bg_rng.randi() % candidates.size()]

		_generate_bg_tile(pos1)
		_generate_bg_tile(pos2)
		placed += 1

		if _bg_stop or not is_inside_tree():
			return
		await get_tree().process_frame
		if _bg_stop or not is_inside_tree():
			return

		if _bg_rng.randf() < _bg_config.tile_path_branch_prob:
			pos = pos2 + _directions[_bg_rng.randi() % _directions.size()]
		else:
			pos = pos1 + _directions[_bg_rng.randi() % _directions.size()]


func _generate_bg_tile(grid_pos: Vector2i) -> void:
	var tile := _tile_scene.instantiate() as Tile
	tile.position = Vector2(grid_pos) * BG_TILE_SIZE

	# Assign random dot value and immediately display it
	var v: int
	if _bg_rng.randf() < _bg_config.p_equal_tile:
		v = _bg_last_val
	else:
		v = _bg_rng.randi_range(0, 6)
	tile.generated_value = v
	tile.place_dots(v)
	_bg_last_val = v

	_bg_tiles.add_child(tile)
	_bg_grid[grid_pos] = tile


func _generate_bg_constraints_async() -> void:
	var remaining: Array = _bg_grid.keys().duplicate()
	while remaining.size() >= 2:
		var size: int = clampi(roundi(_bg_rng.randfn(2.5, 1.5)), 1, 4)
		var group: Array[Tile] = []

		var search := func(p: Vector2i, fn: Callable) -> void:
			if group.size() >= size or not remaining.has(p):
				return
			var idx := remaining.find(p)
			group.append(_bg_grid[remaining.pop_at(idx)])
			for d: Vector2i in _bg_rng_shuffle(_directions.duplicate()):
				fn.call(p + d, fn)

		var init: Vector2i = remaining[_bg_rng.randi() % remaining.size()]
		search.call(init, search)

		if group.size() < 1:
			break

		var c := _constraint_scene.instantiate() as Constraint
		c.group = group
		c.generate(_bg_rng, _bg_config)
		_bg_constraints.add_child(c)

		if _bg_stop or not is_inside_tree():
			return
		await get_tree().process_frame
		if _bg_stop or not is_inside_tree():
			return


func _bg_in_bounds(v: Vector2i) -> bool:
	return v.x >= 0 and v.y >= 0 and v.x < BG_MAP_SIZE and v.y < BG_MAP_SIZE


func _bg_rng_shuffle(arr: Array) -> Array:
	var out: Array = []
	while not arr.is_empty():
		out.append(arr.pop_at(_bg_rng.randi() % arr.size()))
	return out


# ── Per-Frame ────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	_cam_reset_t += delta

	# Pan camera
	var board_px  := float(BG_MAP_SIZE) * BG_TILE_SIZE
	_bg_camera.global_position += _cam_dir * _cam_speed * delta

	# Bounce direction if camera goes out of reasonable range
	var cam_pos := _bg_camera.global_position
	if cam_pos.x < 0.0 or cam_pos.x > board_px:
		_cam_dir.x *= -1.0
	if cam_pos.y < 0.0 or cam_pos.y > board_px:
		_cam_dir.y *= -1.0

	# Full reset after delay (or when generation is long finished)
	if _cam_reset_t >= CAM_RESET_DELAY and not _bg_generating:
		_start_new_bg_cycle()


# ── UI Construction ─────────────────────────────────────────────────────────

func _build_ui_layer() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 10
	add_child(_ui_layer)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_layer.add_child(root)

	# Semi-transparent dark gradient behind the UI so tiles don't compete with text
	var overlay := ColorRect.new()
	overlay.color = Color(0.04, 0.05, 0.09, 0.62)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(overlay)

	# Centre panel
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	vbox.custom_minimum_size = Vector2(300, 0)
	center.add_child(vbox)

	# Game title
	var title := Label.new()
	title.text = "RITZ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0, 1.0))
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "A Domino Puzzle"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.65, 0.75, 0.95, 0.9))
	vbox.add_child(subtitle)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	vbox.add_child(spacer)

	# Play button
	var play_btn := Button.new()
	play_btn.text = "Play"
	play_btn.icon = load("res://assets/icons/icon_play.svg")
	# play_btn.add_theme_constant_override("icon_max_width", 22)
	play_btn.focus_mode = Control.FOCUS_NONE
	play_btn.custom_minimum_size = Vector2(240, 52)
	play_btn.add_theme_font_size_override("font_size", 22)
	play_btn.pressed.connect(_on_play_pressed)
	MusicManager.setup_button(play_btn,
		Color(0.12, 0.40, 0.22, 0.92),
		Color(0.18, 0.58, 0.30, 0.97))
	vbox.add_child(play_btn)

	# Options button
	var options_btn := Button.new()
	options_btn.text = "Options"
	options_btn.icon = load("res://assets/icons/icon_gear.svg")
	# options_btn.add_theme_constant_override("icon_max_width", 18)
	options_btn.focus_mode = Control.FOCUS_NONE
	options_btn.custom_minimum_size = Vector2(240, 44)
	options_btn.add_theme_font_size_override("font_size", 18)
	options_btn.pressed.connect(_on_options_pressed)
	MusicManager.setup_button(options_btn)
	vbox.add_child(options_btn)

	# Exit button — hidden on web (quitting a browser tab is not meaningful)
	if not OS.has_feature("web"):
		var exit_btn := Button.new()
		exit_btn.text = "Exit"
		exit_btn.icon = load("res://assets/icons/icon_close.svg")
		# exit_btn.add_theme_constant_override("icon_max_width", 16)
		exit_btn.focus_mode = Control.FOCUS_NONE
		exit_btn.custom_minimum_size = Vector2(240, 44)
		exit_btn.add_theme_font_size_override("font_size", 18)
		exit_btn.pressed.connect(_on_exit_pressed)
		MusicManager.setup_button(exit_btn,
			Color(0.35, 0.12, 0.12, 0.90),
			Color(0.55, 0.18, 0.18, 0.97))
		vbox.add_child(exit_btn)

	# Version + author label (bottom-right corner)
	var version_lbl := Label.new()
	version_lbl.text = "%s  —  %s" % [VERSION, AUTHOR]
	version_lbl.anchor_left   = 1.0
	version_lbl.anchor_right  = 1.0
	version_lbl.anchor_top    = 1.0
	version_lbl.anchor_bottom = 1.0
	version_lbl.offset_left   = -260.0
	version_lbl.offset_right  = -12.0
	version_lbl.offset_top    = -36.0
	version_lbl.offset_bottom = -8.0
	version_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	version_lbl.add_theme_font_size_override("font_size", 13)
	version_lbl.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75, 0.7))
	root.add_child(version_lbl)

	# Save-state indicator (bottom-left)
	var save_lbl := Label.new()
	if SaveManager.has_save:
		save_lbl.text = "↩  Resume available"
		save_lbl.add_theme_color_override("font_color", Color(0.55, 0.9, 0.55, 0.85))
	else:
		save_lbl.text = "No save state"
		save_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65, 0.6))
	save_lbl.anchor_left   = 0.0
	save_lbl.anchor_right  = 0.0
	save_lbl.anchor_top    = 1.0
	save_lbl.anchor_bottom = 1.0
	save_lbl.offset_left   = 14.0
	save_lbl.offset_right  = 280.0
	save_lbl.offset_top    = -36.0
	save_lbl.offset_bottom = -8.0
	save_lbl.add_theme_font_size_override("font_size", 13)
	root.add_child(save_lbl)

	# Options overlay (invisible until options button pressed)
	_options_menu = OptionsMenu.new()
	_ui_layer.add_child(_options_menu)


# ── Button Handlers ──────────────────────────────────────────────────────────

func _on_play_pressed() -> void:
	_bg_stop = true
	print("MainMenu: Transitioning to game scene")
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _on_options_pressed() -> void:
	_options_menu.show_options()


func _on_exit_pressed() -> void:
	_bg_stop = true
	print("MainMenu: Exit requested")
	get_tree().quit()
