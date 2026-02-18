extends CharacterBody2D

@export var walk_speed: float = 35.0
@export var shield_block_arc: float = 120.0  # degrees in front
@export var turn_speed: float = 2.0
@export var shield_bash_damage: int = 20
@export var bash_cooldown: float = 3.5
@export var bash_range: float = 50.0

var _target_pos: Vector2
var _bash_timer: float = 0.0
var _facing_angle: float = 0.0
var _shield_visual: ColorRect

func _ready() -> void:
	add_to_group("enemies")
	_target_pos = global_position
	
	# Create shield visual (golden rectangle in front)
	_shield_visual = ColorRect.new()
	_shield_visual.size = Vector2(24, 32)
	_shield_visual.position = Vector2(8, -16)
	_shield_visual.color = Color(0.9, 0.7, 0.2, 1.0)
	_shield_visual.z_index = 1
	add_child(_shield_visual)
	
	# Get health component
	var health := get_node_or_null("HealthComponent")
	if health:
		health.died.connect(_on_died)

func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	_target_pos = player.global_position
	var to_player := global_position.direction_to(_target_pos)
	var distance := global_position.distance_to(_target_pos)
	
	# Rotate to face player
	var target_angle := to_player.angle()
	_facing_angle = lerp_angle(_facing_angle, target_angle, turn_speed * delta)
	rotation = _facing_angle
	
	# Move toward player slowly
	if distance > 40.0:
		velocity = Vector2.RIGHT.rotated(_facing_angle) * walk_speed
	else:
		velocity = Vector2.ZERO
	
	move_and_slide()
	
	# Shield bash attack
	_bash_timer -= delta
	if distance <= bash_range and _bash_timer <= 0.0:
		_perform_bash(player)
		_bash_timer = bash_cooldown
	
	# Update shield glow based on whether it's blocking
	_update_shield_state(to_player)

func _update_shield_state(to_player: Vector2) -> void:
	if not _shield_visual:
		return
	
	# Check if player's attack would come from the front
	var player_obj := get_tree().get_first_node_in_group("player")
	if player_obj and player_obj.has_method("get"):
		var attack_dir := to_player * -1  # direction attack would come from
		var shield_forward := Vector2.RIGHT.rotated(_facing_angle)
		var angle_diff := rad_to_deg(attack_dir.angle_to(shield_forward))
		
		# Glow if within blocking arc
		if abs(angle_diff) < shield_block_arc / 2.0:
			_shield_visual.color = Color(1.0, 0.9, 0.4, 1.0)  # bright gold
		else:
			_shield_visual.color = Color(0.9, 0.7, 0.2, 1.0)  # normal

func _perform_bash(player: Node2D) -> void:
	var health_comp := player.get_node_or_null("HealthComponent")
	if health_comp:
		health_comp.take_damage(shield_bash_damage)
		_spawn_damage_number(player.global_position, shield_bash_damage)
	
	# Flash shield bright white
	if _shield_visual:
		var original := _shield_visual.color
		_shield_visual.color = Color.WHITE
		await get_tree().create_timer(0.1).timeout
		if _shield_visual:
			_shield_visual.color = original
	
	_play_bash_sound()

func take_damage_from_direction(amount: int, attack_dir: Vector2) -> int:
	# Check if attack is blocked by shield
	var shield_forward := Vector2.RIGHT.rotated(_facing_angle)
	var angle_diff := rad_to_deg(attack_dir.angle_to(shield_forward))
	
	if abs(angle_diff) < shield_block_arc / 2.0:
		# Blocked! Flash shield and play clang sound
		if _shield_visual:
			var original := _shield_visual.color
			_shield_visual.color = Color.WHITE
			await get_tree().create_timer(0.08).timeout
			if _shield_visual:
				_shield_visual.color = original
		_play_block_sound()
		return 0  # No damage taken
	else:
		# Hit from side or back
		var health := get_node_or_null("HealthComponent")
		if health:
			health.take_damage(amount)
		return amount

func _spawn_damage_number(pos: Vector2, damage: int) -> void:
	var label := Label.new()
	label.text = str(damage)
	label.add_theme_color_override(&"font_color", Color(1.0, 0.3, 0.3, 1.0))
	label.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	label.add_theme_constant_override(&"outline_size", 2)
	label.add_theme_font_size_override(&"font_size", 18)
	label.position = pos + Vector2(-10, -30)
	label.z_index = 100
	get_parent().add_child(label)
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", pos.y - 60, 0.5)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.finished.connect(label.queue_free)

func _play_bash_sound() -> void:
	var player := AudioStreamPlayer.new()
	get_tree().current_scene.add_child(player)
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.25
	player.stream = gen
	player.volume_db = -8.0
	player.play()
	
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback:
		var frames := int(gen.mix_rate * 0.25)
		var phase := 0.0
		for i in range(frames):
			var t := float(i) / frames
			var freq := 200.0 - (t * 100.0)  # Deep thud
			phase += freq / gen.mix_rate
			var sample := sin(phase * TAU) * 0.35 * (1.0 - t * 0.8)
			playback.push_frame(Vector2(sample, sample))
	
	await get_tree().create_timer(0.3).timeout
	player.queue_free()

func _play_block_sound() -> void:
	var player := AudioStreamPlayer.new()
	get_tree().current_scene.add_child(player)
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.15
	player.stream = gen
	player.volume_db = -10.0
	player.play()
	
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback:
		var frames := int(gen.mix_rate * 0.15)
		var phase := 0.0
		for i in range(frames):
			var t := float(i) / frames
			# High metallic clang
			var freq := 1200.0 + (sin(t * TAU * 3.0) * 200.0)
			phase += freq / gen.mix_rate
			var sample := sin(phase * TAU) * 0.25 * (1.0 - t * 0.9)
			playback.push_frame(Vector2(sample, sample))
	
	await get_tree().create_timer(0.2).timeout
	player.queue_free()

func _on_died() -> void:
	# Drop shield as visual debris
	if _shield_visual:
		_shield_visual.reparent(get_parent())
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(_shield_visual, "position", _shield_visual.global_position + Vector2(0, 40), 0.8)
		tween.tween_property(_shield_visual, "rotation", randf_range(-PI, PI), 0.8)
		tween.tween_property(_shield_visual, "modulate:a", 0.0, 0.8)
		tween.finished.connect(_shield_visual.queue_free)
	
	queue_free()