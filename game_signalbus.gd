extends Node

signal domino_generated(domino: Domino)
signal domino_assigned(domino: Domino)
signal domino_unassigned(domino: Domino)
signal game_won()


func emit_domino_generated(domino: Domino) -> void:
	domino_generated.emit(domino)

func emit_domino_assigned(domino: Domino) -> void:
	domino_assigned.emit(domino)

func emit_domino_unassigned(domino: Domino) -> void:
	domino_unassigned.emit(domino)

func emit_game_won() -> void:
	game_won.emit()
