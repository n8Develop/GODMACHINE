extends Node

## Global game state singleton.
## Manages room transitions, world state, and player persistence.

var current_cycle: int = 0
var world_seed: int = 0
var player: CharacterBody2D = null
var current_room: String = "room_01"
var transitioning: bool = false

# Room scene registry
var room_scenes := {
	"room_01": "res://scenes/room_01.tscn",
	"room_02": "res://scenes/room_02.tscn"
}

func _ready() -> void:
	print("[GameManager] Initialized — cycle ", current_cycle)
	call_deferred("_link_player")

func _link_player() -> void:
	player = get_tree().get_first_node_in_group("player")
	if player:
		print("[GameManager] Player linked")
		_distribute_player_reference()

func _distribute_player_reference() -> void:
	# Give all enemies a reference to the player
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.has_method("set"):
			enemy.player = player

func transition_to_room(room_id: String) -> void:
	if transitioning:
		return
	
	if not room_scenes.has(room_id):
		print("[GameManager] ERROR: Room ", room_id, " not found")
		return
	
	transitioning = true
	print("[GameManager] Transitioning to room: ", room_id)
	
	# Store player state
	var player_hp := 0
	var player_max_hp := 0
	if player:
		player_hp = player.current_hp
		player_max_hp = player.max_hp
	
	# Change scene
	current_room = room_id
	get_tree().change_scene_to_file(room_scenes[room_id])
	
	# Restore player state after scene loads
	await get_tree().process_frame
	await get_tree().process_frame
	
	_link_player()
	if player:
		player.current_hp = player_hp
		player.max_hp = player_max_hp
	
	transitioning = false
	print("[GameManager] Transition complete")