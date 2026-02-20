extends CharacterBody2D

@export var patrol_speed: float = 35.0
@export var charge_speed: float = 160.0
@export var charge_range: float = 200.0
@export var charge_cooldown: float = 4.5
@export var swing_damage: int = 24
@export var swing_range: float = 50.0
@export var swing_cooldown: float = 1.8
@export var armor_color: Color = Color(0.3, 0.3, 0.35, 1.0)

var _charge_timer: float = 0.0
var _swing_timer: float = 0.0
var _is_charging: bool = false
var _charge_direction: Vector2 = Vector2.ZERO
var _patrol_direction: Vector2 = Vector2.RIGHT
var _patrol_timer: float = 0.0

func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 2
	collision_mask = 3
	
	# Create visuals - armored knight silhouette
	var body := ColorRect.new()
	body.size = Vector2(28, 36)
	body.position = Vector2(-14, -36)
	body.color = armor_color
	add_child(body)
	
	# Helmet crest
	var crest := ColorRect.new()
	crest.size = Vector2(32, 4)
	crest.position = Vector2(-16, -40)
	crest.color = Color(0.8, 0.2, 0.2, 1.0)
	add_child(crest)
	
	# Sword (held at side)
	var sword := ColorRect.new()
	sword.size = Vector2(6, 28)
	sword.position = Vector2(16, -24)
	sword.color = Color(0.6, 0.6, 0.65, 1.0)
	sword.name = "Sword"
	add_child(sword)
	
	# Collision
	var shape := RectangleShape2D.new()
	shape.size = Vector2(28, 36)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0, -18)
	add_child(collision)
	
	# Health component reference
	var health := get_node_or_null("HealthComponent")
	if health and health.has_signal("died"):
		health.died.connect(_on_died)
	
	# Ambient clank sound
	_create_clank_audio()
	
	# Random patrol direction
	_patrol_direction = Vector2(cos(randf() * TAU), sin(randf() * TAU)).normalized()

func _create_clank_audio() -> void:
	var player := AudioStreamPlayer.new()
	player.name = "ClankAudio"
	add_child(player)
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.1
	player.stream = gen
	player.volume_db = -22.0
	
	# Play clanking periodically
	var timer := Timer.new()
	timer.wait_time = randf_range(3.0, 6.0)
	timer.one_shot = false
	timer.timeout.connect(func():
		player.play()
		var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
		if playback:
			var frames := int(gen.mix_rate * 0.08)
			for i in range(frames):
				var t := float(i) / frames
				var sample := (randf() - 0.5) * 0.15 * (1.0 - t)  # Metallic noise
				playback.push_frame(Vector2(sample, sample))
		timer.wait_time = randf_range(3.0, 6.0)
	)
	add_child(timer)
	timer.start()

func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if not player:
		return
	
	var distance := global_position.distance_to(player.global_position)
	
	_charge_timer -= delta
	_swing_timer -= delta
	_patrol_timer += delta
	
	if _is_charging:
		# Continue charge until collision or timeout
		velocity = _charge_direction * charge_speed
		move_and_slide()
		
		if get_slide_collision_count() > 0:
			_is_charging = false
			_flash_impact()
			_play_clang_sound()
	else:
		# Decide behavior based on distance
		if distance <= charge_range and _charge_timer <= 0.0:
			# Begin charge
			_start_charge(player)
		elif distance <= swing_range and _swing_timer <= 0.0:
			# Melee swing
			_perform_swing(player)
		elif distance <= charge_range * 1.5:
			# Walk toward player
			var direction := global_position.direction_to(player.global_position)
			velocity = direction * patrol_speed
			move_and_slide()
		else:
			# Patrol aimlessly
			if _patrol_timer >= 3.0:
				_patrol_direction = Vector2(cos(randf() * TAU), sin(randf() * TAU)).normalized()
				_patrol_timer = 0.0
			velocity = _patrol_direction * patrol_speed * 0.5
			move_and_slide()

func _start_charge(player: Node2D) -> void:
	_is_charging = true
	_charge_timer = charge_cooldown
	_charge_direction = global_position.direction_to(player.global_position)
	
	# Visual warning
	_flash_charge_warning()
	_play_charge_sound()

