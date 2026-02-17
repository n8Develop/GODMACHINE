extends Node2D
class_name RoomBase

signal room_cleared
signal player_entered
signal player_exited

@export var room_id: String = ""
@export var is_cleared: bool = false

var _doors: Array[Area2D] = []
var _enemies: Array[Node] = []

func _ready() -> void:
	_find_doors()
	_find_enemies()
	
	if _enemies.size() > 0:
		_lock_doors()

func _find_doors() -> void:
	var doors_container := get_node_or_null("Doors")
	if not doors_container:
		return
	
	for child in doors_container.get_children():
		if child is Area2D:
			_doors.append(child)
			child.body_entered.connect(_on_door_body_entered.bind(child))

func _find_enemies() -> void:
	var enemies_container := get_node_or_null("Enemies")
	if not enemies_container:
		return
	
	for child in enemies_container.get_children():
		_enemies.append(child)
		var health := child.get_node_or_null("HealthComponent") as HealthComponent
		if health:
			health.died.connect(_on_enemy_died)

func _lock_doors() -> void:
	for door in _doors:
		door.monitoring = false
		if door.has_node("ColorRect"):
			door.get_node("ColorRect").color = Color(0.5, 0.1, 0.1, 1.0)

func _unlock_doors() -> void:
	for door in _doors:
		door.monitoring = true
		if door.has_node("ColorRect"):
			door.get_node("ColorRect").color = Color(0.2, 0.9, 0.3, 1.0)

func _on_enemy_died() -> void:
	_check_clear_condition()

func _check_clear_condition() -> void:
	var alive_count := 0
	for enemy in _enemies:
		if is_instance_valid(enemy):
			alive_count += 1
	
	if alive_count == 0 and not is_cleared:
		is_cleared = true
		_unlock_doors()
		room_cleared.emit()

func _on_door_body_entered(body: Node2D, door: Area2D) -> void:
	if body.is_in_group("player"):
		var target_room := door.get_meta("target_room", "") as String
		if target_room != "":
			# Track room visit
			var visited := body.get_meta("rooms_visited", []) as Array
			if not visited.has(room_id):
				visited.append(room_id)
				body.set_meta("rooms_visited", visited)
			
			_transition_to_room(target_room)

func _get_door_from_body(body: Node2D) -> Area2D:
	for door in _doors:
		if door == body:
			return door
	return null

func _transition_to_room(target_room_id: String) -> void:
	print("GODMACHINE: transition to room '%s' not yet implemented" % target_room_id)