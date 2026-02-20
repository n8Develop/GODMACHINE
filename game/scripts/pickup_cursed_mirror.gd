extends Area2D
class_name PickupCursedMirror

@export var reflection_duration: float = 8.0
@export var reflection_damage_multiplier: float = 0.5  # Reflection takes half player damage

func _ready() -> void:
	add_to_group("pickups")
	body_entered.connect(_on_body_entered)
	_create_visuals()

func _create_visuals() -> void:
	# Dark mirror frame
	var frame := ColorRect.new()
	frame.size = Vector2(28, 36)
	frame.position = Vector2(-14, -18)
	frame.color = Color(0.15, 0.12, 0.18, 1.0)
	add_child(frame)
	
	# Reflective surface with shimmer
	var surface := ColorRect.new()
	surface.size = Vector2(20, 28)
	surface.position = Vector2(-10, -14)
	surface.color = Color(0.6, 0.55, 0.7, 0.9)
	add_child(surface)
	
	# Collision
	var shape := RectangleShape2D.new()
	shape.size = Vector2(28, 36)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)

func _physics_process(_delta: float) -> void:
	# Shimmer effect
	var shimmer := sin(Time.get_ticks_msec() * 0.004) * 0.1
	modulate = Color(1.0, 1.0, 1.0, 0.9 + shimmer)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	
	_spawn_reflection(body)
	_spawn_pickup_text()
	_play_pickup_sound()
	queue_free()

