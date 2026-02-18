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
	_spawn_wall_cracks()
	
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
	
	for i in range(debris_count):
		var debris := ColorRect.new()
		var debris_type := randi() % 3
		
		if debris_type == 0:  # small rock
			debris.size = Vector2(8, 6)
			debris.color = Color(0.4, 0.35, 0.3, 0.6)
		elif debris_type == 1:  # bone
			debris.size = Vector2(12, 4)
			debris.color = Color(0.5, 0.45, 0.4, 0.5)
		else:  # crack
			debris.size = Vector2(16, 2)
			debris.color = Color(0.2, 0.2, 0.25, 0.4)
		
		debris.position = Vector2(
			randf_range(40, room_width - 40),
			randf_range(40, room_height - 40)
		)
		debris.rotation = randf_range(0, TAU)
		debris.z_index = -5
		add_child(debris)

func _spawn_wall_sconces() -> void:
	var sconce_count := randi_range(3, 6)
	var wall_positions: Array[Dictionary] = [
		{"x": 40, "y_range": Vector2(100, 380)},   # left wall
		{"x": 600, "y_range": Vector2(100, 380)},  # right wall
		{"x_range": Vector2(180, 460), "y": 40},   # top wall
		{"x_range": Vector2(180, 460), "y": 440}   # bottom wall
	]
	
	for i in range(sconce_count):
		var wall_def: Dictionary = wall_positions[randi() % wall_positions.size()]
		var sconce := Node2D.new()
		
		if wall_def.has("x_range"):
			sconce.position = Vector2(
				randf_range(wall_def.x_range.x, wall_def.x_range.y),
				wall_def.y
			)
		else:
			sconce.position = Vector2(
				wall_def.x,
				randf_range(wall_def.y_range.x, wall_def.y_range.y)
			)
		
		# Iron bracket
		var bracket := ColorRect.new()
		bracket.size = Vector2(8, 12)
		bracket.position = Vector2(-4, -6)
		bracket.color = Color(0.3, 0.3, 0.35, 1.0)
		sconce.add_child(bracket)
		
		# Flame
		var flame := ColorRect.new()
		flame.size = Vector2(6, 8)
		flame.position = Vector2(-3, -12)
		flame.color = Color(1.0, 0.6, 0.2, 0.9)
		flame.z_index = 1
		sconce.add_child(flame)
		
		# Glow
		var glow := ColorRect.new()
		glow.size = Vector2(20, 20)
		glow.position = Vector2(-10, -16)
		glow.color = Color(1.0, 0.5, 0.1, 0.15)
		sconce.add_child(glow)
		
		# Flicker script
		var flicker := GDScript.new()
		flicker.source_code = """
extends Node2D

var time := randf_range(0, TAU)

func _physics_process(delta: float) -> void:
	time += delta * 3.0
	var flame := get_child(1) as ColorRect
	var glow := get_child(2) as ColorRect
	if flame:
		flame.modulate.a = 0.85 + sin(time) * 0.15
		flame.size.y = 8.0 + sin(time * 2.0) * 1.5
	if glow:
		glow.modulate.a = 0.15 + sin(time * 0.7) * 0.05
"""
		flicker.reload()
		sconce.set_script(flicker)
		
		add_child(sconce)

func _spawn_wall_cracks() -> void:
	var crack_count := randi_range(6, 12)
	var wall_edges: Array[Dictionary] = [
		{"x": 20, "y_range": Vector2(60, 420), "is_vertical": true},   # left
		{"x": 620, "y_range": Vector2(60, 420), "is_vertical": true},  # right
		{"x_range": Vector2(100, 540), "y": 20, "is_vertical": false}, # top
		{"x_range": Vector2(100, 540), "y": 460, "is_vertical": false} # bottom
	]
	
	for i in range(crack_count):
		var edge: Dictionary = wall_edges[randi() % wall_edges.size()]
		var crack := ColorRect.new()
		
		if edge.is_vertical:
			crack.size = Vector2(2, randf_range(12, 28))
			crack.position = Vector2(
				edge.x,
				randf_range(edge.y_range.x, edge.y_range.y)
			)
		else:
			crack.size = Vector2(randf_range(12, 28), 2)
			crack.position = Vector2(
				randf_range(edge.x_range.x, edge.x_range.y),
				edge.y
			)
		
		crack.color = Color(0.15, 0.15, 0.2, randf_range(0.4, 0.7))
		crack.rotation = randf_range(-0.2, 0.2)
		crack.z_index = -3
		add_child(crack)

