extends Control
class_name UIMinimap

@onready var grid_container := $PanelContainer/MarginContainer/GridContainer

var _visited_rooms: Dictionary = {}
var _current_room_id: String = ""

# Room type icons - color coded
const ROOM_COLORS := {
	"start": Color(0.3, 0.9, 0.3, 1.0),      # Green - safe spawn
	"corridor": Color(0.5, 0.5, 0.6, 1.0),   # Gray - passage
	"treasure": Color(1.0, 0.8, 0.2, 1.0),   # Gold - rewards
	"arena": Color(0.9, 0.2, 0.2, 1.0),      # Red - combat
	"unknown": Color(0.3, 0.3, 0.4, 1.0)     # Dark gray - default
}

func _ready() -> void:
	if not grid_container:
		push_error("GODMACHINE ERROR: GridContainer not found in minimap")
		return
	
	# Start with current room
	var player := get_tree().get_first_node_in_group("player")
	if player:
		var current_room := _find_room_at_position(player.global_position)
		if current_room:
			_current_room_id = current_room.room_id
			_visited_rooms[_current_room_id] = _detect_room_type(current_room)

func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	var current_room := _find_room_at_position(player.global_position)
	if current_room and current_room.room_id != _current_room_id:
		_current_room_id = current_room.room_id
		if not _visited_rooms.has(_current_room_id):
			_visited_rooms[_current_room_id] = _detect_room_type(current_room)
		_update_display()

func _update_display() -> void:
	if not grid_container:
		return
	
	# Clear existing icons
	for child in grid_container.get_children():
		child.queue_free()
	
	# Add icon for each visited room
	for room_id in _visited_rooms.keys():
		var room_type: String = _visited_rooms[room_id]
		var icon := _create_room_icon(room_type, room_id == _current_room_id)
		grid_container.add_child(icon)

func _create_room_icon(room_type: String, is_current: bool) -> ColorRect:
	var icon := ColorRect.new()
	icon.custom_minimum_size = Vector2(12, 12)
	
	var base_color: Color = ROOM_COLORS.get(room_type, ROOM_COLORS["unknown"])
	
	if is_current:
		# Pulse current room brighter
		icon.color = base_color * 1.5
	else:
		icon.color = base_color
	
	return icon

func _detect_room_type(room: Node) -> String:
	# Detect room type based on room_id prefix or node structure
	if room.room_id.begins_with("start"):
		return "start"
	elif room.room_id.begins_with("corridor"):
		return "corridor"
	elif room.room_id.begins_with("treasure"):
		return "treasure"
	elif room.room_id.begins_with("arena"):
		return "arena"
	
	# Fallback: check for spawners/enemies
	var spawners := room.get_node_or_null("Spawners")
	if spawners and spawners.get_child_count() > 0:
		return "arena"
	
	var enemies := room.get_node_or_null("Enemies")
	if enemies and enemies.get_child_count() > 3:
		return "arena"
	
	var pickups := room.get_node_or_null("Pickups")
	if pickups and pickups.get_child_count() > 2:
		return "treasure"
	
	return "corridor"

func _find_room_at_position(pos: Vector2) -> Node:
	var rooms := get_tree().get_nodes_in_group("rooms")
	for room in rooms:
		if room is Node2D:
			var area := room.get_node_or_null("RoomBounds") as Area2D
			if area:
				for shape_owner in area.get_shape_owners():
					var shape := area.shape_owner_get_shape(shape_owner, 0)
					if shape is RectangleShape2D:
						var rect := Rect2(
							room.global_position - shape.size / 2.0,
							shape.size
						)
						if rect.has_point(pos):
							return room
	return null