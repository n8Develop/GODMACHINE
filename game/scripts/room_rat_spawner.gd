extends Node
class_name RoomRatSpawner

## Add to any room's _ready() to spawn ambient rats
## Usage: RoomRatSpawner.spawn_rats_in_room(self, 2, 4)

static func spawn_rats_in_room(room: Node2D, min_count: int = 1, max_count: int = 3) -> void:
	var rat_scene := load("res://scenes/ambient_rat.tscn") as PackedScene
	if not rat_scene:
		return
	
	var count := randi_range(min_count, max_count)
	var room_bounds := _get_room_bounds(room)
	
	for i in range(count):
		var rat := rat_scene.instantiate()
		# Spawn near edges, not in center
		var spawn_pos := _get_edge_position(room_bounds)
		rat.global_position = spawn_pos
		room.add_child(rat)

static func _get_room_bounds(room: Node2D) -> Rect2:
	# Default room size — could be made smarter
	return Rect2(room.global_position - Vector2(280, 200), Vector2(560, 400))

static func _get_edge_position(bounds: Rect2) -> Vector2:
	var margin := 40.0
	var side := randi() % 4
	match side:
		0: # Top edge
			return Vector2(
				randf_range(bounds.position.x + margin, bounds.end.x - margin),
				bounds.position.y + margin
			)
		1: # Right edge
			return Vector2(
				bounds.end.x - margin,
				randf_range(bounds.position.y + margin, bounds.end.y - margin)
			)
		2: # Bottom edge
			return Vector2(
				randf_range(bounds.position.x + margin, bounds.end.x - margin),
				bounds.end.y - margin
			)
		_: # Left edge
			return Vector2(
				bounds.position.x + margin,
				randf_range(bounds.position.y + margin, bounds.end.y - margin)
			)