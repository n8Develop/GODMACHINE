extends CharacterBody2D

@export var fly_speed: float = 60.0
@export var swoop_speed: float = 140.0
@export var detection_range: float = 180.0
@export var swoop_cooldown: float = 2.5
@export var swoop_duration: float = 0.6

var _player: Node2D = null
var _swoop_timer: float = 0.0
var _swoop_active: bool = false
var _swoop_time: float = 0.0
var _idle_drift: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group("enemies")
	_idle_drift = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()

func _physics_process(delta: float) -> void:
	if not _player:
		_player = get_tree().get_first_node_in_group("player")
		if not _player:
			return
	
	var distance := global_position.distance_to(_player.global_position)
	
	# Update timers
	if _swoop_timer > 0.0:
		_swoop_timer -= delta
	
	if _swoop_active:
		_swoop_time -= delta
		if _swoop_time <= 0.0:
			_swoop_active = false
	
	# Behavior logic
	if distance < detection_range:
		if not _swoop_active and _swoop_timer <= 0.0:
			# Start swoop
			_swoop_active = true
			_swoop_time = swoop_duration
			_swoop_timer = swoop_cooldown
		
		if _swoop_active:
			# Swoop at player
			var dir := global_position.direction_to(_player.global_position)
			velocity = dir * swoop_speed
		else:
			# Circle slowly
			var offset := Vector2(sin(Time.get_ticks_msec() * 0.002) * 30, cos(Time.get_ticks_msec() * 0.002) * 30)
			var target := _player.global_position + offset
			var dir := global_position.direction_to(target)
			velocity = dir * fly_speed
	else:
		# Idle drift
		velocity = _idle_drift * fly_speed * 0.4
	
	move_and_slide()