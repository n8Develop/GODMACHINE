extends Node
## Autopilot — simulates gameplay during Movie Maker recording.
## Only activates when Godot runs with --write-movie (OS.has_feature("movie")).
## Registered as an autoload; does nothing during normal play or headless testing.

var _player: Node2D
var _move_dir := Vector2.ZERO
var _move_timer := 0.0
var _attack_timer := 0.0
var _stuck_timer := 0.0
var _last_pos := Vector2.ZERO
var _change_interval := 1.5


func _ready() -> void:
	if not OS.has_feature("movie"):
		set_physics_process(false)
		return
	# Wait for scene tree to initialize
	await get_tree().process_frame
	await get_tree().process_frame
	_player = get_tree().get_first_node_in_group("player")
	if not _player:
		push_warning("Autopilot: no player found")
		set_physics_process(false)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		if not _player:
			return

	_move_timer += delta
	_attack_timer += delta

	# Detect stuck (wall collision)
	if _player.global_position.distance_to(_last_pos) < 0.5:
		_stuck_timer += delta
	else:
		_stuck_timer = 0.0
	_last_pos = _player.global_position

	# --- Decide behavior ---
	var nearest_enemy := _find_nearest("enemies")
	var nearest_pickup := _find_nearest("pickups")

	if nearest_enemy and _player.global_position.distance_to(nearest_enemy.global_position) < 150.0:
		# Chase enemy and attack
		_move_dir = _player.global_position.direction_to(nearest_enemy.global_position)
		if _attack_timer >= 0.6:
			_attack_timer = 0.0
			Input.action_press(&"attack")
			get_tree().create_timer(0.15).timeout.connect(_release_attack)
	elif nearest_pickup and _player.global_position.distance_to(nearest_pickup.global_position) < 200.0:
		# Move toward pickup
		_move_dir = _player.global_position.direction_to(nearest_pickup.global_position)
	elif _stuck_timer > 0.4 or _move_timer >= _change_interval:
		# Wander: pick a new direction
		_move_timer = 0.0
		_stuck_timer = 0.0
		_move_dir = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
		_change_interval = randf_range(0.8, 2.5)
		# Occasionally pause
		if randf() < 0.1:
			_move_dir = Vector2.ZERO

	_apply_movement()


func _apply_movement() -> void:
	Input.action_release(&"move_left")
	Input.action_release(&"move_right")
	Input.action_release(&"move_up")
	Input.action_release(&"move_down")

	if _move_dir.x < -0.3:
		Input.action_press(&"move_left")
	elif _move_dir.x > 0.3:
		Input.action_press(&"move_right")
	if _move_dir.y < -0.3:
		Input.action_press(&"move_up")
	elif _move_dir.y > 0.3:
		Input.action_press(&"move_down")


func _release_attack() -> void:
	Input.action_release(&"attack")


func _find_nearest(group: String) -> Node2D:
	var nodes := get_tree().get_nodes_in_group(group)
	var best: Node2D = null
	var best_dist := INF
	for node in nodes:
		if node is Node2D and is_instance_valid(node):
			var d := _player.global_position.distance_to(node.global_position)
			if d < best_dist:
				best_dist = d
				best = node
	return best
