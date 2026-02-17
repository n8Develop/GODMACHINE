extends CharacterBody2D

@export var fly_speed: float = 60.0
@export var swoop_speed: float = 140.0
@export var detection_range: float = 180.0
@export var swoop_cooldown: float = 2.5
@export var swoop_duration: float = 0.6
@export var is_ghost: bool = false
@export var phase_interval: float = 3.0

var _player: Node2D = null
var _swoop_timer: float = 0.0
var _swoop_active: bool = false
var _swoop_time: float = 0.0
var _idle_drift: Vector2 = Vector2.ZERO
var _phase_timer: float = 0.0
var _is_phased: bool = false

func _ready() -> void:
	add_to_group("enemies")
	_idle_drift = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	
	if is_ghost:
		# Ghost visual style - pale blue/white, semi-transparent
		var body := get_node_or_null("Body") as ColorRect
		if body:
			body.color = Color(0.6, 0.7, 1.0, 0.6)
		var wing1 := get_node_or_null("Wing1") as ColorRect
		if wing1:
			wing1.color = Color(0.5, 0.6, 0.9, 0.5)
		var wing2 := get_node_or_null("Wing2") as ColorRect
		if wing2:
			wing2.color = Color(0.5, 0.6, 0.9, 0.5)
		
		# Ghosts start phased out
		_is_phased = true
		_update_collision_state()

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
	
	# Ghost phasing mechanic
	if is_ghost:
		_phase_timer += delta
		if _phase_timer >= phase_interval:
			_phase_timer = 0.0
			_is_phased = !_is_phased
			_update_collision_state()
			_update_visual_phase()
	
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

func _update_collision_state() -> void:
	if _is_phased:
		# Phased out - no collision with player attacks
		collision_mask = 0
		collision_layer = 0
	else:
		# Phased in - normal collision
		collision_mask = 1
		collision_layer = 2

func _update_visual_phase() -> void:
	var body := get_node_or_null("Body") as ColorRect
	var wing1 := get_node_or_null("Wing1") as ColorRect
	var wing2 := get_node_or_null("Wing2") as ColorRect
	
	if _is_phased:
		# Nearly invisible when phased
		if body:
			body.modulate.a = 0.2
		if wing1:
			wing1.modulate.a = 0.2
		if wing2:
			wing2.modulate.a = 0.2
	else:
		# More visible when vulnerable
		if body:
			body.modulate.a = 0.8
		if wing1:
			wing1.modulate.a = 0.7
		if wing2:
			wing2.modulate.a = 0.7