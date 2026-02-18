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
@export var is_wraith: bool = false
@export var wraith_trail_interval: float = 0.15

@onready var health: HealthComponent = $HealthComponent

var _swoop_timer: float = 0.0
var _state: String = "patrol"
var _hover_time: float = 0.0
var _phase_timer: float = 0.0
var _is_solid: bool = true
var _shoot_timer: float = 0.0
var _charge_timer: float = 0.0
var _flash_timer: float = 0.0
var _wraith_trail_timer: float = 0.0

func _ready() -> void:
	add_to_group("enemies")
	if health:
		health.died.connect(_on_died)
	if is_ghost:
		_phase_timer = phase_interval
	if is_bomber:
		_charge_timer = 1.5

func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		_patrol_movement(delta)
		return
	
	var distance := global_position.distance_to(player.global_position)
	
	if is_wraith:
		_wraith_behavior(delta, player, distance)
		return
	
	if is_bomber:
		_bomber_behavior(delta, player, distance)
		return
	
	if is_archer:
		_archer_behavior(delta, player, distance)
		return
	
	if is_ghost:
		_phase_timer -= delta
		if _phase_timer <= 0.0:
			_phase_timer = phase_interval
			_is_solid = not _is_solid
			_update_collision_state()
			_update_visual_phase()
	
	if distance > detection_range:
		_patrol_movement(delta)
	else:
		_swoop_timer -= delta
		if _swoop_timer <= 0.0:
			_state = "swoop"
			_swoop_timer = swoop_cooldown
		
		if _state == "swoop":
			var direction := global_position.direction_to(player.global_position)
			velocity = direction * swoop_speed
		else:
			_hover_time += delta
			var hover_offset := Vector2(cos(_hover_time * 2.0), sin(_hover_time * 3.0)) * 20.0
			var target := player.global_position + hover_offset + Vector2(0, -60)
			var direction := global_position.direction_to(target)
			velocity = direction * fly_speed
	
	move_and_slide()

func _wraith_behavior(delta: float, player: Node2D, distance: float) -> void:
	# Wraiths glide smoothly toward player, phasing through walls
	collision_layer = 0
	collision_mask = 0
	
	var direction := global_position.direction_to(player.global_position)
	velocity = direction * (fly_speed * 0.7)
	
	# Leave ethereal trail
	_wraith_trail_timer -= delta
	if _wraith_trail_timer <= 0.0:
		_spawn_wraith_trail()
		_wraith_trail_timer = wraith_trail_interval
	
	# Deal damage on contact
	if distance <= 16.0:
		var player_health := player.get_node_or_null("HealthComponent") as HealthComponent
		if player_health and player_health.can_take_damage():
			player_health.take_damage(5)
			_flash_contact()
	
	position += velocity * delta

func _spawn_wraith_trail() -> void:
	var trail := ColorRect.new()
	trail.size = Vector2(14, 10)
	trail.position = global_position + Vector2(-7, -5)
	trail.color = Color(0.3, 0.2, 0.5, 0.6)
	trail.z_index = 40
	
	# Find persistent parent — the Main scene, not current room
	var main_scene := get_tree().current_scene
	if main_scene:
		main_scene.add_child(trail)
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(trail, "modulate:a", 0.0, 0.8)
	tween.tween_property(trail, "scale", Vector2(1.3, 1.3), 0.8)
	tween.finished.connect(trail.queue_free)

func _flash_contact() -> void:
	var rect := get_node_or_null("Body")
	if rect:
		rect.modulate = Color(1.5, 1.5, 1.5, 1.0)
		await get_tree().create_timer(0.1).timeout
		if rect:
			rect.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _bomber_behavior(delta: float, player: Node2D, distance: float) -> void:
	_charge_timer -= delta
	_flash_timer += delta
	
	if _charge_timer > 0.0:
		var flash_rate := max(0.1, _charge_timer * 0.5)
		if fmod(_flash_timer, flash_rate) < flash_rate * 0.5:
			modulate = Color(1.5, 1.2, 0.8, 1.0)
		else:
			modulate = Color(1.0, 1.0, 1.0, 1.0)
		
		var direction := global_position.direction_to(player.global_position)
		velocity = direction * (fly_speed * 0.5)
		move_and_slide()
	else:
		var direction := global_position.direction_to(player.global_position)
		velocity = direction * charge_speed
		move_and_slide()
		
		if distance <= explode_radius * 0.3:
			_explode()

