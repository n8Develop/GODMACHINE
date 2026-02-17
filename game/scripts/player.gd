extends CharacterBody2D

@export var speed: float = 200.0
@export var attack_damage: int = 10
@export var attack_range: float = 40.0
@export var attack_cooldown: float = 0.5

@onready var health: HealthComponent = $HealthComponent
@onready var attack_indicator: ColorRect = $AttackIndicator
@onready var cooldown_bar: ColorRect = $CooldownBar

var _attack_timer: float = 0.0
var _has_weapon: bool = false
var _indicator_timer: float = 0.0

func _ready() -> void:
	add_to_group("player")
	if health:
		health.died.connect(_on_death)
	if attack_indicator:
		attack_indicator.hide()
	if cooldown_bar:
		cooldown_bar.hide()

func _physics_process(delta: float) -> void:
	var input_dir := Vector2.ZERO
	input_dir.x = Input.get_axis(&"move_left", &"move_right")
	input_dir.y = Input.get_axis(&"move_up", &"move_down")

	if input_dir.length() > 1.0:
		input_dir = input_dir.normalized()

	velocity = input_dir * speed
	move_and_slide()
	
	# Attack handling
	if _attack_timer > 0.0:
		_attack_timer -= delta
		# Update cooldown bar
		if cooldown_bar and _has_weapon:
			cooldown_bar.show()
			var progress := 1.0 - (_attack_timer / attack_cooldown)
			cooldown_bar.size.x = 32.0 * progress
	else:
		if cooldown_bar:
			cooldown_bar.hide()
	
	if _has_weapon and Input.is_action_just_pressed(&"attack") and _attack_timer <= 0.0:
		_perform_attack()
		_attack_timer = attack_cooldown
	
	# Visual feedback timer
	if _indicator_timer > 0.0:
		_indicator_timer -= delta
		if _indicator_timer <= 0.0 and attack_indicator:
			attack_indicator.hide()

func _perform_attack() -> void:
	# Show attack indicator
	if attack_indicator:
		attack_indicator.show()
		_indicator_timer = 0.15
	
	# Play attack sound
	_play_attack_sound()
	
	# Find enemies in range
	var enemies := get_tree().get_nodes_in_group("enemies")
	var hit_count := 0
	for enemy in enemies:
		if enemy is Node2D:
			var distance := global_position.distance_to(enemy.global_position)
			if distance <= attack_range:
				var enemy_health := enemy.get_node_or_null("HealthComponent") as HealthComponent
				if enemy_health:
					enemy_health.take_damage(attack_damage)
					_spawn_damage_number(enemy.global_position, attack_damage)
					hit_count += 1
	
	if hit_count > 0:
		print("GODMACHINE: Strike landed — ", hit_count, " targets eliminated")

func _spawn_damage_number(pos: Vector2, damage: int) -> void:
	var label := Label.new()
	label.text = str(damage)
	label.add_theme_color_override(&"font_color", Color(1.0, 0.3, 0.3, 1.0))
	label.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	label.add_theme_constant_override(&"outline_size", 2)
	label.add_theme_font_size_override(&"font_size", 20)
	label.position = pos + Vector2(-10, -30)
	label.z_index = 100
	get_parent().add_child(label)
	
	# Animate upward fade
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", pos.y - 60, 0.6)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.finished.connect(label.queue_free)

func _play_attack_sound() -> void:
	# Create simple procedural swing sound
	var player := AudioStreamPlayer.new()
	get_tree().current_scene.add_child(player)
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.15
	player.stream = gen
	player.volume_db = -10.0
	
	player.play()
	
	# Generate descending swoosh
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback:
		var frames := int(gen.mix_rate * 0.15)
		var phase := 0.0
		for i in range(frames):
			var t := float(i) / frames
			var freq := 800.0 - (t * 600.0)  # Descending pitch
			phase += freq / gen.mix_rate
			var sample := sin(phase * TAU)
			sample *= 0.25 * (1.0 - t)  # Fade out
			playback.push_frame(Vector2(sample, sample))
	
	# Auto-cleanup
	await get_tree().create_timer(0.2).timeout
	player.queue_free()

func equip_weapon() -> void:
	_has_weapon = true
	print("GODMACHINE: Weapon equipped — violence subroutine ACTIVE")

func _on_death() -> void:
	queue_free()