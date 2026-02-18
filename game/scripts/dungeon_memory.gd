extends Node
class_name DungeonMemory

## Singleton that tracks dungeon state across room transitions
## Provides context to rooms so they can adapt to player's journey

signal memory_updated(key: String, value: Variant)

var state := {
	"threat_level": 0.0,           # Accumulates with dangerous encounters
	"rooms_since_heal": 0,         # Tracks desperation
	"recent_enemy_types": [],      # Last 5 enemy types killed (for variety)
	"keys_collected": 0,           # Total keys picked up
	"total_rooms_entered": 0,      # Raw room count
	"player_low_hp_entries": 0,    # Times entered room with <30% HP
	"last_room_type": "",          # previous room's type
	"consecutive_combats": 0,      # combat rooms in a row
}

func _ready() -> void:
	print("DUNGEON MEMORY: consciousness initialized")

func record_room_entry(room_type: String, player_hp_percent: float) -> void:
	state["total_rooms_entered"] += 1
	state["last_room_type"] = room_type
	
	if player_hp_percent < 0.3:
		state["player_low_hp_entries"] += 1
		state["rooms_since_heal"] += 1
	
	if room_type in ["arena", "corridor"]:
		state["consecutive_combats"] += 1
	else:
		state["consecutive_combats"] = 0
	
	memory_updated.emit("room_entry", room_type)

func record_enemy_death(enemy_type: String) -> void:
	var recent: Array = state["recent_enemy_types"]
	recent.append(enemy_type)
	if recent.size() > 5:
		recent.pop_front()
	state["recent_enemy_types"] = recent
	
	# Threat increases with kills
	state["threat_level"] += 0.1
	memory_updated.emit("enemy_killed", enemy_type)

func record_healing(amount: int) -> void:
	state["rooms_since_heal"] = 0
	state["threat_level"] = max(0.0, state["threat_level"] - 0.3)
	memory_updated.emit("healing", amount)

func record_key_collected() -> void:
	state["keys_collected"] += 1
	memory_updated.emit("key_collected", state["keys_collected"])

func get_threat_level() -> float:
	return state["threat_level"]

func is_player_desperate() -> bool:
	return state["rooms_since_heal"] >= 3 or state["player_low_hp_entries"] > state["total_rooms_entered"] * 0.3

func should_force_variety(enemy_type: String) -> bool:
	var recent: Array = state["recent_enemy_types"]
	return recent.count(enemy_type) >= 3

func get_adaptive_spawn_count(base_count: int) -> int:
	if is_player_desperate():
		return max(1, base_count - 1)  # Mercy: reduce enemies
	elif state["threat_level"] > 2.0:
		return max(1, base_count - 1)  # Ease off if threat is high
	return base_count

func get_adaptive_heal_chance() -> float:
	# Higher desperation = more likely to spawn healing
	if is_player_desperate():
		return 0.6
	elif state["rooms_since_heal"] >= 2:
		return 0.3
	return 0.1