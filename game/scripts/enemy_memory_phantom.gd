extends CharacterBody2D

@export var drift_speed: float = 20.0
@export var replay_interval: float = 8.0
@export var replay_duration: float = 3.0
@export var echo_damage: int = 10
@export var memory_range: float = 200.0

var _replay_timer: float = 0.0
var _is_replaying: bool = false
var _replay_lifetime: float = 0.0
var _stored_player_path: Array[Vector2] = []
var _path_index: int = 0
var _recording: bool = true

func _ready() -> void:
	add_to_group("enemies")
	
	# Create visual
	var sprite := ColorRect.new()
	sprite.size = Vector2(28, 28)
	sprite.position = Vector2(-14, -14)
	sprite.color = Color(0.4, 0.3, 0.6, 0.5)
	add_child(sprite)
	
	# Create collision
	var shape := CircleShape2D.new()
	shape.radius = 14.0
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	
	# Health component
	var health := load("res://scripts/health_component.gd").new()
	health.name = "HealthComponent"
	health.max_health = 45
	health.current_health = 45
	add_child(health)
	health.died.connect(_on_died)
	
	_create_memory_hum()

func _create_memory_hum() -> void:
	var audio := AudioStreamPlayer.new()
	audio.name = "MemoryHum"
	add_child(audio)
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.1
	audio.stream = gen
	audio.volume_db = -26.0
	audio.autoplay = true
	
	call_deferred("_generate_memory_loop", audio)

func _generate_memory_loop(player: AudioStreamPlayer) -> void:
	await get_tree().process_frame
	if not is_instance_valid(player):
		return
	
	player.play()
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if not playback:
		return
	
	var phase := randf() * TAU
	while is_instance_valid(self):
		var frames_available := playback.get_frames_available()
		if frames_available > 0:
			var frames_to_gen := mini(frames_available, 64)
			for i in range(frames_to_gen):
				var freq := 220.0 + sin(Time.get_ticks_msec() * 0.0003) * 40.0
				phase += freq / 22050.0
				var sample := sin(phase * TAU) * 0.15
				playback.push_frame(Vector2(sample, sample))
		await get_tree().process_frame

func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if not player:
		return
	
	var distance := global_position.distance_to(player.global_position)
	
	# Record player movement when nearby
	if _recording and distance < memory_range:
		_stored_player_path.append(player.global_position)
		if _stored_player_path.size() > 180:  # 3 seconds at 60fps
			_stored_player_path.pop_front()
	
	_replay_timer += delta
	
	if not _is_replaying:
		# Idle drift
		var drift_angle := Time.get_ticks_msec() * 0.0008
		velocity = Vector2(cos(drift_angle), sin(drift_angle)) * drift_speed
		move_and_slide()
		
		# Start replay
		if _replay_timer >= replay_interval and _stored_player_path.size() > 30:
			_is_replaying = true
			_replay_lifetime = 0.0
			_path_index = 0
			_spawn_replay_text()
			_play_replay_sound()
	else:
		# Replay stored movement
		_replay_lifetime += delta
		
		if _replay_lifetime >= replay_duration or _path_index >= _stored_player_path.size():
			_is_replaying = false
			_replay_timer = 0.0
		else:
			# Move along stored path
			var target_index := int((_replay_lifetime / replay_duration) * _stored_player_path.size())
			target_index = clampi(target_index, 0, _stored_player_path.size() - 1)
			
			if target_index < _stored_player_path.size():
				var target_pos := _stored_player_path[target_index]
				var direction := global_position.direction_to(target_pos)
				velocity = direction * 150.0
				move_and_slide()
				
				# Damage player if touched during replay
				if distance < 32.0:
					var player_health := player.get_node_or_null("HealthComponent")
					if player_health and player_health.has_method("take_damage"):
						player_health.take_damage(echo_damage)
						_spawn_damage_number(player.global_position, echo_damage)
						_is_replaying = false
						_replay_timer = 0.0
	
	# Update visual during replay
	if has_node("ColorRect"):
		var sprite := get_node("ColorRect") as ColorRect
		if _is_replaying:
			sprite.color = Color(0.7, 0.4, 0.8, 0.8)
		else:
			sprite.color = Color(0.4, 0.3, 0.6, 0.5)

func _spawn_replay_text() -> void:
	var label := Label.new()
	label.text = "REPLAYING..."
	label.add_theme_color_override(&"font_color", Color(0.7, 0.5, 0.9, 1.0))
	label.add_theme_font_size_override(&"font_size", 14)
	label.position = global_position + Vector2(-40, -40)
	label.z_index = 100
	get_tree().current_scene.add_child(label)
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 30, 1.5)
	tween.tween_property(label, "modulate:a", 0.0, 1.5)
	tween.finished.connect(label.queue_free)

func _spawn_damage_number(pos: Vector2, damage: int) -> void:
	var label := Label.new()
	label.text = str(damage)
	label.add_theme_color_override(&"font_color", Color(0.8, 0.4, 0.9, 1.0))
	label.add_theme_font_size_override(&"font_size", 18)
	label.position = pos + Vector2(-10, -30)
	label.z_index = 100
	get_tree().current_scene.add_child(label)
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", pos.y - 60, 0.6)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.finished.connect(label.queue_free)

func _play_replay_sound() -> void:
	var player := AudioStreamPlayer.new()
	get_tree().current_scene.add_child(player)
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.5
	player.stream = gen
	player.volume_db = -14.0
	player.play()
	
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback:
		var frames := int(gen.mix_rate * 0.5)
		var phase := randf() * TAU
		for i in range(frames):
			var t := float(i) / frames
			var freq := 400.0 - (t * 200.0)
			phase += freq / gen.mix_rate
			var sample := sin(phase * TAU) * 0.25 * (1.0 - t * 0.5)
			playback.push_frame(Vector2(sample, sample))
	
	await get_tree().create_timer(0.55).timeout
	player.queue_free()

func _on_died() -> void:
	_spawn_dissolve_effect()
	queue_free()

func _spawn_dissolve_effect() -> void:
	for i in range(8):
		var particle := ColorRect.new()
		particle.size = Vector2(6, 6)
		particle.position = global_position + Vector2(-3, -3)
		particle.color = Color(0.5, 0.3, 0.7, 0.8)
		particle.z_index = 50
		get_tree().current_scene.add_child(particle)
		
		var angle := (TAU / 8.0) * i
		var offset := Vector2(cos(angle), sin(angle)) * 40.0
		
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "position", global_position + offset, 0.8)
		tween.tween_property(particle, "modulate:a", 0.0, 0.8)
		tween.finished.connect(particle.queue_free)