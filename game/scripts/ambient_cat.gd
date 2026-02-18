extends CharacterBody2D

@export var wander_speed: float = 30.0
@export var hunt_speed: float = 80.0
@export var detection_range: float = 120.0
@export var rest_interval: float = 5.0

var _state: String = "wander"  # wander, hunt, rest
var _wander_timer: float = 0.0
var _wander_direction: Vector2 = Vector2.ZERO
var _rest_timer: float = 0.0
var _target_rat: Node2D = null
var _eye_blink_timer: float = 0.0

func _ready() -> void:
	collision_layer = 0  # Don't collide with anything
	collision_mask = 0
	add_to_group("ambient_cat")
	_create_visuals()
	_randomize_wander()

func _create_visuals() -> void:
	# Body
	var body := ColorRect.new()
	body.size = Vector2(20, 14)
	body.position = Vector2(-10, -7)
	body.color = Color(0.3, 0.25, 0.2, 1.0)
	add_child(body)
	
	# Tail
	var tail := ColorRect.new()
	tail.size = Vector2(12, 3)
	tail.position = Vector2(-16, -2)
	tail.color = Color(0.25, 0.2, 0.15, 1.0)
	add_child(tail)
	
	# Eyes
	var left_eye := ColorRect.new()
	left_eye.size = Vector2(3, 4)
	left_eye.position = Vector2(-4, -4)
	left_eye.color = Color(0.9, 0.8, 0.2, 1.0)
	left_eye.name = "LeftEye"
	add_child(left_eye)
	
	var right_eye := ColorRect.new()
	right_eye.size = Vector2(3, 4)
	right_eye.position = Vector2(3, -4)
	right_eye.color = Color(0.9, 0.8, 0.2, 1.0)
	right_eye.name = "RightEye"
	add_child(right_eye)

func _physics_process(delta: float) -> void:
	_eye_blink_timer += delta
	if _eye_blink_timer >= 3.0:
		_blink_eyes()
		_eye_blink_timer = randf() * 2.0
	
	match _state:
		"wander":
			_wander_behavior(delta)
		"hunt":
			_hunt_behavior(delta)
		"rest":
			_rest_behavior(delta)
	
	move_and_slide()

func _wander_behavior(delta: float) -> void:
	# Check for nearby rats
	var rats := get_tree().get_nodes_in_group("ambient_rat")
	for rat in rats:
		if is_instance_valid(rat) and rat is Node2D:
			var dist := global_position.distance_to(rat.global_position)
			if dist < detection_range:
				_state = "hunt"
				_target_rat = rat
				_play_meow()
				return
	
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_randomize_wander()
	
	velocity = _wander_direction * wander_speed
	
	# Randomly decide to rest
	if randf() < 0.005:  # 0.5% chance per frame
		_state = "rest"
		_rest_timer = rest_interval
		velocity = Vector2.ZERO

func _hunt_behavior(delta: float) -> void:
	if not is_instance_valid(_target_rat):
		_state = "wander"
		_randomize_wander()
		return
	
	var direction := global_position.direction_to(_target_rat.global_position)
	velocity = direction * hunt_speed
	
	# Catch the rat
	if global_position.distance_to(_target_rat.global_position) < 15.0:
		_target_rat.queue_free()
		_play_purr()
		_state = "rest"
		_rest_timer = rest_interval * 1.5
		velocity = Vector2.ZERO

func _rest_behavior(delta: float) -> void:
	_rest_timer -= delta
	if _rest_timer <= 0.0:
		_state = "wander"
		_randomize_wander()

func _randomize_wander() -> void:
	var angle := randf() * TAU
	_wander_direction = Vector2(cos(angle), sin(angle))
	_wander_timer = 2.0 + randf() * 3.0

func _blink_eyes() -> void:
	var left := get_node_or_null("LeftEye")
	var right := get_node_or_null("RightEye")
	if left and right:
		var tween := create_tween()
		tween.tween_property(left, "size:y", 1.0, 0.1)
		tween.parallel().tween_property(right, "size:y", 1.0, 0.1)
		tween.tween_property(left, "size:y", 4.0, 0.1)
		tween.parallel().tween_property(right, "size:y", 4.0, 0.1)

func _play_meow() -> void:
	var player := AudioStreamPlayer.new()
	get_tree().current_scene.add_child(player)
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.3
	player.stream = gen
	player.volume_db = -18.0
	player.play()
	
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback:
		var frames := 256
		var phase := 0.0
		for i in range(frames):
			var t := float(i) / frames
			var freq := 600.0 + sin(t * TAU * 3.0) * 200.0
			phase += freq / gen.mix_rate
			var sample := sin(phase * TAU) * 0.2 * (1.0 - t * 0.5)
			playback.push_frame(Vector2(sample, sample))
	
	await get_tree().create_timer(0.35).timeout
	player.queue_free()

func _play_purr() -> void:
	var player := AudioStreamPlayer.new()
	get_tree().current_scene.add_child(player)
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.5
	player.stream = gen
	player.volume_db = -20.0
	player.play()
	
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback:
		var frames := 256
		var phase := 0.0
		for i in range(frames):
			var t := float(i) / frames
			var freq := 80.0 + sin(t * TAU * 8.0) * 20.0
			phase += freq / gen.mix_rate
			var sample := sin(phase * TAU) * 0.15
			playback.push_frame(Vector2(sample, sample))
	
	await get_tree().create_timer(0.55).timeout
	player.queue_free()