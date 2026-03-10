extends Panel
class_name DominoPanel

@onready var unassigned_dominos : Node2D = $UnassignedDominos

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Connect signals.
	GameSignalbus.domino_generated.connect(_on_domino_generated)
	# GameSignalbus.domino_assigned.connect(_on_domino_unassigned)
	GameSignalbus.domino_unassigned.connect(_on_domino_unassigned)

func _on_domino_generated(domino: Domino) -> void:
	self.handle_domino_unassignment(domino)

func _on_domino_assigned(domino: Domino) -> void:
	pass

func _on_domino_unassigned(domino: Domino) -> void:
	self.handle_domino_unassignment(domino)

func handle_domino_unassignment(domino: Domino) -> void:
	if unassigned_dominos.get_children().has(domino):
		return
	if domino.get_parent():
		domino.get_parent().remove_child(domino)
	unassigned_dominos.add_child(domino)
	# domino.global_position = unassigned_dominos.global_position

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
