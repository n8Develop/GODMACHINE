extends Area2D

@export var required_keys: int = 1
@export var target_room_id: String = ""
@export var target_room_scene: PackedScene

@onready var label: Label = $Label

func _ready() -> void:
	add_to_group("doors")
	body_entered.connect(_on_body_entered)
	_update_label()

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	
	var keys: int = body.get_meta("keys_collected", 0)
	
	if keys >= required_keys:
		body.set_meta("keys_collected", keys - required_keys)
		_transition_to_room()
	else:
		_update_label()

func _update_label() -> void:
	if label:
		label.text = "Need %d key%s" % [required_keys, "s" if required_keys > 1 else ""]

func _transition_to_room() -> void:
	if not target_room_scene:
		return
	
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	# Find or create room transition handler
	var transition := get_tree().get_first_node_in_group("room_transition")
	if not transition:
		var TransitionScript := load("res://scripts/room_transition.gd")
		transition = TransitionScript.new()
		transition.name = "RoomTransition"
		get_tree().current_scene.add_child(transition)
	
	if transition.has_method("transition_to_room"):
		transition.transition_to_room(target_room_scene, player)