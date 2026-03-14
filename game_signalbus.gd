extends Node

signal domino_generated(domino: Domino)
signal domino_assigned(domino: Domino)
signal domino_unassigned(domino: Domino)
signal game_won()
signal game_state_changed(state: int)
signal generation_update(message: String)

# Starts true so the game is fully blocked until it transitions to ACTIVE state.
var interaction_blocked: bool = true


func emit_domino_generated(domino: Domino) -> void:
	domino_generated.emit(domino)

func emit_domino_assigned(domino: Domino) -> void:
	domino_assigned.emit(domino)

func emit_domino_unassigned(domino: Domino) -> void:
	domino_unassigned.emit(domino)

func emit_game_won() -> void:
	game_won.emit()

func emit_game_state_changed(state: int) -> void:
	game_state_changed.emit(state)

func emit_generation_update(message: String) -> void:
	generation_update.emit(message)
