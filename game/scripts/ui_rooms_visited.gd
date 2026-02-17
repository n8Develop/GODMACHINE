extends Control
class_name UIRoomsVisited

@onready var label := $Label

func _ready() -> void:
	_update_display()

func _process(_delta: float) -> void:
	_update_display()

func _update_display() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		label.text = "Rooms: 0"
		return
	
	var visited := player.get_meta("rooms_visited", []) as Array
	label.text = "Rooms: %d" % visited.size()