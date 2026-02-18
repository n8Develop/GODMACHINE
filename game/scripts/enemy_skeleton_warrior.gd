extends CharacterBody2D

@export var walk_speed: float = 55.0
@export var attack_range: float = 40.0
@export var attack_damage: int = 18
@export var attack_cooldown: float = 1.2
@export var shield_bash_range: float = 60.0
@export var bash_damage: int = 12
@export var bash_cooldown: float = 3.0
@export var bone_color: Color = Color(0.85, 0.85, 0.75, 1.0)

var _attack_timer: float = 0.0
var _bash_timer: float = 0.0
var _combat_stance: String = "neutral"  # neutral, aggressive, defensive

func _ready() -> void:
	add_to_group("enemies")
	var health := get_node_or_null("HealthComponent")
	if health:
		health.died.connect(_on_died)
	
	# Create weapon visual (sword)
	var sword := ColorRect.new()
	sword.size = Vector2(4, 20)
	sword.position = Vector2(12, -10)
	sword.color = Color(0.6, 0.6, 0.65, 1.0)
	sword.name = "Sword"
	add_child(sword)
	
	# Create shield visual
	var shield := ColorRect.new()
	shield.size = Vector2(14, 18)
	shield.position = Vector2(-18, -9)
	shield.color = Color(0.4, 0.35, 0.3, 1.0)
	shield.name = "Shield"
	add_child(shield)

func _physics_process(delta: float) -> void:
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if not player or not is_instance_valid(player):
		return
	
	var distance := global_position.distance_to(player.global_position)
	var direction := global_position.direction_to(player.global_position)
	
	# Update combat stance based on distance and health
	var health := get_node_or_null("HealthComponent")
	if health:
		var hp_percent := float(health.current_health) / float(health.max_health)
		if hp_percent < 0.4:
			_combat_stance = "defensive"
		elif distance < 80.0:
			_combat_stance = "aggressive"
		else:
			_combat_stance = "neutral"
	
	# Update timers
	if _attack_timer > 0.0:
		_attack_timer -= delta
	if _bash_timer > 0.0:
		_bash_timer -= delta
	
	# Behavior based on stance
	match _combat_stance:
		"aggressive":
			velocity = direction * walk_speed * 1.3
			_try_bash(player, distance)
		"defensive":
			# Circle strafe
			var perpendicular := Vector2(-direction.y, direction.x)
			velocity = perpendicular * walk_speed * 0.8
			if distance < 100.0:
				velocity -= direction * walk_speed * 0.5
		"neutral":
			if distance > attack_range:
				velocity = direction * walk_speed
			else:
				velocity = Vector2.ZERO
	
	move_and_slide()
	
	# Rotate weapon/shield based on facing
	var sword := get_node_or_null("Sword")
	var shield := get_node_or_null("Shield")
	if sword and shield:
		if direction.x < 0:
			sword.position.x = -12
			shield.position.x = 4
		else:
			sword.position.x = 12
			shield.position.x = -18
	
	# Attack when in range
	if distance <= attack_range and _attack_timer <= 0.0:
		_perform_attack(player)
		_attack_timer = attack_cooldown

func _try_bash(player: Node2D, distance: float) -> void:
	if distance <= shield_bash_range and _bash_timer <= 0.0:
		_perform_bash(player)
		_bash_timer = bash_cooldown

func _perform_attack(player: Node2D) -> void:
	var player_health := player.get_node_or_null("HealthComponent")
	if player_health:
		player_health.take_damage(attack_damage)
		_spawn_damage_number(player.global_position, attack_damage)
	
	_play_attack_sound()
	_flash_weapon()

func _perform_bash(player: Node2D) -> void:
	var player_health := player.get_node_or_null("HealthComponent")
	if player_health:
		player_health.take_damage(bash_damage)
		_spawn_damage_number(player.global_position, bash_damage)
		
		# Knockback effect
		if player is CharacterBody2D:
			var knockback_dir := global_position.direction_to(player.global_position)
			player.velocity += knockback_dir * 200.0
	
	_play_bash_sound()
	_flash_shield()

func _flash_weapon() -> void:
	var sword := get_node_or_null("Sword")
	if sword:
		var tween := create_tween()
		tween.tween_property(sword, "modulate", Color(2.0, 2.0, 2.0, 1.0), 0.1)
		tween.tween_property(sword, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.1)

func _flash_shield() -> void:
	var shield := get_node_or_null("Shield")
	if shield:
		var tween := create_tween()
		tween.tween_property(shield, "modulate", Color(1.5, 1.5, 1.0, 1.0), 0.15)
		tween.tween_property(shield, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.15)

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

func _play_attack_sound() -> void:
	var player := AudioStreamPlayer.new()
	get_tree().current_scene.add_child(player)
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.12
	player.stream = gen
	player.volume_db = -14.0
	player.play()
	
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback:
		var frames := 128
		var phase := 0.0
		for i in range(frames):
			var t := float(i) / frames
			var freq := 600.0 - (t * 400.0)
			phase += freq / gen.mix_rate
			var sample := sin(phase * TAU) * 0.2 * (1.0 - t)
			playback.push_frame(Vector2(sample, sample))
	
	await get_tree().create_timer(0.15).timeout
	player.queue_free()

func _play_bash_sound() -> void:
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
		var frames := 128
		var phase := 0.0
		for i in range(frames):
			var t := float(i) / frames
			var freq := 180.0 + (t * 80.0)
			phase += freq / gen.mix_rate
			var noise := randf() * 0.1
			var sample := (sin(phase * TAU) * 0.3 + noise) * (1.0 - t * 0.5)
			playback.push_frame(Vector2(sample, sample))
	
	await get_tree().create_timer(0.25).timeout
	player.queue_free()

func _on_died() -> void:
	# Death particles
	for i in range(12):
		var particle := ColorRect.new()
		particle.size = Vector2(6, 6)
		particle.position = global_position + Vector2(-3, -3)
		particle.color = bone_color
		particle.z_index = 50
		get_tree().current_scene.add_child(particle)
		
		var angle := (TAU / 12.0) * i
		var offset := Vector2(cos(angle), sin(angle)) * 50.0
		
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "position", global_position + offset, 0.6)
		tween.tween_property(particle, "modulate:a", 0.0, 0.6)
		tween.finished.connect(particle.queue_free)
	
	queue_free()