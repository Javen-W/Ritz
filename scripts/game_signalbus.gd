extends Node

## GameSignalbus – centralised event bus (autoload) for all game-wide signals.
##
## All inter-system communication between Game, Domino, Constraint and UI nodes
## should go through this singleton rather than direct method calls.  Using an
## explicit emit_* wrapper for every signal keeps call-sites easy to grep and
## avoids accidentally emitting signals from the wrong context.
##
## Registered as an autoload in project.godot so it is always available as
## the global name "GameSignalbus".

signal domino_generated(domino: Domino)
signal domino_assigned(domino: Domino)
signal domino_unassigned(domino: Domino)
signal dominos_reset()
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

func emit_dominos_reset() -> void:
	dominos_reset.emit()

func emit_game_won() -> void:
	game_won.emit()

func emit_game_state_changed(state: int) -> void:
	game_state_changed.emit(state)

func emit_generation_update(message: String) -> void:
	generation_update.emit(message)
