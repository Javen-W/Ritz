extends Node2D
class_name DominoPanel

@onready var game: Node2D = get_parent()

var domino_stack: Array[Domino] = []
var current_index: int = 0
const VISIBLE_COUNT: int = 7
const DOMINO_SPACING: float = 150.0
const PANEL_OFFSET_Y: float = -90.0  # World-space Y offset above camera bottom edge
const PANEL_HEIGHT: float = 160.0
const CORNER_RADIUS: float = 20.0
# Reserve screen space for the always-visible GenPanel on the right
const GEN_PANEL_WIDTH: float = 340.0

var _bg: Polygon2D
var _last_bg_width: float = 0.0
var _button_container: VBoxContainer
var _shuffle_pending := false

func _ready() -> void:
	_bg = Polygon2D.new()
	_bg.color = Color(0.25, 0.25, 0.25, 0.85)
	_bg.z_index = -1
	add_child(_bg)

	# Buttons live in a CanvasLayer so they stay in screen space
	var canvas := CanvasLayer.new()
	canvas.layer = 10
	add_child(canvas)
	_button_container = VBoxContainer.new()
	_button_container.add_theme_constant_override("separation", 6)
	canvas.add_child(_button_container)

	var reset_btn := Button.new()
	reset_btn.text = "↺ Reset"
	reset_btn.focus_mode = Control.FOCUS_NONE
	_button_container.add_child(reset_btn)
	reset_btn.pressed.connect(_on_reset_button_pressed)

	var shuffle_btn := Button.new()
	shuffle_btn.text = "⇄ Shuffle"
	shuffle_btn.focus_mode = Control.FOCUS_NONE
	_button_container.add_child(shuffle_btn)
	shuffle_btn.pressed.connect(_on_shuffle_button_pressed)

	GameSignalbus.domino_generated.connect(_on_domino_generated)
	GameSignalbus.domino_unassigned.connect(_on_domino_unassigned)

func _make_rounded_rect_polygon(w: float, h: float, r: float, segs: int = 8) -> PackedVector2Array:
	var pts := PackedVector2Array()
	r = minf(r, minf(w / 2.0, h / 2.0))
	var corners := [Vector2(-w/2+r, -h/2+r), Vector2(w/2-r, -h/2+r),
					Vector2(w/2-r,  h/2-r),  Vector2(-w/2+r, h/2-r)]
	var angles := [PI, 3*PI/2, 0.0, PI/2]
	for i in 4:
		for s in segs + 1:
			var a : float = angles[i] + (PI/2) * float(s) / float(segs)
			pts.append(corners[i] + Vector2(cos(a), sin(a)) * r)
	return pts

func _process(_delta: float) -> void:
	var camera: Camera2D = game.camera2d
	var viewport_size := get_viewport().get_visible_rect().size

	# Center the panel in the area left of the GenPanel.
	# In world space: shift left by half the GenPanel's screen width.
	var gen_offset_world := GEN_PANEL_WIDTH / (2.0 * camera.zoom.x)
	self.position = camera.global_position + Vector2(
		-gen_offset_world,
		viewport_size.y / (2.0 * camera.zoom.y) + PANEL_OFFSET_Y
	)

	# Panel width = 75% of the available screen area (viewport minus GenPanel)
	var avail_screen := viewport_size.x - GEN_PANEL_WIDTH
	var w := avail_screen / camera.zoom.x * 0.75
	if not is_equal_approx(w, _last_bg_width):
		_last_bg_width = w
		_bg.polygon = _make_rounded_rect_polygon(w, PANEL_HEIGHT, CORNER_RADIUS)

	# Position buttons just outside the right edge of the panel background
	var panel_screen_y := viewport_size.y + PANEL_OFFSET_Y * camera.zoom.y
	var panel_right_screen_x := viewport_size.x / 2.0 - GEN_PANEL_WIDTH / 2.0 + _last_bg_width / 2.0 * camera.zoom.x + 8.0
	_button_container.position = Vector2(
		panel_right_screen_x,
		panel_screen_y - _button_container.size.y / 2.0
	)

