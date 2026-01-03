extends Node

signal domino_assigned(domino: Domino)

func emit_domino_assigned(domino: Domino) -> void:
	domino_assigned.emit(domino)
