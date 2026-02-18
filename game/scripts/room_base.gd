extends Node2D
class_name RoomBase

signal room_cleared
signal player_entered
signal player_exited

@export var room_id: String = ""
@export var is_cleared: bool = false

var _doors: Array[Area2D] = []
var _enemies: Array = []
var _spawners: Array = []
var _fade_overlay: ColorRect = null
var _clear_check_timer: Timer = null

func _ready() -> void:
	add_to_group("rooms")
	
	# Create fade overlay first (so it's on top)
	_create_fade_overlay()
	
	# Spawn atmospheric elements
	_spawn_floor_debris()
	_spawn_wall_sconces()
	
	# Find interactive elements
	_find_doors()
	_find_enemies()
	_find_spawners()
	
	if _enemies.size() > 0 or _spawners.size() > 0:
		_lock_doors()
		_start_clear_check_timer()
	else:
		is_cleared = true
		_unlock_doors()
	
	_fade_from_black()
	
	# Notify memory system
	var main := get_tree().current_scene
	if main and main.has_method("_on_room_entered"):
		main._on_room_entered(self)

func _start_clear_check_timer() -> void:
	_clear_check_timer = Timer.new()
	_clear_check_timer.wait_time = 0.5
	_clear_check_timer.timeout.connect(_check_clear_condition)
	add_child(_clear_check_timer)
	_clear_check_timer.start()

func _spawn_floor_debris() -> void:
	var debris_count := randi_range(8, 16)
	var room_width := 640.0
	var room_height := 480.0
	
	var debris_types := [
		{"size": Vector2(8, 6), "color": Color(0.4, 0.35, 0.3, 0.6)},  # small rock
		{"size": Vector2(12, 4), "color": Color(0.5, 0.45, 0.4, 0.5)},  # bone
		{"size": Vector2(6, 6), "color": Color(0.3, 0.25, 0.2, 0.7)},  # crack
	]
	
	for i in range(debris_count):
		var debris := ColorRect.new()
		var template: Dictionary = debris_types[randi() % debris_types.size()]
		debris.size = template["size"]
		debris.color = template["color"]
		debris.position = Vector2(
			randf_range(60, room_width - 60),
			randf_range(60, room_height - 60)
		)
		debris.rotation = randf_range(0, TAU)
		debris.z_index = -5
		add_child(debris)

func _spawn_wall_sconces() -> void:
	var sconce_count := randi_range(3, 6)
	var room_width := 640.0
	var room_height := 480.0
	
	# Wall positions: top, bottom, left, right
	var wall_positions := [
		{"x_range": [100.0, room_width - 100.0], "y": 40.0, "vertical": false},  # top
		{"x_range": [100.0, room_width - 100.0], "y": room_height - 40.0, "vertical": false},  # bottom
		{"x": 40.0, "y_range": [100.0, room_height - 100.0], "vertical": true},  # left
		{"x": room_width - 40.0, "y_range": [100.0, room_height - 100.0], "vertical": true},  # right
	]
	
	for i in range(sconce_count):
		var wall: Dictionary = wall_positions[randi() % wall_positions.size()]
		var sconce := Node2D.new()
		
		# Position on selected wall
		if wall.get("vertical", false):
			sconce.position = Vector2(
				wall["x"],
				randf_range(wall["y_range"][0], wall["y_range"][1])
			)
		else:
			sconce.position = Vector2(
				randf_range(wall["x_range"][0], wall["x_range"][1]),
				wall["y"]
			)
		
		# Iron bracket
		var bracket := ColorRect.new()
		bracket.size = Vector2(8, 16)
		bracket.position = Vector2(-4, -8)
		bracket.color = Color(0.25, 0.25, 0.25, 1.0)
		sconce.add_child(bracket)
		
		# Flame visual
		var flame := ColorRect.new()
		flame.size = Vector2(10, 12)
		flame.position = Vector2(-5, -20)
		flame.color = Color(1.0, 0.6, 0.1, 0.9)
		flame.z_index = 1
		sconce.add_child(flame)
		
		# Glow effect
		var glow := ColorRect.new()
		glow.size = Vector2(24, 24)
		glow.position = Vector2(-12, -26)
		glow.color = Color(1.0, 0.5, 0.1, 0.15)
		glow.z_index = 0
		sconce.add_child(glow)
		
		# Flicker script (inline)
		var flicker_script := GDScript.new()
		flicker_script.source_code = """
extends Node2D

var _time: float = 0.0
var _flicker_offset: float = 0.0

func _ready() -> void:
	_flicker_offset = randf_range(0.0, TAU)

func _physics_process(delta: float) -> void:
	_time += delta
	var phase := _time * 3.0 + _flicker_offset
	
	# Flame flicker
	var flame := get_child(1) as ColorRect
	if flame:
		var flicker := 1.0 + sin(phase * 2.3) * 0.15 + sin(phase * 5.7) * 0.08
		flame.size.y = 12.0 * flicker
		flame.color.a = 0.9 + sin(phase * 1.8) * 0.1
	
	# Glow pulse
	var glow := get_child(2) as ColorRect
	if glow:
		var pulse := 1.0 + sin(phase * 0.8) * 0.2
		glow.size = Vector2(24, 24) * pulse
		glow.position = Vector2(-12, -26) * pulse
"""
		flicker_script.reload()
		sconce.set_script(flicker_script)
		
		add_child(sconce)

