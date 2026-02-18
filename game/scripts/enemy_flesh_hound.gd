extends CharacterBody2D

@export var hunt_speed: float = 90.0
@export var lunge_speed: float = 220.0
@export var lunge_cooldown: float = 4.0
@export var lunge_range: float = 150.0
@export var bite_damage: int = 22
@export var bite_range: float = 35.0
@export var blood_scent_range: float = 250.0  # Tracks wounded prey

var _lunge_timer: float = 0.0
var _is_lunging: bool = false
var _lunge_direction: Vector2 = Vector2.ZERO
var _lunge_duration: float = 0.4
var _lunge_elapsed: float = 0.0
var _growl_timer: float = 0.0

@onready var _sprite := $ColorRect
@onready var _health := $HealthComponent

func _ready() -> void:
	add_to_group("enemies")
	if _health:
		_health.died.connect(_on_died)
	_create_growl_audio()

func _create_growl_audio() -> void:
	var player := AudioStreamPlayer.new()
	player.name = "GrowlAudio"
	add_child(player)
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.1
	player.stream = gen
	player.volume_db = -22.0

func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	var distance := global_position.distance_to(player.global_position)
	var to_player := global_position.direction_to(player.global_position)
	
	# Update lunge timer
	if _lunge_timer > 0.0:
		_lunge_timer -= delta
	
	# Growl when close
	_growl_timer += delta
	if distance < 120.0 and _growl_timer >= 2.0:
		_play_growl()
		_growl_timer = 0.0
	
	# Check if player is wounded (blood scent mechanic)
	var player_health := player.get_node_or_null("HealthComponent")
	var is_wounded := false
	if player_health:
		var hp_percent := float(player_health.current_health) / float(player_health.max_health)
		is_wounded = hp_percent < 0.7
	
	# Enhanced detection for wounded prey
	var effective_range := blood_scent_range if is_wounded else 180.0
	
	if _is_lunging:
		# Continue lunge
		_lunge_elapsed += delta
		velocity = _lunge_direction * lunge_speed
		
		if _lunge_elapsed >= _lunge_duration:
			_is_lunging = false
			_lunge_elapsed = 0.0
		
		# Check bite contact during lunge
		if distance < bite_range:
			_perform_bite(player)
	
	elif distance < effective_range:
		# Normal hunting behavior
		if distance > bite_range:
			# Try to lunge if in range and off cooldown
			if distance <= lunge_range and _lunge_timer <= 0.0:
				_start_lunge(to_player)
			else:
				# Normal chase
				var speed := hunt_speed * (1.2 if is_wounded else 1.0)  # Faster when tracking blood
				velocity = to_player * speed
		else:
			# In bite range - stop and attack
			velocity = Vector2.ZERO
			_perform_bite(player)
	else:
		velocity = Vector2.ZERO
	
	move_and_slide()
	
	# Visual feedback - flash red when wounded player is in range
	if is_wounded and distance < blood_scent_range:
		_sprite.modulate = Color(1.2, 0.8, 0.8, 1.0)
	else:
		_sprite.modulate = Color.WHITE

func _start_lunge(direction: Vector2) -> void:
	_is_lunging = true
	_lunge_direction = direction
	_lunge_timer = lunge_cooldown
	_lunge_elapsed = 0.0
	_play_lunge_sound()
	_flash_lunge_warning()

func _flash_lunge_warning() -> void:
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", Color(1.5, 0.5, 0.5, 1.0), 0.1)
	tween.tween_property(_sprite, "modulate", Color.WHITE, 0.1)

func _perform_bite(player: Node2D) -> void:
	var player_health := player.get_node_or_null("HealthComponent")
	if player_health:
		player_health.take_damage(bite_damage)
		_spawn_damage_number(player.global_position, bite_damage)
		_play_bite_sound()
		_flash_contact()

func _flash_contact() -> void:
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", Color(2.0, 1.0, 1.0, 1.0), 0.08)
	tween.tween_property(_sprite, "modulate", Color.WHITE, 0.08)

func _spawn_damage_number(pos: Vector2, damage: int) -> void:
	var label := Label.new()
	label.text = str(damage)
	label.add_theme_color_override(&"font_color", Color(1.0, 0.3, 0.3, 1.0))
	label.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	label.add_theme_constant_override(&"outline_size", 2)
	label.add_theme_font_size_override(&"font_size", 18)
	label.position = pos + Vector2(-10, -30)
	label.z_index = 100
	get_tree().current_scene.add_child(label)
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", pos.y - 50, 0.5)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.finished.connect(label.queue_free)

func _play_growl() -> void:
	var player := get_node_or_null("GrowlAudio") as AudioStreamPlayer
	if not player or not player.stream:
		return
	
	player.play()
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if not playback:
		return
	
	var gen := player.stream as AudioStreamGenerator
	var frames := 128
	var phase := randf() * TAU
	
	for i in range(frames):
		var t := float(i) / frames
		# Low rumbling growl (80-200Hz with noise)
		var freq := 80.0 + sin(t * TAU * 3.0) * 60.0
		phase += freq / gen.mix_rate
		var sample := sin(phase * TAU) * 0.4
		# Add noise texture
		sample += (randf() * 2.0 - 1.0) * 0.15
		sample *= (1.0 - t * 0.5)
		playback.push_frame(Vector2(sample, sample))

func _play_lunge_sound() -> void:
	var player := AudioStreamPlayer.new()
	get_tree().current_scene.add_child(player)
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.3
	player.stream = gen
	player.volume_db = -14.0
	player.play()
	
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback:
		var frames := int(gen.mix_rate * 0.3)
		var phase := 0.0
		for i in range(frames):
			var t := float(i) / frames
			var freq := 300.0 - (t * 180.0)  # Descending snarl
			phase += freq / gen.mix_rate
			var sample := sin(phase * TAU) * 0.5 * (1.0 - t)
			playback.push_frame(Vector2(sample, sample))
	
	await get_tree().create_timer(0.35).timeout
	player.queue_free()

func _play_bite_sound() -> void:
	var player := AudioStreamPlayer.new()
	get_tree().current_scene.add_child(player)
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.2
	player.stream = gen
	player.volume_db = -12.0
	player.play()
	
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback:
		var frames := int(gen.mix_rate * 0.2)
		var phase := 0.0
		for i in range(frames):
			var t := float(i) / frames
			var freq := 400.0 + sin(t * TAU * 8.0) * 200.0  # Sharp snap
			phase += freq / gen.mix_rate
			var sample := sin(phase * TAU) * 0.4 * (1.0 - t)
			playback.push_frame(Vector2(sample, sample))
	
	await get_tree().create_timer(0.25).timeout
	player.queue_free()

func _on_died() -> void:
	# Spawn blood puddle
	for i in range(8):
		var blood := ColorRect.new()
		blood.size = Vector2(6, 6)
		blood.position = global_position + Vector2(randf() * 20.0 - 10.0, randf() * 20.0 - 10.0)
		blood.color = Color(0.4, 0.05, 0.05, 0.6)
		blood.z_index = -4
		get_tree().current_scene.add_child(blood)
	
	queue_free()