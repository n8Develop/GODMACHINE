extends Node2D
class_name RoomTransition

## Handles visual transitions between rooms, remembering blood trails and death locations

@export var fade_duration: float = 0.6
@export var blood_fade_start: float = 0.3  # When blood starts appearing during transition

var _is_transitioning: bool = false
var _blood_memories: Array[Dictionary] = []  # Stores {pos: Vector2, intensity: float}

func _ready() -> void:
	add_to_group("room_transition")

func transition_to_room(new_room_scene: PackedScene, player: Node2D) -> void:
	if _is_transitioning:
		return
	
	_is_transitioning = true
	
	# Record current blood state before transition
	_record_blood_state()
	
	# Create fade overlay
	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	overlay.size = get_viewport_rect().size
	overlay.z_index = 200
	get_tree().current_scene.add_child(overlay)
	
	# Fade to black
	var fade_out := create_tween()
	fade_out.tween_property(overlay, "color:a", 1.0, fade_duration * 0.5)
	await fade_out.finished
	
	# Show blood memories during darkness
	_show_blood_echoes(overlay)
	await get_tree().create_timer(blood_fade_start).timeout
	
	# Load new room
	var current_scene := get_tree().current_scene
	var old_room := current_scene.get_node_or_null("CurrentRoom")
	if old_room:
		old_room.queue_free()
	
	var new_room := new_room_scene.instantiate()
	new_room.name = "CurrentRoom"
	current_scene.add_child(new_room)
	
	# Position player at entrance
	if player:
		player.global_position = new_room.global_position + Vector2(320, 400)
	
	# Fade from black
	var fade_in := create_tween()
	fade_in.tween_property(overlay, "color:a", 0.0, fade_duration * 0.5)
	await fade_in.finished
	
	overlay.queue_free()
	_is_transitioning = false

func _record_blood_state() -> void:
	_blood_memories.clear()
	
	var blood_stains := get_tree().get_nodes_in_group("blood_stain")
	for stain in blood_stains:
		if not is_instance_valid(stain):
			continue
		if stain is Node2D:
			_blood_memories.append({
				"pos": stain.global_position,
				"intensity": stain.modulate.a
			})

func _show_blood_echoes(overlay: ColorRect) -> void:
	if _blood_memories.is_empty():
		return
	
	# Create temporary container for blood echoes
	var echo_layer := Control.new()
	echo_layer.anchor_right = 1.0
	echo_layer.anchor_bottom = 1.0
	echo_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(echo_layer)
	
	# Spawn faint blood memories
	for memory in _blood_memories:
		var echo := ColorRect.new()
		echo.size = Vector2(8, 8)
		echo.position = memory.pos - Vector2(4, 4)
		echo.color = Color(0.4, 0.05, 0.05, memory.intensity * 0.3)
		echo_layer.add_child(echo)
		
		# Pulse briefly
		var pulse := create_tween()
		pulse.set_parallel(true)
		pulse.tween_property(echo, "modulate:a", 0.0, blood_fade_start)
		pulse.tween_property(echo, "scale", Vector2(1.5, 1.5), blood_fade_start)