extends Control
class_name UICompass

const DIRECTION_LABELS := {
	Vector2.RIGHT: "E",
	Vector2.LEFT: "W",
	Vector2.DOWN: "S",
	Vector2.UP: "N"
}

var _compass_center: ColorRect = null
var _direction_markers: Dictionary = {}
var _active_direction: Vector2 = Vector2.ZERO
var _last_velocity: Vector2 = Vector2.ZERO

func _ready() -> void:
	# Create compass background
	_compass_center = ColorRect.new()
	_compass_center.size = Vector2(60, 60)
	_compass_center.position = Vector2(0, 0)
	_compass_center.color = Color(0.1, 0.1, 0.15, 0.8)
	add_child(_compass_center)
	
	# Create cardinal direction markers
	_create_direction_marker(Vector2.RIGHT, "E", Color(0.9, 0.8, 0.3))  # East - gold
	_create_direction_marker(Vector2.LEFT, "W", Color(0.7, 0.7, 0.7))   # West - silver
	_create_direction_marker(Vector2.DOWN, "S", Color(0.6, 0.6, 0.6))   # South - gray
	_create_direction_marker(Vector2.UP, "N", Color(1.0, 0.3, 0.3))     # North - red
	
	# Create center dot
	var center_dot := ColorRect.new()
	center_dot.size = Vector2(6, 6)
	center_dot.position = Vector2(27, 27)
	center_dot.color = Color(0.4, 0.4, 0.5, 1.0)
	_compass_center.add_child(center_dot)

func _create_direction_marker(dir: Vector2, label_text: String, color: Color) -> void:
	var marker := Label.new()
	marker.text = label_text
	marker.add_theme_color_override(&"font_color", color)
	marker.add_theme_font_size_override(&"font_size", 16)
	marker.modulate.a = 0.4
	
	# Position at edge of compass
	var offset := dir * 22.0
	marker.position = Vector2(30, 30) + offset - Vector2(6, 10)
	
	_direction_markers[dir] = marker
	_compass_center.add_child(marker)

func _process(_delta: float) -> void:
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if not player:
		return
	
	var velocity: Vector2 = player.velocity if player.has_method("get") else Vector2.ZERO
	
	# Only update if velocity changed significantly
	if velocity.length() > 10.0:
		_last_velocity = velocity
		_update_active_direction(velocity.normalized())
	elif _last_velocity.length() > 10.0:
		# Keep showing last direction briefly when stopped
		_update_active_direction(_last_velocity.normalized())
	else:
		_update_active_direction(Vector2.ZERO)

func _update_active_direction(normalized_vel: Vector2) -> void:
	if normalized_vel.length() < 0.1:
		# Dim all when stationary
		for marker in _direction_markers.values():
			marker.modulate.a = 0.4
		return
	
	# Find closest cardinal direction
	var closest_dir := Vector2.RIGHT
	var best_dot := -2.0
	
	for dir in DIRECTION_LABELS.keys():
		var dot := normalized_vel.dot(dir)
		if dot > best_dot:
			best_dot = dot
			closest_dir = dir
	
	# Update marker brightness
	for dir in _direction_markers.keys():
		var marker := _direction_markers[dir] as Label
		if dir == closest_dir:
			marker.modulate.a = 1.0
		else:
			marker.modulate.a = 0.4