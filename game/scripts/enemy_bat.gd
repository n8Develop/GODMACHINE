extends CharacterBody2D

@export var fly_speed: float = 60.0
@export var swoop_speed: float = 140.0
@export var detection_range: float = 180.0
@export var swoop_cooldown: float = 2.5
@export var swoop_duration: float = 0.6
@export var is_ghost: bool = false
@export var phase_interval: float = 3.0
@export var is_boss: bool = false

@onready var health: HealthComponent = $HealthComponent

var _state: String = "patrol"
var _swoop_timer: float = 0.0
var _swoop_target: Vector2 = Vector2.ZERO
var _phase_timer: float = 0.0
var _is_solid: bool = true

func _ready() -> void:
	add_to_group("enemies")
	if is_boss:
		add_to_group("boss")
	if health:
		health.died.connect(_on_died)
	_phase_timer = phase_interval

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
	
	# State machine
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
	var sprite := get_node_or_null("ColorRect")
	if sprite:
		if _is_solid:
			sprite.modulate.a = 1.0
			sprite.color = Color(0.6, 0.8, 1.0, 1.0)
		else:
			sprite.modulate.a = 0.4
			sprite.color = Color(0.4, 0.6, 0.9, 0.4)

func _on_died() -> void:
	queue_free()