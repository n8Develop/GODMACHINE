extends CharacterBody2D

@export var wander_speed: float = 30.0
@export var flee_speed: float = 120.0
@export var detection_range: float = 80.0
@export var wander_interval: float = 2.0

var _wander_timer: float = 0.0
var _wander_dir: Vector2 = Vector2.ZERO
var _is_fleeing: bool = false
var _flee_timer: float = 0.0
var _squeak_timer: float = 0.0

func _ready() -> void:
	add_to_group("vermin")
	_randomize_wander()
	collision_layer = 0  # Don't collide with anything
	collision_mask = 1   # Detect walls only

func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	
	if player and is_instance_valid(player):
		var distance := global_position.distance_to(player.global_position)
		
		# Flee if player is too close
		if distance < detection_range:
			if not _is_fleeing:
				_start_fleeing(player.global_position)
			_flee_timer = 2.0
	
	if _is_fleeing:
		_flee_timer -= delta
		if _flee_timer <= 0.0:
			_is_fleeing = false
			_randomize_wander()
	
	# Movement behavior
	if _is_fleeing:
		velocity = _wander_dir * flee_speed
	else:
		_wander_timer -= delta
		if _wander_timer <= 0.0:
			_randomize_wander()
		velocity = _wander_dir * wander_speed
	
	move_and_slide()
	
	# Squeak occasionally when fleeing
	if _is_fleeing:
		_squeak_timer -= delta
		if _squeak_timer <= 0.0:
			_squeak()
			_squeak_timer = randf_range(0.8, 1.5)

func _randomize_wander() -> void:
	_wander_timer = wander_interval + randf_range(-0.5, 0.5)
	var angle := randf() * TAU
	_wander_dir = Vector2(cos(angle), sin(angle))

func _start_fleeing(threat_pos: Vector2) -> void:
	_is_fleeing = true
	# Flee away from threat
	_wander_dir = global_position.direction_to(threat_pos) * -1.0
	_squeak()

func _squeak() -> void:
	var player := AudioStreamPlayer.new()
	get_tree().current_scene.add_child(player)
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.08
	player.stream = gen
	player.volume_db = -18.0
	player.play()
	
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback:
		var frames := int(gen.mix_rate * 0.08)
		var phase := 0.0
		for i in range(frames):
			var t := float(i) / frames
			var freq := 2400.0 + (randf() * 400.0)  # High-pitched squeak
			phase += freq / gen.mix_rate
			var sample := sin(phase * TAU) * 0.15 * (1.0 - t)
			playback.push_frame(Vector2(sample, sample))
	
	await get_tree().create_timer(0.1).timeout
	player.queue_free()