func _explode() -> void:
	var bodies := get_tree().get_nodes_in_group("player")
	for body in bodies:
		if body is Node2D:
			var dist := global_position.distance_to(body.global_position)
			if dist <= explode_radius:
				var health_comp := body.get_node_or_null("HealthComponent") as HealthComponent
				if health_comp:
					health_comp.take_damage(explode_damage)
	
	_play_explosion_sound()
	
	for i in range(20):
		var particle := ColorRect.new()
		particle.size = Vector2(4, 4)
		particle.position = global_position + Vector2(-2, -2)
		particle.color = Color(1.0, 0.5, 0.1, 1.0)
		particle.z_index = 50
		get_tree().current_scene.add_child(particle)
		
		var angle := (TAU / 20.0) * i
		var speed := randf_range(80.0, 150.0)
		var velocity := Vector2(cos(angle), sin(angle)) * speed
		
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "position", global_position + velocity * 0.4, 0.5)
		tween.tween_property(particle, "modulate:a", 0.0, 0.5)
		tween.finished.connect(particle.queue_free)
	
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
		for i in range(frames):
			var t := float(i) / frames
			var sample := randf_range(-1.0, 1.0) * 0.4 * (1.0 - t)
			playback.push_frame(Vector2(sample, sample))
	
	await get_tree().create_timer(0.45).timeout
	player.queue_free()

func _archer_behavior(delta: float, player: Node2D, distance: float) -> void:
	_shoot_timer -= delta
	
	if distance < 120.0:
		var direction := player.global_position.direction_to(global_position)
		velocity = direction * fly_speed * 1.5
	else:
		_hover_time += delta
		var hover_offset := Vector2(cos(_hover_time * 2.0), sin(_hover_time * 3.0)) * 30.0
		var target := player.global_position + hover_offset + Vector2(0, -100)
		var direction := global_position.direction_to(target)
		velocity = direction * fly_speed
	
	move_and_slide()
	
	if _shoot_timer <= 0.0 and distance >= 80.0 and distance <= detection_range:
		_spawn_arrow(player.global_position)
		_shoot_timer = shoot_cooldown

func _spawn_arrow(target_pos: Vector2) -> void:
	var arrow := Area2D.new()
	arrow.collision_layer = 0
	arrow.collision_mask = 2
	arrow.global_position = global_position
	
	var visual := ColorRect.new()
	visual.size = Vector2(16, 4)
	visual.position = Vector2(-8, -2)
	visual.color = Color(1.0, 0.9, 0.3, 1.0)
	arrow.add_child(visual)
	
	var shape := CircleShape2D.new()
	shape.radius = 4.0
	var collision := CollisionShape2D.new()
	collision.shape = shape
	arrow.add_child(collision)
	
	var script := GDScript.new()
	script.source_code = """
extends Area2D

var velocity := Vector2.ZERO
var damage := 8
var lifetime := 2.0

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
	_hover_time += delta
	velocity.x = sin(_hover_time * 1.5) * fly_speed * 0.5
	velocity.y = cos(_hover_time * 2.0) * fly_speed * 0.3
	move_and_slide()

func _update_collision_state() -> void:
	collision_layer = 2 if _is_solid else 0
	collision_mask = 3 if _is_solid else 0

func _update_visual_phase() -> void:
	var rect := get_node_or_null("ColorRect")
	if rect:
		rect.modulate.a = 1.0 if _is_solid else 0.3

func _on_died() -> void:
	# Spawn death particles
	var particle_count := 8 if not is_boss else 16
	var particle_color := Color(0.6, 0.2, 0.8, 1.0)
	
	if is_wraith:
		particle_color = Color(0.3, 0.2, 0.5, 1.0)
		particle_count = 10
	
	for i in range(particle_count):
		var particle := ColorRect.new()
		particle.size = Vector2(6, 6)
		particle.position = global_position + Vector2(-3, -3)
		particle.color = particle_color
		particle.z_index = 50
		get_tree().current_scene.add_child(particle)
		
		var angle := (TAU / particle_count) * i
		var speed := randf_range(60.0, 100.0)
		var velocity := Vector2(cos(angle), sin(angle)) * speed
		
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "position", global_position + velocity * 0.3, 0.6)
		tween.tween_property(particle, "modulate:a", 0.0, 0.6)
		tween.finished.connect(particle.queue_free)
	
	queue_free()