extends CharacterBody2D

@export var drift_speed: float = 30.0
@export var echo_interval: float = 1.2
@export var echo_damage: int = 8
@export var echo_range: float = 120.0
@export var fade_distance: float = 200.0

var _echo_timer: float = 0.0
var _fade_alpha: float = 1.0
var _original_color: Color

@onready var visual: ColorRect = $Visual
@onready var health: Node = $HealthComponent

func _ready() -> void:
	add_to_group("enemies")
	_original_color = Color(0.5, 0.4, 0.7, 0.6)
	if visual:
		visual.color = _original_color
	if health and health.has_signal(&"died"):
		health.died.connect(_on_died)

func _physics_process(delta: float) -> void:
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if not player:
		return
	
	var distance := global_position.distance_to(player.global_position)
	
	# Fade based on distance
	_fade_alpha = clampf(1.0 - (distance / fade_distance), 0.3, 1.0)
	if visual:
		var fade_color := _original_color
		fade_color.a = _fade_alpha * 0.6
		visual.color = fade_color
	
	# Drift toward player slowly
	var direction := global_position.direction_to(player.global_position)
	velocity = direction * drift_speed
	
	# Add vertical sine wave drift
	var time := Time.get_ticks_msec() / 1000.0
	velocity.y += sin(time * 2.0) * 20.0
	
	move_and_slide()
	
	# Echo attack
	_echo_timer += delta
	if _echo_timer >= echo_interval and distance <= echo_range:
		_echo_timer = 0.0
		_emit_echo(player)

func _emit_echo(player: Node2D) -> void:
	# Visual pulse
	if visual:
		var tween := create_tween()
		tween.tween_property(visual, "scale", Vector2(1.5, 1.5), 0.2)
		tween.tween_property(visual, "scale", Vector2(1.0, 1.0), 0.2)
	
	# Damage player if in range
	var player_health := player.get_node_or_null("HealthComponent")
	if player_health and player_health.has_method("take_damage"):
		player_health.take_damage(echo_damage)
		_spawn_echo_text(player.global_position)
	
	# Sound
	_play_echo_sound()

func _spawn_echo_text(pos: Vector2) -> void:
	var label := Label.new()
	label.text = "echo..."
	label.add_theme_color_override(&"font_color", Color(0.5, 0.4, 0.7, 1.0))
	label.add_theme_constant_override(&"outline_size", 1)
	label.add_theme_font_size_override(&"font_size", 14)
	label.position = pos + Vector2(-20, -40)
	label.z_index = 80
	get_tree().current_scene.add_child(label)
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", pos.y - 60, 1.0)
	tween.tween_property(label, "modulate:a", 0.0, 1.0)
	tween.finished.connect(label.queue_free)

func _play_echo_sound() -> void:
	var player := AudioStreamPlayer.new()
	get_tree().current_scene.add_child(player)
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.8
	player.stream = gen
	player.volume_db = -18.0
	player.play()
	
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback:
		var frames := int(gen.mix_rate * 0.8)
		var phase1 := 0.0
		var phase2 := 0.0
		for i in range(frames):
			var t := float(i) / frames
			# Two descending sine waves for echo effect
			var freq1 := 440.0 - (t * 200.0)
			var freq2 := 330.0 - (t * 150.0)
			phase1 += freq1 / gen.mix_rate
			phase2 += freq2 / gen.mix_rate
			var sample := (sin(phase1 * TAU) * 0.5 + sin(phase2 * TAU) * 0.3) * (1.0 - t * 0.7)
			playback.push_frame(Vector2(sample, sample))
	
	await get_tree().create_timer(0.85).timeout
	player.queue_free()

func _on_died() -> void:
	# Fade out instead of particle burst
	if visual:
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(visual, "modulate:a", 0.0, 0.6)
		tween.tween_property(visual, "scale", Vector2(2.0, 2.0), 0.6)
		await tween.finished
	queue_free()