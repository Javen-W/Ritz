extends Node2D
class_name DominoPanel

@onready var game: Node2D = get_parent()

var domino_stack: Array[Domino] = []
var current_index: int = 0
const VISIBLE_COUNT: int = 5
const DOMINO_SPACING: float = 150.0
const PANEL_OFFSET_Y: float = -90.0  # World-space Y offset above camera bottom edge
const PANEL_HEIGHT: float = 160.0

var _reset_button: Button

func _ready() -> void:
	# Background bar spans the full visible width of the viewport
	var bg := Polygon2D.new()
	var w := 3000.0
	bg.polygon = PackedVector2Array([
		Vector2(-w / 2.0, -PANEL_HEIGHT / 2.0), Vector2(w / 2.0, -PANEL_HEIGHT / 2.0),
		Vector2(w / 2.0, PANEL_HEIGHT / 2.0), Vector2(-w / 2.0, PANEL_HEIGHT / 2.0)
	])
	bg.color = Color(0.25, 0.25, 0.25, 0.85)
	bg.z_index = -1
	add_child(bg)

	# Reset button lives in a CanvasLayer so it stays in screen space
	var canvas := CanvasLayer.new()
	canvas.layer = 10
	add_child(canvas)
	_reset_button = Button.new()
	_reset_button.text = "↺ Reset"
	canvas.add_child(_reset_button)
	_reset_button.pressed.connect(_on_reset_button_pressed)

	GameSignalbus.domino_generated.connect(_on_domino_generated)
	GameSignalbus.domino_unassigned.connect(_on_domino_unassigned)

func _process(_delta: float) -> void:
	# Keep panel anchored to the bottom of the camera view in world space
	var camera: Camera2D = game.camera2d
	var viewport_size := get_viewport().get_visible_rect().size
	self.position = camera.global_position + Vector2(0.0, viewport_size.y / (2.0 * camera.zoom.y) + PANEL_OFFSET_Y)

	# Position the reset button to the right of the domino row in screen space
	var panel_screen_y := viewport_size.y + PANEL_OFFSET_Y * camera.zoom.y
	_reset_button.position = Vector2(
		viewport_size.x / 2.0 + (VISIBLE_COUNT - 1) / 2.0 * DOMINO_SPACING * camera.zoom.x + 20.0,
		panel_screen_y - _reset_button.size.y / 2.0
	)

func _on_domino_generated(domino: Domino) -> void:
	add_domino_to_stack(domino)

func _on_domino_unassigned(domino: Domino) -> void:
	add_domino_to_stack(domino)

func add_domino_to_stack(domino: Domino) -> void:
	if not domino_stack.has(domino):
		if domino.get_parent():
			domino.get_parent().remove_child(domino)
		add_child(domino)
		domino_stack.append(domino)
		domino.is_from_panel = true

	_layout_dominos()
	# Compute the expected slot position directly so picked dominos get the right origin
	domino.panel_origin_position = _slot_local_position(domino_stack.find(domino))

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

		# Wrap-safe modulo so negative indices work correctly
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

func _on_reset_button_pressed() -> void:
	reset_all_dominos()
