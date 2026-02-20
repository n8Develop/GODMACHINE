extends Area2D

@export var heal_amount: int = 40
@export var corruption_cost: float = 0.05  # Adds darkness corruption

var _pulse_timer: float = 0.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_on_body_entered)
	_create_visuals()

func _create_visuals() -> void:
	# Glass vial
	var vial := ColorRect.new()
	vial.size = Vector2(8, 14)
	vial.position = Vector2(-4, -7)
	vial.color = Color(0.15, 0.15, 0.2, 0.8)
	add_child(vial)
	
	# Blood inside
	var blood := ColorRect.new()
	blood.size = Vector2(6, 10)
	blood.position = Vector2(-3, -5)
	blood.color = Color(0.6, 0.1, 0.15, 0.9)
	blood.name = "Blood"
	add_child(blood)
	
	# Cork/stopper
	var cork := ColorRect.new()
	cork.size = Vector2(6, 3)
	cork.position = Vector2(-3, -9)
	cork.color = Color(0.3, 0.2, 0.15, 1.0)
	add_child(cork)
	
	# Collision
	var shape := CircleShape2D.new()
	shape.radius = 10.0
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)

func _physics_process(delta: float) -> void:
	_pulse_timer += delta
	var blood_rect := get_node_or_null("Blood") as ColorRect
	if blood_rect:
		var pulse := 0.9 + (sin(_pulse_timer * 3.0) * 0.1)
		blood_rect.color.a = pulse
		blood_rect.modulate = Color(1.0, 0.8 + (sin(_pulse_timer * 2.5) * 0.2), 0.8, 1.0)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	
	var health := body.get_node_or_null("HealthComponent")
	if health and health.has_method("heal"):
		health.heal(heal_amount)
		_spawn_heal_text(global_position, heal_amount)
	
	# Add corruption cost
	var main := get_tree().current_scene
	var corruption_ui := main.get_node_or_null("CanvasLayer/UIDarknessCorruption")
	if corruption_ui and corruption_ui.has_method("add_corruption"):
		corruption_ui.add_corruption(corruption_cost)
		_spawn_corruption_text(global_position)
	
	_spawn_drain_effect()
	_play_pickup_sound()
	queue_free()

func _spawn_heal_text(pos: Vector2, amount: int) -> void:
	var label := Label.new()
	label.text = "+" + str(amount)
	label.add_theme_color_override(&"font_color", Color(0.8, 0.2, 0.3, 1.0))
	label.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	label.add_theme_constant_override(&"outline_size", 2)
	label.add_theme_font_size_override(&"font_size", 18)
	label.position = pos + Vector2(-15, -40)
	label.z_index = 100
	get_tree().current_scene.add_child(label)
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", pos.y - 70, 0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.8)
	tween.finished.connect(label.queue_free)

func _spawn_corruption_text(pos: Vector2) -> void:
	var label := Label.new()
	label.text = "corrupted"
	label.add_theme_color_override(&"font_color", Color(0.2, 0.15, 0.25, 1.0))
	label.add_theme_color_override(&"font_outline_color", Color(0.5, 0.1, 0.5, 0.8))
	label.add_theme_constant_override(&"outline_size", 2)
	label.add_theme_font_size_override(&"font_size", 12)
	label.position = pos + Vector2(-25, -20)
	label.z_index = 100
	get_tree().current_scene.add_child(label)
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", pos.y - 35, 0.6)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.finished.connect(label.queue_free)

func _spawn_drain_effect() -> void:
	for i in range(8):
		var particle := ColorRect.new()
		particle.size = Vector2(3, 3)
		particle.position = global_position + Vector2(-1.5, -1.5)
		particle.color = Color(0.5, 0.1, 0.15, 0.8)
		particle.z_index = 50
		get_tree().current_scene.add_child(particle)
		
		var angle := (TAU / 8.0) * i
		var target := global_position + Vector2(cos(angle), sin(angle)) * randf_range(20.0, 35.0)
		
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "position", target, 0.5)
		tween.tween_property(particle, "modulate:a", 0.0, 0.5)
		tween.tween_property(particle, "scale", Vector2.ZERO, 0.5)
		tween.finished.connect(particle.queue_free)

func _play_pickup_sound() -> void:
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
			# Low, wet gulp sound
			var freq := 180.0 - (t * 80.0)
			phase += freq / gen.mix_rate
			var sample := sin(phase * TAU) * 0.3
			# Add harmonics for wet texture
			sample += sin(phase * TAU * 2.0) * 0.1
			sample *= (1.0 - t * 0.8)
			playback.push_frame(Vector2(sample, sample))
	
	await get_tree().create_timer(0.35).timeout
	player.queue_free()