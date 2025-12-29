extends Node2D
class_name Tile

signal dots_placed

@export var generated_value : int = -1
@export var dots_value : int = -1

func place_dots(v: int) -> void:
	self.dots_value = v
	dots_placed.emit()

func remove_dots() -> void:
	place_dots(-1)
