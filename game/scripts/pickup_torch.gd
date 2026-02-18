extends Area2D

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_on_body_entered)
	
	# Visual
	var glow := ColorRect.new()
	glow.size = Vector2(32, 32)
	glow.position = Vector2(-16, -16)
	glow.color = Color(1.0, 0.6, 0.2, 0.3)
	add_child(glow)
	
	var flame := ColorRect.new()
	flame.size = Vector2(12, 20)
	flame.position = Vector2(-6, -18)
	flame.color = Color(1.0, 0.8, 0.3, 1.0)
	add_child(flame)
	
	var handle := ColorRect.new()
	handle.size = Vector2(6, 16)
	handle.position = Vector2(-3, 2)
	handle.color = Color(0.4, 0.3, 0.2, 1.0)
	add_child(handle)
	
	var shape := CircleShape2D.new()
	shape.radius = 16.0
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)

func _physics_process(delta: float) -> void:
	# Flame flicker
	var flame := get_node_or_null("ColorRect2")
	if flame:
		var pulse := 0.8 + (sin(Time.get_ticks_msec() * 0.01) * 0.2)
		flame.scale.y = pulse

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	
	body.set_meta("has_torch", true)
	
	# Create darkness overlay if it doesn't exist
	var main := get_tree().current_scene
	if not main.get_node_or_null("DarknessOverlay"):
		var overlay := Node.new()
		overlay.name = "DarknessOverlay"
		overlay.set_script(load("res://scripts/darkness_overlay.gd"))
		main.add_child(overlay)
	
	_spawn_pickup_text(body.global_position)
	_play_pickup_sound()
	queue_free()

func _spawn_pickup_text(pos: Vector2) -> void:
	var label := Label.new()
	label.text = "TORCH ACQUIRED"
	label.add_theme_color_override(&"font_color", Color(1.0, 0.8, 0.3, 1.0))
	label.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	label.add_theme_constant_override(&"outline_size", 2)
	label.add_theme_font_size_override(&"font_size", 14)
	label.position = pos + Vector2(-50, -30)
	label.z_index = 100
	get_tree().current_scene.add_child(label)
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", pos.y - 60, 0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.8)
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
			var freq := 300.0 + (sin(t * TAU * 3.0) * 200.0)
			phase += freq / gen.mix_rate
			var sample := sin(phase * TAU) * 0.25 * (1.0 - t * 0.7)
			playback.push_frame(Vector2(sample, sample))
	
	await get_tree().create_timer(0.35).timeout
	player.queue_free()