extends Node2D
class_name Tile

signal dots_placed

@export var generated_value : int = -1
@export var dots_value : int = -1

func place_dots(v: int) -> bool:
	if self.dots_value != -1:
		return false
	self.dots_value = v
	dots_placed.emit()
	return true

func remove_dots() -> void:
	self.dots_value = -1
