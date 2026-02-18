extends CharacterBody2D

@export var hover_speed: float = 40.0
@export var cast_range: float = 200.0
@export var cast_cooldown: float = 2.5
@export var bolt_damage: int = 12
@export var bolt_speed: float = 150.0
@export var retreat_distance: float = 120.0

var _cast_timer: float = 0.0
var _hover_offset: float = 0.0
var _retreat_timer: float = 0.0

func _ready() -> void:
	add_to_group("enemies")
	_hover_offset = randf() * TAU
	
	var health := get_node_or_null("HealthComponent")
	if health:
		health.died.connect(_on_died)
	
	# Create visual layers
	var robe := ColorRect.new()
	robe.size = Vector2(28, 36)
	robe.position = Vector2(-14, -32)
	robe.color = Color(0.15, 0.1, 0.25, 1.0)
	add_child(robe)
	
	var hood := ColorRect.new()
	hood.size = Vector2(24, 16)
	hood.position = Vector2(-12, -38)
	hood.color = Color(0.1, 0.05, 0.15, 1.0)
	add_child(hood)
	
	var skull := ColorRect.new()
	skull.size = Vector2(16, 14)
	skull.position = Vector2(-8, -34)
	skull.color = Color(0.9, 0.9, 0.8, 1.0)
	add_child(skull)
	
	# Floating staff
	var staff := ColorRect.new()
	staff.size = Vector2(4, 32)
	staff.position = Vector2(-16, -24)
	staff.color = Color(0.4, 0.25, 0.15, 1.0)
	staff.name = "Staff"
	add_child(staff)
	
	var orb := ColorRect.new()
	orb.size = Vector2(8, 8)
	orb.position = Vector2(-18, -28)
	orb.color = Color(0.6, 0.3, 0.9, 0.9)
	orb.name = "Orb"
	add_child(orb)

func _physics_process(delta: float) -> void:
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if not player:
		return
	
	var distance := global_position.distance_to(player.global_position)
	var direction := global_position.direction_to(player.global_position)
	
	_cast_timer -= delta
	_retreat_timer -= delta
	
	# Hover motion
	_hover_offset += delta * 2.0
	var hover_y := sin(_hover_offset) * 8.0
	
	# Behavior: maintain distance, cast spells
	if distance < retreat_distance and _retreat_timer <= 0.0:
		# Too close — retreat
		velocity = -direction * hover_speed * 1.5
		_retreat_timer = 0.8
	elif distance > cast_range + 50.0:
		# Too far — advance slowly
		velocity = direction * hover_speed * 0.6
	else:
		# Ideal range — strafe
		var strafe := Vector2(-direction.y, direction.x)
		velocity = strafe * hover_speed * 0.8
	
	velocity.y += hover_y * 2.0
	move_and_slide()
	
	# Cast spell
	if distance <= cast_range and _cast_timer <= 0.0:
		_cast_bolt(player.global_position)
		_cast_timer = cast_cooldown
	
	# Animate staff and orb
	var staff := get_node_or_null("Staff")
	var orb := get_node_or_null("Orb")
	if staff:
		staff.rotation = sin(Time.get_ticks_msec() * 0.001) * 0.15
	if orb:
		var pulse := 0.9 + sin(Time.get_ticks_msec() * 0.005) * 0.1
		orb.scale = Vector2(pulse, pulse)

func _cast_bolt(target_pos: Vector2) -> void:
	var direction := global_position.direction_to(target_pos)
	
	var bolt := Area2D.new()
	bolt.collision_layer = 0
	bolt.collision_mask = 2  # Player layer
	bolt.global_position = global_position
	
	var visual := ColorRect.new()
	visual.size = Vector2(8, 8)
	visual.position = Vector2(-4, -4)
	visual.color = Color(0.6, 0.3, 0.9, 1.0)
	bolt.add_child(visual)
	
	var trail := ColorRect.new()
	trail.size = Vector2(12, 4)
	trail.position = Vector2(-16, -2)
	trail.color = Color(0.4, 0.2, 0.6, 0.4)
	trail.z_index = -1
	bolt.add_child(trail)
	
	var shape := CircleShape2D.new()
	shape.radius = 4.0
	var collision := CollisionShape2D.new()
	collision.shape = shape
	bolt.add_child(collision)
	
	var script := GDScript.new()
	script.source_code = """
extends Area2D

var velocity := Vector2.ZERO
var damage := 12
var lifetime := 2.5

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	position += velocity * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
	
	# Rotate trail
	var trail := get_node_or_null('ColorRect2')
	if trail:
		trail.rotation = velocity.angle()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group('player'):
		var health := body.get_node_or_null('HealthComponent')
		if health:
			health.take_damage(damage)
		_spawn_hit_particles()
		queue_free()

func _spawn_hit_particles() -> void:
	for i in range(6):
		var particle := ColorRect.new()
		particle.size = Vector2(3, 3)
		particle.position = global_position + Vector2(-1.5, -1.5)
		particle.color = Color(0.6, 0.3, 0.9, 1.0)
		particle.z_index = 50
		get_tree().current_scene.add_child(particle)
		
		var angle := (TAU / 6.0) * i
		var offset := Vector2(cos(angle), sin(angle)) * 30.0
		
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, 'position', global_position + offset, 0.3)
		tween.tween_property(particle, 'modulate:a', 0.0, 0.3)
		tween.finished.connect(particle.queue_free)
"""
	script.reload()
	bolt.set_script(script)
	bolt.velocity = direction * bolt_speed
	bolt.damage = bolt_damage
	
	get_tree().current_scene.add_child(bolt)
	_play_cast_sound()
	
	# Visual flash
	var orb := get_node_or_null("Orb")
	if orb:
		orb.modulate = Color(1.5, 1.5, 1.5, 1.0)
		var tween := create_tween()
		tween.tween_property(orb, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.2)

func _play_cast_sound() -> void:
	var player := AudioStreamPlayer.new()
	get_tree().current_scene.add_child(player)
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.3
	player.stream = gen
	player.volume_db = -14.0
	player.play()
	
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback:
		var frames := int(gen.mix_rate * 0.3)
		var phase := 0.0
		for i in range(frames):
			var t := float(i) / frames
			var freq := 400.0 + (t * 300.0)  # Rising magical tone
			phase += freq / gen.mix_rate
			var sample := sin(phase * TAU) * 0.25 * (1.0 - t * 0.5)
			playback.push_frame(Vector2(sample, sample))
	
	await get_tree().create_timer(0.35).timeout
	player.queue_free()

func _on_died() -> void:
	# Death particles
	for i in range(12):
		var particle := ColorRect.new()
		particle.size = Vector2(4, 4)
		particle.position = global_position + Vector2(-2, -2)
		particle.color = Color(0.6, 0.3, 0.9, 1.0) if i % 2 == 0 else Color(0.9, 0.9, 0.8, 1.0)
		particle.z_index = 50
		get_tree().current_scene.add_child(particle)
		
		var angle := (TAU / 12.0) * i
		var offset := Vector2(cos(angle), sin(angle)) * 40.0
		
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "position", global_position + offset, 0.5)
		tween.tween_property(particle, "modulate:a", 0.0, 0.5)
		tween.tween_property(particle, "rotation", randf() * TAU, 0.5)
		tween.finished.connect(particle.queue_free)
	
	queue_free()