func _spawn_reflection(player: Node2D) -> void:
	var reflection := CharacterBody2D.new()
	reflection.name = "PlayerReflection"
	reflection.global_position = player.global_position
	reflection.collision_layer = 2  # Same as player
	reflection.collision_mask = 1
	
	# Visual mimic of player
	var sprite := ColorRect.new()
	sprite.size = Vector2(32, 32)
	sprite.position = Vector2(-16, -16)
	sprite.color = Color(0.4, 0.8, 0.6, 0.7)  # Ghostly tint
	reflection.add_child(sprite)
	
	# Collision
	var shape := RectangleShape2D.new()
	shape.size = Vector2(32, 32)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	reflection.add_child(collision)
	
	# Health component
	var HealthComponentScript := load("res://scripts/health_component.gd")
	var health := HealthComponentScript.new()
	health.max_health = 50
	health.current_health = 50
	health.name = "HealthComponent"
	reflection.add_child(health)
	
	# Reflection AI script
	var script := GDScript.new()
	script.source_code = """
extends CharacterBody2D

@export var follow_distance: float = 60.0
@export var move_speed: float = 180.0
@export var attack_range: float = 40.0
@export var attack_damage: int = 8
@export var attack_cooldown: float = 0.8
@export var lifetime: float = 8.0
@export var damage_multiplier: float = 0.5

var _player: Node2D = null
var _attack_timer: float = 0.0
var _lifetime_remaining: float = 0.0

func _ready() -> void:
	add_to_group('reflection')
	_player = get_tree().get_first_node_in_group('player')
	_lifetime_remaining = lifetime
	
	var health := get_node_or_null('HealthComponent')
	if health:
		health.died.connect(_on_died)
		health.damaged.connect(_on_damaged)

func _physics_process(delta: float) -> void:
	_lifetime_remaining -= delta
	if _lifetime_remaining <= 0.0:
		_fade_away()
		return
	
	if not is_instance_valid(_player):
		_fade_away()
		return
	
	var distance := global_position.distance_to(_player.global_position)
	
	# Follow player but maintain distance
	if distance > follow_distance:
		var direction := global_position.direction_to(_player.global_position)
		velocity = direction * move_speed
		move_and_slide()
	else:
		velocity = Vector2.ZERO
	
	# Attack nearby enemies
	_attack_timer -= delta
	if _attack_timer <= 0.0:
		_try_attack_enemies()
		_attack_timer = attack_cooldown
	
	# Fade warning as lifetime expires
	if _lifetime_remaining < 2.0:
		modulate.a = _lifetime_remaining / 2.0

func _try_attack_enemies() -> void:
	var enemies := get_tree().get_nodes_in_group('enemies')
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy is Node2D:
			var distance := global_position.distance_to(enemy.global_position)
			if distance <= attack_range:
				var enemy_health := enemy.get_node_or_null('HealthComponent')
				if enemy_health:
					enemy_health.take_damage(attack_damage)
					_flash_attack()
					_play_attack_sound()
					break

func _flash_attack() -> void:
	modulate = Color(1.5, 1.5, 1.5, modulate.a)
	var tween := create_tween()
	tween.tween_property(self, 'modulate', Color(1.0, 1.0, 1.0, modulate.a), 0.15)

func _play_attack_sound() -> void:
	var player := AudioStreamPlayer.new()
	get_tree().current_scene.add_child(player)
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.1
	player.stream = gen
	player.volume_db = -16.0
	player.play()
	
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback:
		var frames := int(gen.mix_rate * 0.1)
		var phase := 0.0
		for i in range(frames):
			var t := float(i) / frames
			var freq := 600.0 - (t * 300.0)
			phase += freq / gen.mix_rate
			var sample := sin(phase * TAU) * 0.2 * (1.0 - t)
			playback.push_frame(Vector2(sample, sample))
	
	await get_tree().create_timer(0.15).timeout
	player.queue_free()

func _on_damaged(amount: int) -> void:
	# Reflection takes reduced damage
	var health := get_node_or_null('HealthComponent')
	if health:
		var actual_damage := int(amount * damage_multiplier)
		# Damage already applied, adjust current_health
		health.current_health = min(health.current_health + amount - actual_damage, health.max_health)

func _on_died() -> void:
	_spawn_shatter_effect()
	queue_free()

func _fade_away() -> void:
	var tween := create_tween()
	tween.tween_property(self, 'modulate:a', 0.0, 0.5)
	tween.finished.connect(queue_free)

func _spawn_shatter_effect() -> void:
	for i in range(8):
		var shard := ColorRect.new()
		shard.size = Vector2(6, 6)
		shard.position = global_position + Vector2(-3, -3)
		shard.color = Color(0.6, 0.55, 0.7, 0.8)
		shard.z_index = 50
		get_tree().current_scene.add_child(shard)
		
		var angle := (TAU / 8.0) * i
		var offset := Vector2(cos(angle), sin(angle)) * 40.0
		
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(shard, 'position', global_position + offset, 0.6)
		tween.tween_property(shard, 'modulate:a', 0.0, 0.6)
		tween.finished.connect(shard.queue_free)
"""
	script.reload()
	reflection.set_script(script)
	reflection.lifetime = reflection_duration
	reflection.damage_multiplier = reflection_damage_multiplier
	
	get_tree().current_scene.add_child(reflection)

func _spawn_pickup_text() -> void:
	var label := Label.new()
	label.text = "YOUR REFLECTION FIGHTS"
	label.add_theme_color_override(&"font_color", Color(0.6, 0.8, 1.0, 1.0))
	label.add_theme_font_size_override(&"font_size", 16)
	label.position = global_position + Vector2(-80, -40)
	label.z_index = 100
	get_tree().current_scene.add_child(label)
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", global_position.y - 70, 1.5)
	tween.tween_property(label, "modulate:a", 0.0, 1.5)
	tween.finished.connect(label.queue_free)

func _play_pickup_sound() -> void:
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
		var phase := 0.0
		for i in range(frames):
			var t := float(i) / frames
			var freq := 400.0 + (sin(t * TAU * 2.0) * 200.0)
			phase += freq / gen.mix_rate
			var sample := sin(phase * TAU) * 0.25 * (1.0 - t * 0.7)
			playback.push_frame(Vector2(sample, sample))
	
	await get_tree().create_timer(0.35).timeout
	player.queue_free()