func _on_domino_generated(domino: Domino) -> void:
	add_domino_to_stack(domino)
	# Defer initial shuffle so it runs once after all dominos are added this frame
	if not _shuffle_pending:
		_shuffle_pending = true
		call_deferred("_do_initial_shuffle")

func _do_initial_shuffle() -> void:
	_shuffle_pending = false
	shuffle_stack()
	print("DominoPanel: Initial shuffle complete — %d dominos in stack" % domino_stack.size())

func _on_domino_unassigned(domino: Domino) -> void:
	add_domino_to_stack(domino)

func add_domino_to_stack(domino: Domino) -> void:
	if not domino_stack.has(domino):
		var saved_global := domino.global_position
		if domino.get_parent():
			domino.get_parent().remove_child(domino)
		add_child(domino)
		domino_stack.append(domino)
		domino.is_from_panel = true
		# Restore world position so a picked domino doesn't flicker when reparented
		if domino.is_picked:
			domino.global_position = saved_global
		print("DominoPanel: Added domino — stack size now %d" % domino_stack.size())

	_layout_dominos()
	# Compute the expected slot position directly so picked dominos get the right origin
	domino.panel_origin_position = _slot_local_position(domino_stack.find(domino))

func shuffle_stack() -> void:
	if domino_stack.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in range(domino_stack.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := domino_stack[i]
		domino_stack[i] = domino_stack[j]
		domino_stack[j] = tmp
	current_index = 0
	# Shuffle all panel domino orientations.
	for domino in domino_stack:
		for j in rng.randi_range(0, 3):
			domino.rotate_once()
	_layout_dominos()
	print("DominoPanel: Shuffled stack (%d dominos)" % domino_stack.size())

func shuffle_to_next() -> void:
	if domino_stack.is_empty():
		return
	current_index = (current_index + 1) % domino_stack.size()
	_layout_dominos()

func shuffle_to_previous() -> void:
	if domino_stack.is_empty():
		return
	current_index = (current_index - 1 + domino_stack.size()) % domino_stack.size()
	_layout_dominos()

func _slot_local_position(stack_index: int) -> Vector2:
	var n := domino_stack.size()
	if n == 0:
		return Vector2.ZERO
	var slot := ((stack_index - current_index) % n + n) % n
	return Vector2(-(VISIBLE_COUNT - 1) / 2.0 * DOMINO_SPACING + slot * DOMINO_SPACING, 0.0)

func _layout_dominos() -> void:
	var n := domino_stack.size()
	for i in range(n):
		var domino := domino_stack[i]
		if domino.is_picked:
			continue

		var slot := ((i - current_index) % n + n) % n

		if slot < VISIBLE_COUNT:
			domino.visible = true
			domino.position = _slot_local_position(i)
			domino.scale = Vector2.ONE
			domino.z_index = 10
		else:
			domino.visible = false

func remove_domino_from_stack(domino: Domino) -> void:
	if domino_stack.has(domino):
		domino_stack.erase(domino)
		print("DominoPanel: Removed domino — stack size now %d" % domino_stack.size())
		_layout_dominos()

func reset_all_dominos() -> void:
	var to_reset: Array[Domino] = []
	for node in get_tree().get_nodes_in_group("dominos"):
		var domino := node as Domino
		if domino and domino.is_placed:
			to_reset.append(domino)
	for domino in to_reset:
		if domino.tile1:
			domino.tile1.remove_dots()
			domino.tile1 = null
		if domino.tile2:
			domino.tile2.remove_dots()
			domino.tile2 = null
		domino.is_placed = false
		domino.is_from_panel = true
		add_domino_to_stack(domino)
	print("DominoPanel: Reset %d placed dominos back to panel" % to_reset.size())

func _on_shuffle_button_pressed() -> void:
	if GameSignalbus.interaction_blocked:
		return
	shuffle_stack()

func _on_reset_button_pressed() -> void:
	if GameSignalbus.interaction_blocked:
		return
	reset_all_dominos()
