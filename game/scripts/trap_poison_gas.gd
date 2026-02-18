extends Area2D

@export var gas_duration: float = 4.0
@export var damage_per_tick: int = 3
@export var tick_interval: float = 0.5
@export var trigger_radius: float = 60.0

var _is_active: bool = false
var _gas_timer: float = 0.0
var _gas_cloud: ColorRect = null
var _damage_timer: float = 0.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # Player layer
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_create_visuals()

func _create_visuals() -> void:
	# Warning indicator (pulsing green circle)
	var indicator := ColorRect.new()
	indicator.size = Vector2(trigger_radius * 2, trigger_radius * 2)
	indicator.position = Vector2(-trigger_radius, -trigger_radius)
	indicator.color = Color(0.2, 0.8, 0.3, 0.3)
	add_child(indicator)
	
	# Collision shape
	var shape := CircleShape2D.new()
	shape.radius = trigger_radius
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)

func _physics_process(delta: float) -> void:
	if _is_active:
		_gas_timer -= delta
		_damage_timer -= delta
		
		# Pulse the gas cloud
		if _gas_cloud:
			var pulse := 0.3 + (sin(Time.get_ticks_msec() * 0.004) * 0.15)
			_gas_cloud.modulate.a = pulse
		
		# Apply damage to player
		if _damage_timer <= 0.0:
			_damage_timer = tick_interval
			var player := get_tree().get_first_node_in_group("player")
			if player:
				var distance := global_position.distance_to(player.global_position)
				if distance <= trigger_radius:
					var health := player.get_node_or_null("HealthComponent")
					var status := player.get_node_or_null("StatusEffectComponent")
					if health:
						health.take_damage(damage_per_tick)
					if status:
						status.apply_effect("poison", 2.0, damage_per_tick)
		
		# End gas
		if _gas_timer <= 0.0:
			_deactivate_gas()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not _is_active:
		_activate_gas()

func _on_body_exited(body: Node2D) -> void:
	pass  # Gas persists even if player leaves

func _activate_gas() -> void:
	_is_active = true
	_gas_timer = gas_duration
	_damage_timer = 0.0
	
	# Create gas cloud
	_gas_cloud = ColorRect.new()
	_gas_cloud.size = Vector2(trigger_radius * 2.2, trigger_radius * 2.2)
	_gas_cloud.position = Vector2(-trigger_radius * 1.1, -trigger_radius * 1.1)
	_gas_cloud.color = Color(0.3, 0.8, 0.2, 0.4)
	_gas_cloud.z_index = -5
	add_child(_gas_cloud)
	
	_play_gas_sound()

func _deactivate_gas() -> void:
	_is_active = false
	if _gas_cloud:
		var tween := create_tween()
		tween.tween_property(_gas_cloud, "modulate:a", 0.0, 0.8)
		tween.finished.connect(_gas_cloud.queue_free)
		_gas_cloud = null

func _play_gas_sound() -> void:
	var player := AudioStreamPlayer.new()
	get_tree().current_scene.add_child(player)
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.6
	player.stream = gen
	player.volume_db = -14.0
	player.play()
	
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback:
		var frames := int(gen.mix_rate * 0.6)
		var phase := 0.0
		for i in range(frames):
			var t := float(i) / frames
			var freq := 180.0 - (t * 80.0)  # Low descending hiss
			phase += freq / gen.mix_rate
			var sample := sin(phase * TAU) * 0.15 * (1.0 - t * 0.3)
			# Add noise
			sample += (randf() * 2.0 - 1.0) * 0.05
			playback.push_frame(Vector2(sample, sample))
	
	await get_tree().create_timer(0.65).timeout
	player.queue_free()