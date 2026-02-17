extends Area2D

@export var required_keys: int = 1
@export var target_room_id: String = ""

@onready var label: Label = $Label

var _is_unlocked: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_update_label()

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	
	var player_keys: int = body.get_meta("keys_collected", 0)
	
	if _is_unlocked:
		# Already unlocked, allow passage
		if target_room_id != "":
			_transition_to_room(target_room_id)
		return
	
	if player_keys >= required_keys:
		# Unlock permanently
		_is_unlocked = true
		body.set_meta("keys_collected", player_keys - required_keys)
		print("GODMACHINE: Door unlocked — ", required_keys, " keys consumed")
		_update_label()
		if target_room_id != "":
			_transition_to_room(target_room_id)
	else:
		print("GODMACHINE: Door sealed — requires ", required_keys, " keys (you have ", player_keys, ")")

func _update_label() -> void:
	if not label:
		return
	
	if _is_unlocked:
		label.text = "OPEN"
		label.modulate = Color(0.2, 0.9, 0.3, 1.0)
	else:
		label.text = "LOCKED\n" + str(required_keys) + " KEY"
		label.modulate = Color(0.9, 0.2, 0.2, 1.0)

func _transition_to_room(new_room_id: String) -> void:
	var main := get_tree().current_scene
	if not main:
		return
	
	var current_room := main.get_node_or_null("CurrentRoom")
	if not current_room:
		return
	
	# Mark current room as visited
	var player := get_tree().get_first_node_in_group("player")
	if player:
		var visited: Array = player.get_meta("visited_rooms", [])
		var current_id: String = current_room.room_id
		if current_id != "" and current_id not in visited:
			visited.append(current_id)
			player.set_meta("visited_rooms", visited)
	
	# Load new room
	var room_scene: PackedScene
	match new_room_id:
		"room_start":
			room_scene = load("res://scenes/room_start.tscn")
		"room_corridor":
			room_scene = load("res://scenes/room_corridor.tscn")
		"room_treasure":
			room_scene = load("res://scenes/room_treasure.tscn")
	
	if room_scene:
		current_room.queue_free()
		var new_room := room_scene.instantiate()
		main.add_child(new_room)
		main.move_child(new_room, 0)
		
		if player:
			player.global_position = Vector2(320, 400)