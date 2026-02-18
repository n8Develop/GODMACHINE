extends Area2D

@export var teleport_distance: float = 150.0
@export var scroll_color: Color = Color(0.4, 0.7, 1.0, 1.0)

func _ready() -> void:
	add_to_group("pickups")
	body_entered.connect(_on_body_entered)
	
	# Update visual
	var rect := get_node_or_null("ColorRect")
	if rect:
		rect.color = scroll_color

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		# Grant teleport ability via metadata
		body.set_meta("has_teleport", true)
		body.set_meta("teleport_distance", teleport_distance)
		
		_spawn_pickup_text(body.global_position)
		_play_pickup_sound()
		queue_free()

func _spawn_pickup_text(pos: Vector2) -> void:
	var label := Label.new()
	label.text = "TELEPORT"
	label.add_theme_color_override(&"font_color", Color(0.4, 0.7, 1.0, 1.0))
	label.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	label.add_theme_constant_override(&"outline_size", 2)
	label.add_theme_font_size_override(&"font_size", 16)
	label.position = pos + Vector2(-30, -30)
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
			var freq := 400.0 + (t * 800.0)  # Rising pitch
			phase += freq / gen.mix_rate
			var sample := sin(phase * TAU) * 0.25 * (1.0 - t)
			playback.push_frame(Vector2(sample, sample))
	
	await get_tree().create_timer(0.35).timeout
	player.queue_free()