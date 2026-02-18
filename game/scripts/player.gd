extends CharacterBody2D

@export var speed: float = 200.0
@export var attack_damage: int = 10
@export var attack_range: float = 40.0
@export var attack_cooldown: float = 0.5
@export var fireball_cost: int = 20
@export var fireball_damage: int = 15
@export var fireball_speed: float = 300.0
@export var teleport_cooldown: float = 3.0

@onready var health: HealthComponent = $HealthComponent
@onready var mana: ManaComponent = $ManaComponent
@onready var attack_indicator: ColorRect = $AttackIndicator
@onready var cooldown_bar: ColorRect = $CooldownBar

var _attack_timer: float = 0.0
var _has_weapon: bool = false
var _indicator_timer: float = 0.0
var _teleport_timer: float = 0.0

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
	
	# Timers
	if _attack_timer > 0.0:
		_attack_timer -= delta
		if cooldown_bar and _has_weapon:
			cooldown_bar.show()
			var progress := 1.0 - (_attack_timer / attack_cooldown)
			cooldown_bar.size.x = 32.0 * progress
	else:
		if cooldown_bar:
			cooldown_bar.hide()
	
	if _teleport_timer > 0.0:
		_teleport_timer -= delta
	
	# Melee attack
	if _has_weapon and Input.is_action_just_pressed(&"attack") and _attack_timer <= 0.0:
		_perform_attack()
		_attack_timer = attack_cooldown
	
	# Magic attack
	if Input.is_action_just_pressed(&"cast_spell") and _attack_timer <= 0.0:
		if mana and mana.spend(fireball_cost):
			_cast_fireball()
			_attack_timer = attack_cooldown
	
	# Teleport (right-click)
	if Input.is_action_just_pressed(&"ui_select") and get_meta("has_teleport", false):
		if _teleport_timer <= 0.0:
			_perform_teleport()
			_teleport_timer = teleport_cooldown
	
	if _indicator_timer > 0.0:
		_indicator_timer -= delta
		if _indicator_timer <= 0.0 and attack_indicator:
			attack_indicator.hide()

func _perform_teleport() -> void:
	var mouse_pos := get_global_mouse_position()
	var teleport_distance: float = get_meta("teleport_distance", 150.0)
	var direction := global_position.direction_to(mouse_pos)
	var target_pos := global_position + (direction * teleport_distance)
	
	# Visual effect at start position
	_spawn_teleport_particles(global_position, false)
	
	# Play sound
	_play_teleport_sound()
	
	# Actually teleport
	global_position = target_pos
	
	# Visual effect at end position
	_spawn_teleport_particles(global_position, true)

func _spawn_teleport_particles(pos: Vector2, is_arrival: bool) -> void:
	for i in range(12):
		var particle := ColorRect.new()
		particle.size = Vector2(4, 4)
		particle.position = pos + Vector2(-2, -2)
		particle.color = Color(0.4, 0.7, 1.0, 1.0) if not is_arrival else Color(0.8, 0.9, 1.0, 1.0)
		particle.z_index = 50
		get_tree().current_scene.add_child(particle)
		
		var angle := (TAU / 12.0) * i
		var offset := Vector2(cos(angle), sin(angle)) * (40.0 if not is_arrival else 0.0)
		var target_offset := Vector2(cos(angle), sin(angle)) * (0.0 if not is_arrival else 40.0)
		
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "position", pos + target_offset, 0.4)
		tween.tween_property(particle, "modulate:a", 0.0, 0.4)
		tween.finished.connect(particle.queue_free)

func _play_teleport_sound() -> void:
	var player := AudioStreamPlayer.new()
	get_tree().current_scene.add_child(player)
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.4
	player.stream = gen
	player.volume_db = -10.0
	player.play()
	
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback:
		var frames := int(gen.mix_rate * 0.4)
		var phase := 0.0
		for i in range(frames):
			var t := float(i) / frames
			var freq := 800.0 - (t * 400.0)  # Descending whoosh
			phase += freq / gen.mix_rate
			var sample := sin(phase * TAU) * 0.3 * (1.0 - t * 0.5)
			playback.push_frame(Vector2(sample, sample))
	
	await get_tree().create_timer(0.45).timeout
	player.queue_free()

func _perform_attack() -> void:
	if attack_indicator:
		attack_indicator.show()
		_indicator_timer = 0.15
	
	_play_attack_sound()
	
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

func _cast_fireball() -> void:
	var mouse_pos := get_global_mouse_position()
	var direction := global_position.direction_to(mouse_pos)
	
	var fireball := Area2D.new()
	fireball.collision_layer = 0
	fireball.collision_mask = 2
	fireball.global_position = global_position
	
	var visual := ColorRect.new()
	visual.size = Vector2(12, 12)
	visual.position = Vector2(-6, -6)
	visual.color = Color(1.0, 0.4, 0.1, 1.0)
	fireball.add_child(visual)
	
	var shape := CircleShape2D.new()
	shape.radius = 6.0
	var collision := CollisionShape2D.new()
	collision.shape = shape
	fireball.add_child(collision)
	
	var script := GDScript.new()
	script.source_code = """
extends Area2D

var velocity := Vector2.ZERO
var damage := 15
var lifetime := 3.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	position += velocity * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group('enemies'):
		var health := body.get_node_or_null('HealthComponent')
		if health:
			health.take_damage(damage)
		queue_free()
"""
	script.reload()
	fireball.set_script(script)
	fireball.velocity = direction * fireball_speed
	fireball.damage = fireball_damage
	
	get_parent().add_child(fireball)
	_play_cast_sound()
	
	if attack_indicator:
		attack_indicator.modulate = Color(0.2, 0.4, 1.0, 0.5)
		attack_indicator.show()
		_indicator_timer = 0.15

func _play_cast_sound() -> void:
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
			var freq := 600.0 + (t * 400.0)
			phase += freq / gen.mix_rate
			var sample := sin(phase * TAU) * 0.3 * (1.0 - t)
			playback.push_frame(Vector2(sample, sample))
	
	await get_tree().create_timer(0.25).timeout
	player.queue_free()

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
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", pos.y - 60, 0.6)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.finished.connect(label.queue_free)

func _play_attack_sound() -> void:
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
			var freq := 800.0 - (t * 600.0)
			phase += freq / gen.mix_rate
			var sample := sin(phase * TAU)
			sample *= 0.25 * (1.0 - t)
			playback.push_frame(Vector2(sample, sample))
	
	await get_tree().create_timer(0.2).timeout
	player.queue_free()

func equip_weapon() -> void:
	_has_weapon = true
	print("GODMACHINE: Weapon equipped — violence subroutine ACTIVE")

func _on_death() -> void:
	queue_free()