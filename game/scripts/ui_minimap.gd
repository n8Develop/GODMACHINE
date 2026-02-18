extends Control
class_name UIMinimap

const ROOM_COLORS := {
	"start": Color(0.3, 0.8, 0.3, 1.0),
	"corridor": Color(0.5, 0.5, 0.5, 1.0),
	"arena": Color(0.9, 0.3, 0.3, 1.0),
	"treasure": Color(0.9, 0.8, 0.2, 1.0),
	"unknown": Color(0.3, 0.3, 0.3, 1.0)
}

const ROOM_LABELS := {
	"start": "S",
	"corridor": "C",
	"arena": "A",
	"treasure": "T",
	"unknown": "?"
}

var _visited_rooms: Dictionary = {}
var _grid_container: GridContainer

func _ready() -> void:
	_grid_container = GridContainer.new()
	_grid_container.columns = 5
	_grid_container.add_theme_constant_override(&"h_separation", 4)
	_grid_container.add_theme_constant_override(&"v_separation", 4)
	add_child(_grid_container)

func _process(_delta: float) -> void:
	_update_display()

func _update_display() -> void:
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if not player:
		return
	
	var current_room := _find_room_at_position(player.global_position)
	if not current_room:
		return
	
	var room_id: String = current_room.get_meta("room_id", "unknown")
	if room_id and room_id not in _visited_rooms:
		_visited_rooms[room_id] = _detect_room_type(current_room)
	
	# Clear and rebuild grid
	for child in _grid_container.get_children():
		child.queue_free()
	
	for rid in _visited_rooms.keys():
		var room_type: String = _visited_rooms[rid]
		var is_current: bool = (current_room.get_meta("room_id", "") == rid)
		var icon := _create_room_icon(room_type, is_current)
		_grid_container.add_child(icon)

func _create_room_icon(room_type: String, is_current: bool) -> ColorRect:
	var icon := ColorRect.new()
	icon.custom_minimum_size = Vector2(24, 24)
	
	var base_color: Color = ROOM_COLORS.get(room_type, ROOM_COLORS["unknown"])
	if is_current:
		icon.color = base_color
	else:
		icon.color = base_color.darkened(0.4)
	
	# Add label overlay
	var label := Label.new()
	label.text = ROOM_LABELS.get(room_type, "?")
	label.add_theme_color_override(&"font_color", Color(1.0, 1.0, 1.0, 1.0))
	label.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	label.add_theme_constant_override(&"outline_size", 2)
	label.add_theme_font_size_override(&"font_size", 14)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(24, 24)
	icon.add_child(label)
	
	return icon

func _detect_room_type(room: Node) -> String:
	var room_name := room.name.to_lower()
	if "start" in room_name:
		return "start"
	elif "corridor" in room_name:
		return "corridor"
	elif "arena" in room_name:
		return "arena"
	elif "treasure" in room_name:
		return "treasure"
	return "unknown"

func _find_room_at_position(pos: Vector2) -> Node:
	for node in get_tree().get_nodes_in_group("rooms"):
		if node is Node2D:
			var rect := Rect2(node.global_position - Vector2(200, 200), Vector2(400, 400))
			if rect.has_point(pos):
				return node
	return null