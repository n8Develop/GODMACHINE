extends Control
class_name UIKeyInventory

@onready var _key_container: HBoxContainer = $Panel/MarginContainer/HBoxContainer
var _key_labels: Array[Label] = []

func _ready() -> void:
	# Find player and connect to key pickup events
	var player := get_tree().get_first_node_in_group("player")
	if player:
		_update_keys()
		# Poll for key changes every frame (simple approach)
		set_process(true)
	else:
		set_process(false)

func _process(_delta: float) -> void:
	_update_keys()

func _update_keys() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	var keys: Array = player.get_meta("keys", [])
	
	# Clear existing labels
	for label in _key_labels:
		label.queue_free()
	_key_labels.clear()
	
	# Create label for each key
	for key_id in keys:
		var label := Label.new()
		label.text = "🔑"
		label.add_theme_font_size_override(&"font_size", 24)
		label.add_theme_color_override(&"font_color", Color(1.0, 0.9, 0.2, 1.0))
		_key_container.add_child(label)
		_key_labels.append(label)
	
	# Show "No keys" message if empty
	if keys.is_empty():
		var label := Label.new()
		label.text = "No keys"
		label.add_theme_font_size_override(&"font_size", 12)
		label.add_theme_color_override(&"font_color", Color(0.5, 0.5, 0.5, 1.0))
		_key_container.add_child(label)
		_key_labels.append(label)