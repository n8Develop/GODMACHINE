extends CharacterBody2D

@export var fly_speed: float = 60.0
@export var swoop_speed: float = 140.0
@export var detection_range: float = 180.0
@export var swoop_cooldown: float = 2.5
@export var swoop_duration: float = 0.6
@export var is_ghost: bool = false
@export var phase_interval: float = 3.0
@export var is_boss: bool = false
@export var is_archer: bool = false
@export var shoot_cooldown: float = 2.0
@export var arrow_speed: float = 200.0
@export var arrow_damage: int = 8
@export var is_bomber: bool = false
@export var explode_radius: float = 60.0
@export var explode_damage: int = 20
@export var charge_speed: float = 200.0

@onready var health: HealthComponent = $HealthComponent

var _hover_offset: float = 0.0
var _swoop_timer: float = 0.0
var _swoop_target: Vector2 = Vector2.ZERO
var _is_swooping: bool = false
var _phase_timer: float = 0.0
var _is_solid: bool = true
var _shoot_timer: float = 0.0
var _is_charging: bool = false
var _flash_timer: float = 0.0

func _ready() -> void:
	add_to_group("enemies")
	if health:
		health.died.connect(_on_died)
	
	if is_ghost:
		_phase_timer = phase_interval
		collision_layer = 0
		collision_mask = 0
		_is_solid = false
		_update_visual_phase()

func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if not player:
		return
	
	var distance := global_position.distance_to(player.global_position)
	
	# Bomber behavior - charge and explode
	if is_bomber:
		_bomber_behavior(delta, player, distance)
		return
	
	# Archer behavior - kite and shoot
	if is_archer:
		_archer_behavior(delta, player, distance)
		return
	
	# Ghost phase cycle
	if is_ghost:
		_phase_timer -= delta
		if _phase_timer <= 0.0:
			_is_solid = not _is_solid
			_phase_timer = phase_interval
			_update_collision_state()
			_update_visual_phase()
	
	# Standard bat behavior
	if distance < detection_range:
		_swoop_timer -= delta
		
		if _is_swooping:
			var dir := global_position.direction_to(_swoop_target)
			velocity = dir * swoop_speed
			move_and_slide()
			
			if global_position.distance_to(_swoop_target) < 20.0:
				_is_swooping = false
		else:
			if _swoop_timer <= 0.0:
				_swoop_target = player.global_position
				_is_swooping = true
				_swoop_timer = swoop_cooldown
			else:
				_patrol_movement(delta)
	else:
		_patrol_movement(delta)

func _bomber_behavior(delta: float, player: Node2D, distance: float) -> void:
	# Flash faster as it gets closer to player
	_flash_timer += delta * 8.0
	var flash_intensity := abs(sin(_flash_timer))
	var sprite := get_node_or_null("ColorRect") as ColorRect
	if sprite:
		sprite.color = Color(1.0, flash_intensity * 0.3, 0.0, 1.0)
	
	# Start charging when in range
	if distance < detection_range and not _is_charging:
		_is_charging = true
	
	if _is_charging:
		# Charge directly at player
		var dir := global_position.direction_to(player.global_position)
		velocity = dir * charge_speed
		move_and_slide()
		
		# Explode on close proximity
		if distance < explode_radius:
			_explode()
	else:
		_patrol_movement(delta)

func _explode() -> void:
	# Damage all nearby entities
	var nearby := get_tree().get_nodes_in_group("player")
	for target in nearby:
		if target is Node2D:
			var dist := global_position.distance_to(target.global_position)
			if dist <= explode_radius:
				var target_health := target.get_node_or_null("HealthComponent") as HealthComponent
				if target_health:
					target_health.take_damage(explode_damage)
	
	# Visual explosion effect
	var explosion := ColorRect.new()
	explosion.size = Vector2(explode_radius * 2, explode_radius * 2)
	explosion.position = global_position - Vector2(explode_radius, explode_radius)
	explosion.color = Color(1.0, 0.5, 0.0, 0.6)
	explosion.z_index = 50
	get_parent().add_child(explosion)
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(explosion, "scale", Vector2(1.5, 1.5), 0.3)
	tween.tween_property(explosion, "modulate:a", 0.0, 0.3)
	tween.finished.connect(explosion.queue_free)
	
	# Explosion sound
	_play_explosion_sound()
	
	# Self-destruct
	queue_free()

func _play_explosion_sound() -> void:
	var player := AudioStreamPlayer.new()
	get_tree().current_scene.add_child(player)
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.4
	player.stream = gen
	player.volume_db = -8.0
	player.play()
	
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback:
		var frames := int(gen.mix_rate * 0.4)
		var phase := 0.0
		for i in range(frames):
			var t := float(i) / frames
			var freq := 120.0 - (t * 100.0)
			phase += freq / gen.mix_rate
			var sample := sin(phase * TAU) * 0.4 * (1.0 - t)
			playback.push_frame(Vector2(sample, sample))
	
	await get_tree().create_timer(0.5).timeout
	player.queue_free()

func _archer_behavior(delta: float, player: Node2D, distance: float) -> void:
	_shoot_timer -= delta
	
	if distance < detection_range:
		if distance < 100.0:
			var flee_dir := global_position.direction_to(player.global_position) * -1
			velocity = flee_dir * fly_speed * 1.5
			move_and_slide()
		else:
			_patrol_movement(delta)
		
		if _shoot_timer <= 0.0:
			_spawn_arrow(player.global_position)
			_shoot_timer = shoot_cooldown
	else:
		_patrol_movement(delta)

func _spawn_arrow(target_pos: Vector2) -> void:
	var arrow := Area2D.new()
	arrow.collision_layer = 0
	arrow.collision_mask = 2
	arrow.global_position = global_position
	
	var visual := ColorRect.new()
	visual.size = Vector2(8, 3)
	visual.position = Vector2(-4, -1.5)
	visual.color = Color(1.0, 0.8, 0.2, 1.0)
	arrow.add_child(visual)
	
	var shape := RectangleShape2D.new()
	shape.size = Vector2(8, 3)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	arrow.add_child(collision)
	
	var script := GDScript.new()
	script.source_code = """
extends Area2D

var velocity := Vector2.ZERO
var damage := 8
var lifetime := 3.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	position += velocity * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group('player'):
		var health := body.get_node_or_null('HealthComponent')
		if health:
			health.take_damage(damage)
		queue_free()
"""
	script.reload()
	arrow.set_script(script)
	
	var direction := global_position.direction_to(target_pos)
	arrow.velocity = direction * arrow_speed
	arrow.damage = arrow_damage
	
	get_parent().add_child(arrow)

func _patrol_movement(delta: float) -> void:
	_hover_offset += delta * 2.0
	var hover_y := sin(_hover_offset) * 30.0
	var target_y := global_position.y + hover_y * delta
	velocity.y = (target_y - global_position.y) * 2.0
	velocity.x = cos(_hover_offset * 0.5) * fly_speed * 0.5
	move_and_slide()

func _update_collision_state() -> void:
	if _is_solid:
		collision_layer = 2
		collision_mask = 1
	else:
		collision_layer = 0
		collision_mask = 0

func _update_visual_phase() -> void:
	var sprite := get_node_or_null("ColorRect") as ColorRect
	if sprite:
		if _is_solid:
			sprite.modulate.a = 1.0
			sprite.color = Color(0.9, 0.2, 0.2, 1.0)
		else:
			sprite.modulate.a = 0.4
			sprite.color = Color(0.6, 0.7, 1.0, 1.0)

func _on_died() -> void:
	queue_free()