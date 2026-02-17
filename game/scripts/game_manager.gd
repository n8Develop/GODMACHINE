extends Node

## Global game state singleton.
## The AI orchestrator will expand this to track dungeon state,
## cycle counts, lore events, and more.

var current_cycle: int = 0
var world_seed: int = 0
var player: CharacterBody2D = null

func _ready() -> void:
	print("[GameManager] Initialized — cycle ", current_cycle)
	# Wait a frame for scene tree to populate
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