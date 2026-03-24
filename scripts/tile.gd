extends Node2D
class_name Tile

## Tile – a single cell in the puzzle grid.
##
## Each tile starts empty (dots_value == -1) and becomes filled when a Domino
## is placed on top of it via place_dots().  The generated_value is set during
## procedural generation and represents the "answer" value the domino must
## match.  dots_value is the player-placed value used for constraint checking.

signal dots_placed

## The value assigned during procedural generation (-1 = not yet set).
@export var generated_value : int = -1
## The value placed by the player via a domino (-1 = empty / unoccupied).
@export var dots_value : int = -1

## Place a dot value on this tile.  Returns false if the tile is already filled.
func place_dots(v: int) -> bool:
	if self.dots_value != -1:
		return false
	self.dots_value = v
	dots_placed.emit()
	return true

## Remove the player-placed dot value, returning the tile to the empty state.
func remove_dots() -> void:
	self.dots_value = -1
