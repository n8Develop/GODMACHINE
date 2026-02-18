extends Node2D
class_name RoomBase

signal room_cleared

@export var room_id: String = ""
@export var is_cleared: bool = false

var _doors: Array[Area2D] = []
var _enemies: Array = []

func _ready() -> void:
	add_to_group("rooms")
	_find_doors()
	_find_enemies()
	
	if _enemies.size() > 0:
		_lock_doors()
	else:
		is_cleared = true
		_unlock_doors()

func _find_doors() -> void:
	_doors.clear()
	var doors_container := get_node_or_null("Doors")
	if doors_container:
		for child in doors_container.get_children():
			if child is Area2D:
				_doors.append(child)

func _find_enemies() -> void:
	_enemies.clear()
	var enemies_container := get_node_or_null("Enemies")
	if enemies_container:
		for child in enemies_container.get_children():
			if child.is_in_group("enemies"):
				_enemies.append(child)

func _lock_doors() -> void:
	for door in _doors:
		if door and is_instance_valid(door):
			door.set_meta("locked", true)

func _unlock_doors() -> void:
	for door in _doors:
		if door and is_instance_valid(door):
			door.set_meta("locked", false)