func _create_fade_overlay() -> void:
	_fade_overlay = ColorRect.new()
	_fade_overlay.color = Color(0, 0, 0, 1)
	_fade_overlay.anchor_right = 1.0
	_fade_overlay.anchor_bottom = 1.0
	_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_overlay.z_index = 1000
	get_tree().current_scene.get_node("CanvasLayer").add_child(_fade_overlay)

func _fade_from_black() -> void:
	if _fade_overlay:
		var tween := create_tween()
		tween.tween_property(_fade_overlay, "modulate:a", 0.0, 0.3)
		await tween.finished

func _fade_to_black() -> void:
	if _fade_overlay:
		var tween := create_tween()
		tween.tween_property(_fade_overlay, "modulate:a", 1.0, 0.3)
		await tween.finished

func _find_doors() -> void:
	_doors.clear()
	var doors_container := get_node_or_null("Doors")
	if doors_container:
		for child in doors_container.get_children():
			if child is Area2D:
				_doors.append(child)
				child.body_entered.connect(_on_door_body_entered.bind(child))

func _find_enemies() -> void:
	_enemies.clear()
	var enemies_container := get_node_or_null("Enemies")
	if enemies_container:
		for child in enemies_container.get_children():
			if child.is_in_group("enemies"):
				_enemies.append(child)

func _find_spawners() -> void:
	_spawners.clear()
	var enemies_container := get_node_or_null("Enemies")
	if enemies_container:
		for child in enemies_container.get_children():
			if child.has_method("get_enemy_type"):
				_spawners.append(child)

func _lock_doors() -> void:
	for door in _doors:
		door.set_meta("locked", true)

func _unlock_doors() -> void:
	for door in _doors:
		door.set_meta("locked", false)

func _check_clear_condition() -> void:
	var all_enemies_dead := true
	for enemy in _enemies:
		if is_instance_valid(enemy):
			all_enemies_dead = false
			break
	
	var all_spawners_dead := true
	for spawner in _spawners:
		if is_instance_valid(spawner):
			all_spawners_dead = false
			break
	
	if all_enemies_dead and all_spawners_dead:
		if not is_cleared:
			is_cleared = true
			_unlock_doors()
			room_cleared.emit()
		if _clear_check_timer:
			_clear_check_timer.stop()

func _on_door_body_entered(body: Node2D, door: Area2D) -> void:
	if not body.is_in_group("player"):
		return
	
	if door.get_meta("locked", false):
		return
	
	var target_room_id: String = door.get_meta("target_room_id", "")
	if target_room_id != "":
		await _fade_to_black()
		_transition_to_room(target_room_id)

func _transition_to_room(target_room_id: String) -> void:
	var room_scenes := {
		"corridor": "res://scenes/room_corridor.tscn",
		"arena": "res://scenes/room_arena.tscn",
		"treasure": "res://scenes/room_treasure.tscn",
		"boss": "res://scenes/room_boss.tscn",
		"start": "res://scenes/room_start.tscn"
	}
	
	var scene_path: String = room_scenes.get(target_room_id, "res://scenes/room_corridor.tscn")
	var new_scene: PackedScene = load(scene_path)
	
	if new_scene:
		var new_room: Node = new_scene.instantiate()
		var main := get_tree().current_scene
		var old_room := main.get_node_or_null("CurrentRoom")
		
		if old_room:
			old_room.queue_free()
		
		new_room.name = "CurrentRoom"
		main.add_child(new_room)
		
		var player := main.get_node_or_null("Player")
		if player:
			player.global_position = Vector2(320, 400)