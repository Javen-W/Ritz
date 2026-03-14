extends Node2D
class_name DominoPanel

@onready var game: Node2D = get_parent()

var domino_stack: Array[Domino] = []
var current_index: int = 0
const VISIBLE_COUNT: int = 5
const DOMINO_SPACING: float = 150.0
const PANEL_OFFSET_Y: float = -50.0  # World-space Y offset above camera bottom edge

func _ready() -> void:
	# Add a grey background bar behind the domino row
	var bg := Polygon2D.new()
	var w := VISIBLE_COUNT * DOMINO_SPACING + 60.0
	var h := 80.0
	bg.polygon = PackedVector2Array([
		Vector2(-w / 2.0, -h / 2.0), Vector2(w / 2.0, -h / 2.0),
		Vector2(w / 2.0, h / 2.0), Vector2(-w / 2.0, h / 2.0)
	])
	bg.color = Color(0.25, 0.25, 0.25, 0.85)
	bg.z_index = -1
	add_child(bg)

	GameSignalbus.domino_generated.connect(_on_domino_generated)
	GameSignalbus.domino_unassigned.connect(_on_domino_unassigned)

func _process(_delta: float) -> void:
	# Keep panel anchored to the bottom of the camera view in world space
	var camera := game.camera2d
	var viewport_size := get_viewport().get_visible_rect().size
	self.position = camera.global_position + Vector2(0.0, viewport_size.y / (2.0 * camera.zoom.y) + PANEL_OFFSET_Y)

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
	# Save panel-local position so _return_to_panel can restore it
	domino.panel_origin_position = domino.position

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
			# Position relative to panel center (local coordinates)
			domino.position = Vector2(
				-(VISIBLE_COUNT - 1) / 2.0 * DOMINO_SPACING + slot * DOMINO_SPACING,
				0.0
			)
			domino.scale = Vector2.ONE
			domino.z_index = 10
		else:
			domino.visible = false

func remove_domino_from_stack(domino: Domino) -> void:
	if domino_stack.has(domino):
		domino_stack.erase(domino)
		_layout_dominos()
