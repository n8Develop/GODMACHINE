extends CharacterBody2D

@export var stalk_speed: float = 55.0
@export var vanish_distance: float = 120.0  # Stays at this distance
@export var strike_distance: float = 40.0   # Teleports when player looks away
@export var strike_damage: int = 28
@export var strike_cooldown: float = 5.0
@export var visibility_check_interval: float = 0.2

var _health: Node = null
var _sprite: ColorRect = null
var _strike_timer: float = 0.0
var _visibility_timer: float = 0.0
var _was_visible_last_check: bool = false
var _strike_ready: bool = false

func _ready() -> void:
	add_to_group("enemies")
	
	_health = get_node_or_null("HealthComponent")
	if _health and _health.has_signal("died"):
		_health.died.connect(_on_died)
	
	# Visual: dark silhouette
	_sprite = ColorRect.new()
	_sprite.size = Vector2(28, 40)
	_sprite.position = Vector2(-14, -20)
	_sprite.color = Color(0.1, 0.1, 0.15, 0.9)
	add_child(_sprite)
	
	# Start partially transparent
	modulate.a = 0.6

func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if not player:
		return
	
	var distance := global_position.distance_to(player.global_position)
	var to_player := global_position.direction_to(player.global_position)
	
	# Update timers
	_strike_timer = max(0.0, _strike_timer - delta)
	_visibility_timer += delta
	
	# Check if player is looking at us
	if _visibility_timer >= visibility_check_interval:
		_visibility_timer = 0.0
		var player_looking := _is_player_looking_at_me(player, distance)
		
		# If player looks away AND we're strike-ready, teleport strike
		if _was_visible_last_check and not player_looking and _strike_ready:
			_perform_strike(player)
		
		_was_visible_last_check = player_looking
		
		# Visual feedback: fade when seen, solidify when hidden
		var target_alpha := 0.3 if player_looking else 0.85
		modulate.a = lerp(modulate.a, target_alpha, 0.1)
	
	# Movement: maintain distance when visible, approach when hidden
	if _was_visible_last_check:
		# Stay at vanish_distance
		if distance < vanish_distance:
			velocity = -to_player * stalk_speed
		elif distance > vanish_distance + 20.0:
			velocity = to_player * stalk_speed * 0.6
		else:
			velocity = Vector2.ZERO
	else:
		# Creep closer when player isn't looking
		if distance > strike_distance:
			velocity = to_player * (stalk_speed * 0.8)
			_strike_ready = (_strike_timer <= 0.0)
		else:
			velocity = Vector2.ZERO
	
	move_and_slide()

func _is_player_looking_at_me(player: Node2D, distance: float) -> bool:
	# Check if player's movement direction points roughly toward us
	if player.velocity.length() < 20.0:
		return false  # Player standing still = not looking
	
	var player_facing := player.velocity.normalized()
	var to_me := player.global_position.direction_to(global_position)
	var dot := player_facing.dot(to_me)
	
	# If player is moving toward us AND we're not too far
	return dot > 0.5 and distance < 250.0

func _perform_strike(player: Node2D) -> void:
	# Teleport behind player
	var behind_offset := -player.velocity.normalized() * 30.0
	if behind_offset.length() < 10.0:
		behind_offset = Vector2(0, 30)  # Default behind if player stopped
	
	global_position = player.global_position + behind_offset
	
	# Deal damage
	var player_health := player.get_node_or_null("HealthComponent")
	if player_health and player_health.has_method("take_damage"):
		player_health.take_damage(strike_damage)
		_spawn_damage_number(player.global_position, strike_damage)
	
	# Visual flash
	_flash_strike()
	
	# Audio
	_play_strike_sound()
	
	# Reset state
	_strike_timer = strike_cooldown
	_strike_ready = false
	modulate.a = 0.3  # Briefly visible after strike

func _flash_strike() -> void:
	var flash := ColorRect.new()
	flash.size = Vector2(48, 48)
	flash.position = Vector2(-24, -24)
	flash.color = Color(0.8, 0.1, 0.2, 0.6)
	flash.z_index = 10
	add_child(flash)
	
	var tween := create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.3)
	tween.finished.connect(flash.queue_free)

func _spawn_damage_number(pos: Vector2, damage: int) -> void:
	var label := Label.new()
	label.text = str(damage)
	label.add_theme_color_override(&"font_color", Color(0.9, 0.2, 0.2, 1.0))
	label.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	label.add_theme_constant_override(&"outline_size", 2)
	label.add_theme_font_size_override(&"font_size", 22)
	label.position = pos + Vector2(-12, -35)
	label.z_index = 100
	get_tree().current_scene.add_child(label)
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", pos.y - 65, 0.7)
	tween.tween_property(label, "modulate:a", 0.0, 0.7)
	tween.finished.connect(label.queue_free)

func _play_strike_sound() -> void:
	var player := AudioStreamPlayer.new()
	get_tree().current_scene.add_child(player)
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.3
	player.stream = gen
	player.volume_db = -12.0
	player.play()
	
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback:
		var frames := int(gen.mix_rate * 0.3)
		var phase := randf() * TAU
		for i in range(frames):
			var t := float(i) / frames
			var freq := 220.0 - (t * 180.0)  # Descending whisper
			phase += freq / gen.mix_rate
			var sample := sin(phase * TAU) * 0.2 * (1.0 - t)
			# Add noise for texture
			sample += (randf() - 0.5) * 0.08 * (1.0 - t)
			playback.push_frame(Vector2(sample, sample))
	
	await get_tree().create_timer(0.35).timeout
	player.queue_free()

func _on_died() -> void:
	# Dissolve into shadows
	for i in range(8):
		var particle := ColorRect.new()
		particle.size = Vector2(6, 6)
		particle.position = global_position + Vector2(randf_range(-12, 12), randf_range(-12, 12))
		particle.color = Color(0.1, 0.1, 0.15, 0.8)
		particle.z_index = 5
		get_tree().current_scene.add_child(particle)
		
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "position:y", particle.position.y - 40, 1.2)
		tween.tween_property(particle, "modulate:a", 0.0, 1.2)
		tween.finished.connect(particle.queue_free)
	
	queue_free()