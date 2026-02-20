extends Area2D

@export var heal_amount: int = 30
@export var suppress_hunger: bool = true
@export var suppress_duration: float = 45.0

var _hover_offset: float = 0.0

func _ready() -> void:
	add_to_group("pickups")
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_on_body_entered)
	_create_visuals()

func _create_visuals() -> void:
	# Bread loaf shape - warm brown
	var bread := ColorRect.new()
	bread.size = Vector2(16, 10)
	bread.position = Vector2(-8, -5)
	bread.color = Color(0.6, 0.4, 0.2, 1.0)
	add_child(bread)
	
	# Crust highlights
	var crust := ColorRect.new()
	crust.size = Vector2(14, 2)
	crust.position = Vector2(-7, -5)
	crust.color = Color(0.5, 0.3, 0.15, 1.0)
	add_child(crust)
	
	# Collision
	var shape := CircleShape2D.new()
	shape.radius = 12.0
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)

func _physics_process(delta: float) -> void:
	_hover_offset += delta * 2.0
	position.y += sin(_hover_offset) * 0.3

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	
	var health := body.get_node_or_null("HealthComponent")
	if health and health.has_method("heal"):
		health.heal(heal_amount)
		_spawn_heal_text(global_position, heal_amount)
	
	# Suppress hunger whispers
	if suppress_hunger:
		var main := get_tree().current_scene
		var hunger_whisper := main.get_node_or_null("HungerWhisper")
		if hunger_whisper and hunger_whisper.has_method("suppress_whispers"):
			hunger_whisper.suppress_whispers(suppress_duration)
			_spawn_sated_text(global_position)
	
	_play_pickup_sound()
	queue_free()

func _spawn_heal_text(pos: Vector2, amount: int) -> void:
	var label := Label.new()
	label.text = "+%d HP" % amount
	label.add_theme_color_override(&"font_color", Color(0.3, 0.9, 0.3, 1.0))
	label.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	label.add_theme_constant_override(&"outline_size", 2)
	label.add_theme_font_size_override(&"font_size", 18)
	label.position = pos + Vector2(-20, -40)
	label.z_index = 100
	get_tree().current_scene.add_child(label)
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", pos.y - 70, 0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.8)
	tween.finished.connect(label.queue_free)

func _spawn_sated_text(pos: Vector2) -> void:
	var label := Label.new()
	label.text = "SATED"
	label.add_theme_color_override(&"font_color", Color(0.9, 0.7, 0.3, 1.0))
	label.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	label.add_theme_constant_override(&"outline_size", 2)
	label.add_theme_font_size_override(&"font_size", 16)
	label.position = pos + Vector2(-25, -60)
	label.z_index = 100
	get_tree().current_scene.add_child(label)
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", pos.y - 85, 1.0)
	tween.tween_property(label, "modulate:a", 0.0, 1.0)
	tween.finished.connect(label.queue_free)

func _play_pickup_sound() -> void:
	var player := AudioStreamPlayer.new()
	get_tree().current_scene.add_child(player)
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.25
	player.stream = gen
	player.volume_db = -14.0
	player.play()
	
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback:
		var frames := int(gen.mix_rate * 0.25)
		var phase := 0.0
		for i in range(frames):
			var t := float(i) / frames
			var freq := 300.0 + (t * 200.0)  # Warm rising tone
			phase += freq / gen.mix_rate
			var sample := sin(phase * TAU) * 0.25 * (1.0 - t)
			playback.push_frame(Vector2(sample, sample))
	
	await get_tree().create_timer(0.3).timeout
	player.queue_free()