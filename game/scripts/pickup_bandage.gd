extends Area2D

@export var heal_amount: int = 15
@export var stop_bleeding: bool = true

var _player_nearby: bool = false
var _pulse_phase: float = 0.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_on_body_entered)
	_create_visuals()

func _create_visuals() -> void:
	# Cloth wrapping visual
	var cloth := ColorRect.new()
	cloth.size = Vector2(12, 16)
	cloth.position = Vector2(-6, -8)
	cloth.color = Color(0.85, 0.82, 0.75, 1.0)
	add_child(cloth)
	
	# Blood stain on cloth
	var stain := ColorRect.new()
	stain.size = Vector2(8, 4)
	stain.position = Vector2(-4, 0)
	stain.color = Color(0.6, 0.2, 0.15, 0.6)
	add_child(stain)
	
	# Collision
	var shape := RectangleShape2D.new()
	shape.size = Vector2(16, 20)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)

func _physics_process(delta: float) -> void:
	_pulse_phase += delta * 2.0
	var pulse := (sin(_pulse_phase) * 0.5 + 0.5) * 0.15
	modulate.a = 0.85 + pulse

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	
	var health := body.get_node_or_null("HealthComponent")
	if not health:
		return
	
	# Heal
	health.heal(heal_amount)
	
	# Stop bleeding if player is wounded
	if stop_bleeding:
		var blood_trail := get_tree().get_first_node_in_group("blood_trail")
		if blood_trail and blood_trail.has_method("stop_bleeding"):
			blood_trail.stop_bleeding(3.0)  # 3 seconds of no bleeding
			_spawn_bandage_text(body.global_position)
	
	_spawn_heal_text(body.global_position, heal_amount)
	_play_pickup_sound()
	queue_free()

func _spawn_heal_text(pos: Vector2, amount: int) -> void:
	var label := Label.new()
	label.text = "+" + str(amount)
	label.add_theme_color_override(&"font_color", Color(0.3, 0.9, 0.4, 1.0))
	label.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	label.add_theme_constant_override(&"outline_size", 2)
	label.add_theme_font_size_override(&"font_size", 18)
	label.position = pos + Vector2(-15, -35)
	label.z_index = 100
	get_tree().current_scene.add_child(label)
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", pos.y - 60, 0.6)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.finished.connect(label.queue_free)

func _spawn_bandage_text(pos: Vector2) -> void:
	var label := Label.new()
	label.text = "BLEEDING STOPPED"
	label.add_theme_color_override(&"font_color", Color(0.85, 0.82, 0.75, 1.0))
	label.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	label.add_theme_constant_override(&"outline_size", 2)
	label.add_theme_font_size_override(&"font_size", 14)
	label.position = pos + Vector2(-60, -55)
	label.z_index = 101
	get_tree().current_scene.add_child(label)
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", pos.y - 75, 0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.8)
	tween.finished.connect(label.queue_free)

func _play_pickup_sound() -> void:
	var player := AudioStreamPlayer.new()
	get_tree().current_scene.add_child(player)
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.25
	player.stream = gen
	player.volume_db = -18.0
	player.play()
	
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback:
		var frames := int(gen.mix_rate * 0.25)
		var phase := 0.0
		for i in range(frames):
			var t := float(i) / frames
			var freq := 400.0 + (t * 200.0)  # Rising gentle tone
			phase += freq / gen.mix_rate
			var sample := sin(phase * TAU) * 0.2 * (1.0 - t * 0.5)
			playback.push_frame(Vector2(sample, sample))
	
	await get_tree().create_timer(0.3).timeout
	player.queue_free()