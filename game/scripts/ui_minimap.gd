extends Control
class_name UIMinimap

@onready var _label: Label = $Label

var _rooms_visited: Array[String] = []

func _ready() -> void:
	_update_display()

func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	var visited_rooms: Array = player.get_meta("rooms_visited", [])
	if visited_rooms != _rooms_visited:
		_rooms_visited = visited_rooms.duplicate()
		_update_display()

func _update_display() -> void:
	if _rooms_visited.is_empty():
		_label.text = "◻"
		return
	
	# Simple minimap: show room count and a grid pattern
	var count := _rooms_visited.size()
	var grid := ""
	
	# Create a simple visual representation
	if count == 1:
		grid = "◼"
	elif count == 2:
		grid = "◼◼"
	elif count == 3:
		grid = "◼◼\n◼"
	elif count == 4:
		grid = "◼◼\n◼◼"
	elif count == 5:
		grid = "◼◼◼\n◼◼"
	else:
		grid = "◼◼◼\n◼◼◼"
	
	_label.text = grid