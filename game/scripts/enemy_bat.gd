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

@onready var health: HealthComponent = $HealthComponent

var _state: String = "patrol"
var _swoop_timer: float = 0.0
var _swoop_target: Vector2 = Vector2.ZERO
var _phase_timer: float = 0.0
var _is_solid: bool = true
var _shoot_timer: float = 0.0

func _ready() -> void:
	add_to_group("enemies")
	if is_boss:
		add_to_group("boss")
	if health:
		health.died.connect(_on_died)
	_phase_timer = phase_interval
	_shoot_timer = randf_range(0.0, shoot_cooldown)

func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	var distance := global_position.distance_to(player.global_position)
	
	# Ghost phasing logic
	if is_ghost:
		_phase_timer -= delta
		if _phase_timer <= 0.0:
			_phase_timer = phase_interval
			_is_solid = not _is_solid
			_update_collision_state()
			_update_visual_phase()
	
	# Archer behavior overrides normal bat AI
	if is_archer:
		_archer_behavior(delta, player, distance)
		move_and_slide()
		return
	
	# Normal bat state machine
	match _state:
		"patrol":
			_patrol_movement(delta)
			if distance <= detection_range:
				_state = "chase"
		
		"chase":
			if distance > detection_range * 1.5:
				_state = "patrol"
			elif _swoop_timer <= 0.0 and distance < detection_range * 0.6:
				_state = "swoop"
				_swoop_target = player.global_position
				_swoop_timer = swoop_cooldown
			else:
				_swoop_timer -= delta
				var dir := global_position.direction_to(player.global_position)
				velocity = dir * fly_speed
		
		"swoop":
			var dir := global_position.direction_to(_swoop_target)
			velocity = dir * swoop_speed
			if global_position.distance_to(_swoop_target) < 20.0:
				_state = "chase"
	
	move_and_slide()

func _archer_behavior(delta: float, player: Node2D, distance: float) -> void:
	_shoot_timer -= delta
	
	# Keep distance (kiting behavior)
	var ideal_distance := 150.0
	var dir := global_position.direction_to(player.global_position)
	
	if distance < ideal_distance:
		# Too close, back away
		velocity = -dir * fly_speed
	elif distance > ideal_distance * 1.5:
		# Too far, move closer
		velocity = dir * fly_speed * 0.5
	else:
		# Good range, strafe
		var time := Time.get_ticks_msec() / 1000.0
		var strafe := Vector2(-dir.y, dir.x) * sin(time * 2.0)
		velocity = strafe * fly_speed * 0.6
	
	# Shoot arrow
	if _shoot_timer <= 0.0 and distance <= detection_range:
		_spawn_arrow(player.global_position)
		_shoot_timer = shoot_cooldown

func _spawn_arrow(target_pos: Vector2) -> void:
	var arrow := Area2D.new()
	arrow.collision_layer = 0
	arrow.collision_mask = 2  # Hit player
	arrow.global_position = global_position
	
	# Visual
	var sprite := ColorRect.new()
	sprite.size = Vector2(8, 2)
	sprite.color = Color(0.8, 0.7, 0.3, 1.0)
	sprite.position = Vector2(-4, -1)
	arrow.add_child(sprite)
	
	# Collision
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(8, 2)
	shape.shape = rect
	arrow.add_child(shape)
	
	# Script (inline)
	var script_code := """
extends Area2D

var velocity := Vector2.ZERO
var damage := 0
var lifetime := 3.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	global_position += velocity * delta
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
	var gd_script := GDScript.new()
	gd_script.source_code = script_code
	gd_script.reload()
	arrow.set_script(gd_script)
	
	# Set arrow properties
	var dir := global_position.direction_to(target_pos)
	arrow.velocity = dir * arrow_speed
	arrow.damage = arrow_damage
	arrow.rotation = dir.angle()
	
	get_parent().add_child(arrow)

func _patrol_movement(delta: float) -> void:
	var time := Time.get_ticks_msec() / 1000.0
	var offset_x := sin(time * 1.2) * 30.0
	var offset_y := cos(time * 0.8) * 20.0
	var target := global_position + Vector2(offset_x, offset_y)
	var dir := global_position.direction_to(target)
	velocity = dir * fly_speed * 0.3

func _update_collision_state() -> void:
	if _is_solid:
		collision_layer = 2
		collision_mask = 3
	else:
		collision_layer = 0
		collision_mask = 0

func _update_visual_phase() -> void:
	var sprite := get_node_or_null("Body")
	if sprite:
		if _is_solid:
			sprite.modulate.a = 1.0
			sprite.color = Color(0.6, 0.8, 1.0, 1.0) if is_ghost else Color(0.4, 0.2, 0.5, 1.0)
		else:
			sprite.modulate.a = 0.4
			sprite.color = Color(0.4, 0.6, 0.9, 0.4)

func _on_died() -> void:
	queue_free()