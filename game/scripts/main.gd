extends Node2D

var _DungeonMemoryScript = preload("res://scripts/dungeon_memory.gd")
var _AmbientSoundscapeScript = preload("res://scripts/ambient_soundscape.gd")
var _HungerWhisperScript = preload("res://scripts/hunger_whisper.gd")

var dungeon_memory: Node
var ambient_soundscape: Node
var hunger_whisper: Node

func _ready() -> void:
	# Create dungeon memory singleton
	dungeon_memory = _DungeonMemoryScript.new()
	dungeon_memory.name = "DungeonMemory"
	add_child(dungeon_memory)

	# Create ambient soundscape
	ambient_soundscape = _AmbientSoundscapeScript.new()
	ambient_soundscape.name = "AmbientSoundscape"
	add_child(ambient_soundscape)
	
	# Create hunger whisper system
	hunger_whisper = _HungerWhisperScript.new()
	hunger_whisper.name = "HungerWhisper"
	add_child(hunger_whisper)
	
	# Connect to room for initial entry recording
	var current_room := get_node_or_null("CurrentRoom")
	if current_room:
		_on_room_entered(current_room)

func _on_room_entered(room: Node) -> void:
	var player := get_node_or_null("Player")
	if not player:
		return
	
	var health_comp := player.get_node_or_null("HealthComponent")
	var hp_percent := 1.0
	if health_comp:
		hp_percent = float(health_comp.current_health) / float(health_comp.max_health)
	
	var room_type := "unknown"
	if room.name.contains("arena"):
		room_type = "arena"
	elif room.name.contains("corridor"):
		room_type = "corridor"
	elif room.name.contains("treasure"):
		room_type = "treasure"
	elif room.name.contains("boss"):
		room_type = "boss"
	elif room.name.contains("start"):
		room_type = "start"
	
	dungeon_memory.record_room_entry(room_type, hp_percent)