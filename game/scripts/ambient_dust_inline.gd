extends Node2D

## Inline dust mote system - spawns particles near player
## Avoids class_name to prevent main.gd parse errors

@export var mote_count: int = 20
@export var spawn_radius: float = 200.0
@export var drift_speed: float = 8.0
@export var respawn_distance: float = 250.0

var _motes: Array[ColorRect] = []
var _mote_velocities: Array[Vector2] = []
var _player: Node2D = null

func _ready() -> void:
	z_index = -2
	
	# Find player
	await get_tree().process_frame
	_player = get_tree().get_first_node_in_group("player")
	
	if not _player:
		queue_free()
		return
	
	# Spawn initial motes
	for i in range(mote_count):
		_spawn_mote()

func _spawn_mote() -> void:
	var mote := ColorRect.new()
	mote.size = Vector2(2, 2)
	mote.color = Color(0.9, 0.9, 0.85, randf_range(0.15, 0.35))
	
	# Random position around player
	var angle := randf() * TAU
	var distance := randf_range(20.0, spawn_radius)
	var offset := Vector2(cos(angle), sin(angle)) * distance
	mote.position = offset - Vector2(1, 1)
	
	add_child(mote)
	_motes.append(mote)
	
	# Random drift velocity
	var drift_angle := randf() * TAU
	var drift_mag := randf_range(drift_speed * 0.5, drift_speed)
	_mote_velocities.append(Vector2(cos(drift_angle), sin(drift_angle)) * drift_mag)

func _physics_process(delta: float) -> void:
	if not _player or not is_instance_valid(_player):
		return
	
	# Keep system centered on player
	global_position = _player.global_position
	
	# Update each mote
	for i in range(_motes.size()):
		if i >= _mote_velocities.size():
			break
		
		var mote := _motes[i]
		if not is_instance_valid(mote):
			continue
		
		# Drift motion
		mote.position += _mote_velocities[i] * delta
		
		# Gentle sine wave
		var phase := Time.get_ticks_msec() * 0.001 + (i * 0.3)
		mote.position.y += sin(phase * 2.0) * 0.3
		
		# Respawn if too far
		var dist := mote.position.length()
		if dist > respawn_distance:
			var angle := randf() * TAU
			var spawn_dist := randf_range(20.0, spawn_radius)
			mote.position = Vector2(cos(angle), sin(angle)) * spawn_dist
			
			# New velocity
			var drift_angle := randf() * TAU
			var drift_mag := randf_range(drift_speed * 0.5, drift_speed)
			_mote_velocities[i] = Vector2(cos(drift_angle), sin(drift_angle)) * drift_mag