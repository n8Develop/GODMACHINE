extends Node2D
class_name RoomBase

signal room_cleared

@export var room_id: String = ""
@export var is_cleared: bool = false

var _doors: Array[Area2D] = []
var _enemies: Array[Node] = []

func _ready() -> void:
	_find_doors()
	_find_enemies()
	_spawn_ambient_crows()
	_spawn_dust_motes()
	
	if _enemies.size() > 0:
		_lock_doors()

func _spawn_dust_motes() -> void:
	var dust_scene := load("res://scenes/ambient_dust_inline.tscn") as PackedScene
	if dust_scene:
		var dust := dust_scene.instantiate()
		add_child(dust)

func _spawn_ambient_crows() -> void:
	for i in range(randi_range(1, 3)):
		var crow_scene := load("res://scenes/ambient_crow.tscn") as PackedScene
		if crow_scene:
			var crow := crow_scene.instantiate()
			var spawn_x := randf_range(100, 540)
			var spawn_y := randf_range(80, 180)
			crow.position = Vector2(spawn_x, spawn_y)
			add_child(crow)

func _find_doors() -> void:
	_doors.clear()
	for child in get_children():
		if child.has_signal("body_entered"):
			if child.get_meta("is_door", false):
				_doors.append(child)

func _find_enemies() -> void:
	_enemies.clear()
	for child in get_children():
		if child.is_in_group("enemies"):
			_enemies.append(child)
			if child.has_signal("died"):
				child.died.connect(_on_enemy_died)

func _lock_doors() -> void:
	for door in _doors:
		door.monitoring = false

func _unlock_doors() -> void:
	for door in _doors:
		door.monitoring = true
	room_cleared.emit()

func _on_enemy_died() -> void:
	await get_tree().create_timer(0.1).timeout
	
	var alive_count := 0
	for enemy in _enemies:
		if is_instance_valid(enemy):
			alive_count += 1
	
	if alive_count == 0:
		is_cleared = true
		_unlock_doors()