extends Node2D
class_name RoomBase

signal room_cleared

@export var room_id: String = ""
@export var is_cleared: bool = false

var _doors: Array[Node] = []
var _enemies: Array[Node] = []

func _ready() -> void:
	_find_doors()
	_find_enemies()
	
	if _enemies.size() > 0:
		_lock_doors()
	
	# Spawn ambient creatures
	_spawn_ambient_crows()

func _spawn_ambient_crows() -> void:
	# Only spawn in some room types
	if room_id.contains("boss") or room_id.contains("treasure"):
		return
	
	var crow_scene := load("res://scenes/ambient_crow.tscn") as PackedScene
	if not crow_scene:
		return
	
	var spawn_count := randi_range(1, 3)
	
	for i in range(spawn_count):
		var crow := crow_scene.instantiate()
		
		# Perch on edges or corners
		var edge := randi() % 4
		var offset := randf_range(50.0, 250.0)
		
		match edge:
			0: crow.position = Vector2(offset, 50)  # Top
			1: crow.position = Vector2(offset, 430)  # Bottom
			2: crow.position = Vector2(50, offset)  # Left
			3: crow.position = Vector2(590, offset)  # Right
		
		add_child(crow)

func _find_doors() -> void:
	_doors.clear()
	for child in get_children():
		if child.name.begins_with("Door"):
			_doors.append(child)

func _find_enemies() -> void:
	_enemies.clear()
	for child in get_children():
		if child.is_in_group("enemies"):
			_enemies.append(child)

func _lock_doors() -> void:
	for door in _doors:
		if door.has_method("lock"):
			door.lock()

func _unlock_doors() -> void:
	for door in _doors:
		if door.has_method("unlock"):
			door.unlock()