func _create_fade_overlay() -> void:
	_fade_overlay = ColorRect.new()
	_fade_overlay.color = Color(0, 0, 0, 1)
	_fade_overlay.anchor_right = 1.0
	_fade_overlay.anchor_bottom = 1.0
	_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_overlay.z_index = 1000
	add_child(_fade_overlay)

func _fade_from_black() -> void:
	if not _fade_overlay:
		return
	var tween := create_tween()
	tween.tween_property(_fade_overlay, "color:a", 0.0, 0.4)

func _fade_to_black() -> void:
	if not _fade_overlay:
		return
	var tween := create_tween()
	tween.tween_property(_fade_overlay, "color:a", 1.0, 0.3)
	await tween.finished

func _find_doors() -> void:
	var doors_container := get_node_or_null("Doors")
	if doors_container:
		for child in doors_container.get_children():
			if child is Area2D:
				_doors.append(child)
				child.body_entered.connect(_on_door_body_entered.bind(child))

func _find_enemies() -> void:
	var enemies_container := get_node_or_null("Enemies")
	if enemies_container:
		for child in enemies_container.get_children():
			if child.is_in_group("enemies"):
				_enemies.append(child)

func _find_spawners() -> void:
	var enemies_container := get_node_or_null("Enemies")
	if enemies_container:
		for child in enemies_container.get_children():
			if child.has_method("get_enemy_type"):
				_spawners.append(child)

func _lock_doors() -> void:
	for door in _doors:
		if door.has_node("ColorRect"):
			door.get_node("ColorRect").color = Color(0.8, 0.2, 0.2, 1.0)

func _unlock_doors() -> void:
	for door in _doors:
		if door.has_node("ColorRect"):
			door.get_node("ColorRect").color = Color(0.2, 0.8, 0.2, 1.0)

func _check_clear_condition() -> void:
	# Count valid enemies
	var valid_enemies := 0
	for enemy in _enemies:
		if is_instance_valid(enemy):
			valid_enemies += 1
	
	# Count valid spawners
	var valid_spawners := 0
	for spawner in _spawners:
		if is_instance_valid(spawner):
			valid_spawners += 1
	
	# Clear condition: no enemies AND no spawners
	if valid_enemies == 0 and valid_spawners == 0:
		if not is_cleared:
			is_cleared = true
			_unlock_doors()
			room_cleared.emit()
			if _clear_check_timer:
				_clear_check_timer.stop()

func _on_door_body_entered(body: Node2D, door: Area2D) -> void:
	if not body.is_in_group("player"):
		return
	
	var target: String = door.get_meta("target_room_id", "")
	if target.is_empty():
		return
	
	_transition_to_room(target)

func _transition_to_room(target_room_id: String) -> void:
	await _fade_to_black()
	
	var room_scenes := {
		"corridor": "res://scenes/room_corridor.tscn",
		"arena": "res://scenes/room_arena.tscn",
		"treasure": "res://scenes/room_treasure.tscn",
		"boss": "res://scenes/room_boss.tscn",
	}
	
	var scene_path: String = room_scenes.get(target_room_id, "res://scenes/room_corridor.tscn")
	var scene := load(scene_path) as PackedScene
	if not scene:
		return
	
	var new_room: Node = scene.instantiate()
	new_room.name = "CurrentRoom"
	
	var main := get_tree().current_scene
	var player := main.get_node_or_null("Player")
	
	if player:
		main.remove_child(player)
	
	main.remove_child(self)
	queue_free()
	
	main.add_child(new_room)
	
	if player:
		main.add_child(player)
		player.global_position = Vector2(320, 400)