func _flash_charge_warning() -> void:
	var crest := get_node_or_null("ColorRect2")
	if crest:
		var tween := create_tween()
		tween.tween_property(crest, "color", Color(1.0, 0.5, 0.1, 1.0), 0.2)
		tween.tween_property(crest, "color", Color(0.8, 0.2, 0.2, 1.0), 0.2)

func _flash_impact() -> void:
	var body := get_node_or_null("ColorRect")
	if body:
		var tween := create_tween()
		tween.tween_property(body, "modulate", Color(2.0, 2.0, 2.0, 1.0), 0.1)
		tween.tween_property(body, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.2)

func _perform_swing(player: Node2D) -> void:
	_swing_timer = swing_cooldown
	
	var sword := get_node_or_null("Sword")
	if sword:
		var tween := create_tween()
		tween.tween_property(sword, "rotation", deg_to_rad(90), 0.15)
		tween.tween_property(sword, "rotation", 0.0, 0.15)
	
	_play_swing_sound()
	
	# Check if player is in range
	if global_position.distance_to(player.global_position) <= swing_range:
		var player_health := player.get_node_or_null("HealthComponent")
		if player_health:
			player_health.take_damage(swing_damage)
			_spawn_damage_number(player.global_position, swing_damage)

func _spawn_damage_number(pos: Vector2, damage: int) -> void:
	var label := Label.new()
	label.text = str(damage)
	label.add_theme_color_override(&"font_color", Color(1.0, 0.3, 0.3, 1.0))
	label.add_theme_font_size_override(&"font_size", 20)
	label.position = pos + Vector2(-10, -30)
	label.z_index = 100
	get_tree().current_scene.add_child(label)
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", pos.y - 60, 0.6)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.finished.connect(label.queue_free)

func _play_charge_sound() -> void:
	var player := AudioStreamPlayer.new()
	get_tree().current_scene.add_child(player)
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.5
	player.stream = gen
	player.volume_db = -12.0
	player.play()
	
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback:
		var frames := int(gen.mix_rate * 0.5)
		var phase := 0.0
		for i in range(frames):
			var t := float(i) / frames
			var freq := 80.0 + (t * 120.0)  # Rising rumble
			phase += freq / gen.mix_rate
			var sample := sin(phase * TAU) * 0.25 * (1.0 - t * 0.3)
			playback.push_frame(Vector2(sample, sample))
	
	await get_tree().create_timer(0.55).timeout
	player.queue_free()

func _play_swing_sound() -> void:
	var player := AudioStreamPlayer.new()
	get_tree().current_scene.add_child(player)
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.2
	player.stream = gen
	player.volume_db = -14.0
	player.play()
	
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback:
		var frames := int(gen.mix_rate * 0.2)
		for i in range(frames):
			var t := float(i) / frames
			var sample := (randf() - 0.5) * 0.2 * (1.0 - t)  # Whoosh
			playback.push_frame(Vector2(sample, sample))
	
	await get_tree().create_timer(0.25).timeout
	player.queue_free()

func _play_clang_sound() -> void:
	var player := AudioStreamPlayer.new()
	get_tree().current_scene.add_child(player)
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.3
	player.stream = gen
	player.volume_db = -10.0
	player.play()
	
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback:
		var frames := int(gen.mix_rate * 0.3)
		var phase := 0.0
		for i in range(frames):
			var t := float(i) / frames
			var freq := 1200.0 - (t * 900.0)  # Sharp metallic ring
			phase += freq / gen.mix_rate
			var sample := sin(phase * TAU) * 0.3 * (1.0 - t)
			playback.push_frame(Vector2(sample, sample))
	
	await get_tree().create_timer(0.35).timeout
	player.queue_free()

func _on_died() -> void:
	# Death particles
	for i in range(20):
		var particle := ColorRect.new()
		particle.size = Vector2(6, 6)
		particle.position = global_position + Vector2(randf_range(-12, 12), randf_range(-18, 0))
		particle.color = armor_color
		particle.z_index = 50
		get_tree().current_scene.add_child(particle)
		
		var direction := Vector2(randf_range(-1, 1), randf_range(-1, 0)).normalized()
		var speed := randf_range(60, 120)
		
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "position", particle.position + direction * speed, randf_range(0.4, 0.8))
		tween.tween_property(particle, "modulate:a", 0.0, randf_range(0.4, 0.8))
		tween.finished.connect(particle.queue_free)
	
	queue_free()