extends RoomBase

@export var footstep_interval: float = 0.35
@export var min_speed_threshold: float = 20.0

var _footstep_timer: float = 0.0
var _last_player_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	super._ready()
	_spawn_footstep_listener()

func _spawn_footstep_listener() -> void:
	var listener := Node.new()
	listener.name = "FootstepListener"
	add_child(listener)
	
	var script := GDScript.new()
	script.source_code = """
extends Node

var parent_room: Node2D
var footstep_timer: float = 0.0
var footstep_interval: float = 0.35
var min_speed: float = 20.0

func _ready() -> void:
	parent_room = get_parent()
	footstep_interval = parent_room.get('footstep_interval')
	min_speed = parent_room.get('min_speed_threshold')

func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group('player') as Node2D
	if not player:
		return
	
	var velocity := player.get('velocity')
	if velocity == null:
		return
	
	var speed := (velocity as Vector2).length()
	
	if speed < min_speed:
		footstep_timer = 0.0
		return
	
	# Adjust interval based on speed (faster = more frequent clicks)
	var adjusted_interval := footstep_interval * (100.0 / speed)
	adjusted_interval = clamp(adjusted_interval, 0.15, 0.6)
	
	footstep_timer += delta
	if footstep_timer >= adjusted_interval:
		footstep_timer = 0.0
		_play_footstep_sound(player.global_position)

func _play_footstep_sound(pos: Vector2) -> void:
	var player := AudioStreamPlayer.new()
	player.volume_db = -18.0
	get_tree().current_scene.add_child(player)
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.08
	player.stream = gen
	player.play()
	
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback:
		var frames := int(gen.mix_rate * 0.08)
		# Stone click = brief noise burst with decay
		var phase := randf() * TAU
		for i in range(frames):
			var t := float(i) / frames
			var noise := randf() * 2.0 - 1.0  # White noise
			var decay := 1.0 - (t * t * t)  # Fast decay
			var sample := noise * decay * 0.15
			playback.push_frame(Vector2(sample, sample))
	
	await get_tree().create_timer(0.1).timeout
	player.queue_free()
"""
	script.reload()
	listener.set_script(script)