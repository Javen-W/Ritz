extends Node

signal domino_assigned(domino: Domino)
signal game_won()

func emit_domino_assigned(domino: Domino) -> void:
	domino_assigned.emit(domino)

func emit_game_won() -> void:
	game_won.emit()
