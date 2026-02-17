extends Node

## Global game state singleton.
## The AI orchestrator will expand this to track dungeon state,
## cycle counts, lore events, and more.

var current_cycle: int = 0
var world_seed: int = 0

func _ready() -> void:
	print("[GameManager] Initialized — cycle ", current_cycle)
