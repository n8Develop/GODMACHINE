extends CharacterBody2D

@export var drift_speed: float = 35.0
@export var thread_spawn_interval: float = 2.5
@export var thread_lifetime: float = 12.0
@export var thread_damage: int = 6
@export var max_threads: int = 8
@export var weave_range: float = 250.0

var _thread_timer: float = 0.0
var _active_threads: Array = []
var _sprite: ColorRect = null

func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 2
	collision_mask = 1
	
	# Visual: Dark purple weaver with trailing tendrils
	_sprite = ColorRect.new()
	_sprite.size = Vector2(24, 24)
	_sprite.position = Vector2(-12, -12)
	_sprite.color = Color(0.25, 0.15, 0.35, 0.85)
	add_child(_sprite)
	
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 12.0
	collision.shape = shape
	add_child(collision)
	
	var health := load("res://scripts/health_component.gd").new()
	health.name = "HealthComponent"
	health.max_health = 35
	health.current_health = 35
	add_child(health)
	health.died.connect(_on_died)
	
	_create_weaver_hum()

func _create_weaver_hum() -> void:
	var player := AudioStreamPlayer.new()
	player.volume_db = -26.0
	add_child(player)
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.1
	player.stream = gen
	player.play()
	
	call_deferred("_generate_weaver_loop", player)

func _generate_weaver_loop(player: AudioStreamPlayer) -> void:
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if not playback:
		return
	
	var phase := randf() * TAU
	while is_instance_valid(player) and player.playing:
		var frames := 128
		for i in range(frames):
			phase += (180.0 / 22050.0) * TAU
			var sample := sin(phase) * 0.15
			playback.push_frame(Vector2(sample, sample))
		await get_tree().process_frame

func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not player or not is_instance_valid(player):
		return
	
	var distance := global_position.distance_to(player.global_position)
	
	# Slow circular drift around player
	if distance < weave_range:
		var to_player := global_position.direction_to(player.global_position)
		var tangent := Vector2(-to_player.y, to_player.x)  # Perpendicular
		velocity = tangent * drift_speed
		
		# Pulse visual while weaving
		if _sprite:
			var pulse := 0.85 + sin(Time.get_ticks_msec() * 0.003) * 0.15
			_sprite.modulate.a = pulse
	else:
		velocity = global_position.direction_to(player.global_position) * drift_speed * 0.5
	
	move_and_slide()
	
	# Spawn void threads
	_thread_timer += delta
	if _thread_timer >= thread_spawn_interval and _active_threads.size() < max_threads:
		_thread_timer = 0.0
		_spawn_void_thread()
	
	# Cleanup dead threads
	_active_threads = _active_threads.filter(func(t): return is_instance_valid(t))

func _spawn_void_thread() -> void:
	var thread := Area2D.new()
	thread.collision_layer = 0
	thread.collision_mask = 1
	thread.global_position = global_position
	
	var visual := Line2D.new()
	visual.width = 3.0
	visual.default_color = Color(0.3, 0.2, 0.4, 0.6)
	thread.add_child(visual)
	
	var collision := CollisionShape2D.new()
	var shape := SegmentShape2D.new()
	shape.a = Vector2.ZERO
	shape.b = Vector2.ZERO  # Will extend over time
	collision.shape = shape
	thread.add_child(collision)
	
	var script := GDScript.new()
	script.source_code = """
extends Area2D

var start_pos := Vector2.ZERO
var end_pos := Vector2.ZERO
var growth_speed := 80.0
var current_length := 0.0
var max_length := 120.0
var lifetime := 12.0
var damage := 6
var has_damaged := {}

func _ready() -> void:
	start_pos = global_position
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	
	# Grow thread toward end position
	if current_length < max_length:
		current_length += growth_speed * delta
		var direction := start_pos.direction_to(end_pos)
		var current_end := start_pos + (direction * current_length)
		
		var line := get_node_or_null('Line2D')
		if line:
			line.clear_points()
			line.add_point(Vector2.ZERO)
			line.add_point(to_local(current_end))
		
		var collision := get_node_or_null('CollisionShape2D')
		if collision and collision.shape is SegmentShape2D:
			collision.shape.b = to_local(current_end)
	
	# Fade out near end of lifetime
	if lifetime < 2.0:
		modulate.a = lifetime / 2.0

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group('player'):
		if has_damaged.has(body):
			return
		has_damaged[body] = true
		
		var health := body.get_node_or_null('HealthComponent')
		if health:
			health.take_damage(damage)
		
		_spawn_snare_text(body.global_position)

func _spawn_snare_text(pos: Vector2) -> void:
	var label := Label.new()
	label.text = 'SNARED'
	label.add_theme_font_size_override(&'font_size', 14)
	label.add_theme_color_override(&'font_color', Color(0.4, 0.3, 0.5, 1.0))
	label.position = pos + Vector2(-30, -40)
	label.z_index = 100
	get_tree().current_scene.add_child(label)
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, 'position:y', pos.y - 65, 0.8)
	tween.tween_property(label, 'modulate:a', 0.0, 0.8)
	tween.finished.connect(label.queue_free)
"""
	script.reload()
	thread.set_script(script)
	
	# Set thread endpoints
	var player := get_tree().get_first_node_in_group("player")
	if player and is_instance_valid(player):
		var offset := Vector2(randf_range(-60, 60), randf_range(-60, 60))
		thread.end_pos = player.global_position + offset
	else:
		thread.end_pos = global_position + Vector2(randf_range(-100, 100), randf_range(-100, 100))
	
	thread.damage = thread_damage
	thread.max_length = 120.0
	thread.lifetime = thread_lifetime
	
	get_tree().current_scene.add_child(thread)
	_active_threads.append(thread)
	
	_play_weave_sound()

func _play_weave_sound() -> void:
	var player := AudioStreamPlayer.new()
	get_tree().current_scene.add_child(player)
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.3
	player.stream = gen
	player.volume_db = -16.0
	player.play()
	
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback:
		var frames := int(gen.mix_rate * 0.3)
		var phase := 0.0
		for i in range(frames):
			var t := float(i) / frames
			var freq := 300.0 + (t * 200.0)
			phase += freq / gen.mix_rate
			var sample := sin(phase * TAU) * 0.2 * (1.0 - t * 0.7)
			playback.push_frame(Vector2(sample, sample))
	
	await get_tree().create_timer(0.35).timeout
	player.queue_free()

func _on_died() -> void:
	# Dissolve all threads
	for thread in _active_threads:
		if is_instance_valid(thread):
			var tween := create_tween()
			tween.tween_property(thread, "modulate:a", 0.0, 0.4)
			tween.finished.connect(thread.queue_free)
	
	_spawn_unravel_effect()
	queue_free()

func _spawn_unravel_effect() -> void:
	for i in range(8):
		var particle := ColorRect.new()
		particle.size = Vector2(3, 12)
		particle.position = global_position + Vector2(-1.5, -6)
		particle.color = Color(0.3, 0.2, 0.4, 0.8)
		particle.z_index = 50
		get_tree().current_scene.add_child(particle)
		
		var angle := (TAU / 8.0) * i
		var velocity := Vector2(cos(angle), sin(angle)) * 80.0
		
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "position", particle.position + velocity * 0.6, 0.6)
		tween.tween_property(particle, "rotation", randf_range(-PI, PI), 0.6)
		tween.tween_property(particle, "modulate:a", 0.0, 0.6)
		tween.finished.connect(particle.queue_free)