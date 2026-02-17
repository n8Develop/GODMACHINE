extends Node2D

## Draws the room visuals: dark floor and lighter wall borders.
## Physics walls are defined in the scene as StaticBody2D with WorldBoundaryShape2D.

const ROOM_W := 640
const ROOM_H := 480
const WALL_THICKNESS := 32
const FLOOR_COLOR := Color(0.15, 0.15, 0.18, 1.0)
const WALL_COLOR := Color(0.35, 0.3, 0.28, 1.0)

func _draw() -> void:
	# Floor
	draw_rect(Rect2(0, 0, ROOM_W, ROOM_H), FLOOR_COLOR)
	# Walls (top, bottom, left, right)
	draw_rect(Rect2(0, 0, ROOM_W, WALL_THICKNESS), WALL_COLOR)
	draw_rect(Rect2(0, ROOM_H - WALL_THICKNESS, ROOM_W, WALL_THICKNESS), WALL_COLOR)
	draw_rect(Rect2(0, 0, WALL_THICKNESS, ROOM_H), WALL_COLOR)
	draw_rect(Rect2(ROOM_W - WALL_THICKNESS, 0, WALL_THICKNESS, ROOM_H), WALL_COLOR)
