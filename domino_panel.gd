extends Panel
class_name DominoPanel

@onready var unassigned_dominos : Node2D = $UnassignedDominos

# Domino stack management
var domino_stack: Array[Domino] = []
var current_index: int = 0
const VISIBLE_COUNT: int = 5
const DOMINO_SPACING: float = 70.0

func _ready() -> void:
	GameSignalbus.domino_generated.connect(_on_domino_generated)
	GameSignalbus.domino_unassigned.connect(_on_domino_unassigned)

func _on_domino_generated(domino: Domino) -> void:
	add_domino_to_stack(domino)

func _on_domino_unassigned(domino: Domino) -> void:
	add_domino_to_stack(domino)

func add_domino_to_stack(domino: Domino) -> void:
	if domino_stack.has(domino):
		return
	
	if domino.get_parent():
		domino.get_parent().remove_child(domino)
	
	unassigned_dominos.add_child(domino)
	domino_stack.append(domino)
	domino.is_from_panel = true
	
	_layout_dominos()

func shuffle_to_next() -> void:
	if domino_stack.is_empty():
		return
	current_index = (current_index + 1) % domino_stack.size()
	_layout_dominos()

func shuffle_to_previous() -> void:
	if domino_stack.is_empty():
		return
	current_index = (current_index - 1) % domino_stack.size()
	_layout_dominos()

func _layout_dominos() -> void:
	for i in range(domino_stack.size()):
		var domino = domino_stack[i]
		var position_index = (i - current_index) % domino_stack.size()
		
		if position_index < VISIBLE_COUNT:
			domino.visible = true
			var x_pos = 20.0 + position_index * DOMINO_SPACING
			var y_pos = self.size.y / 2.0
			domino.position = Vector2(x_pos, y_pos)
		else:
			domino.visible = false

func remove_domino_from_stack(domino: Domino) -> void:
	if domino_stack.has(domino):
		domino_stack.erase(domino)
		_layout_dominos()
