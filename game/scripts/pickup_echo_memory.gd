extends Area2D

@export var memory_text: String = "The dungeon remembers this place."
@export var echo_color: Color = Color(0.6, 0.5, 0.9, 0.8)
@export var fade_distance: float = 150.0

var _visual: ColorRect
var _glow: ColorRect
var _text_label: Label
var _player_ref: Node2D = null

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_on_body_entered)
	
	# Create ethereal glow
	_glow = ColorRect.new()
	_glow.size = Vector2(48, 48)
	_glow.position = Vector2(-24, -24)
	_glow.color = Color(echo_color.r, echo_color.g, echo_color.b, 0.15)
	_glow.z_index = -1
	add_child(_glow)
	
	# Create core visual
	_visual = ColorRect.new()
	_visual.size = Vector2(16, 16)
	_visual.position = Vector2(-8, -8)
	_visual.color = echo_color
	add_child(_visual)
	
	# Create floating text
	_text_label = Label.new()
	_text_label.text = memory_text
	_text_label.add_theme_color_override(&"font_color", echo_color)
	_text_label.add_theme_font_size_override(&"font_size", 10)
	_text_label.position = Vector2(-60, -35)
	_text_label.modulate.a = 0.0
	_text_label.z_index = 10
	add_child(_text_label)
	
	# Find player reference
	await get_tree().process_frame
	_player_ref = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
	# Pulse glow
	var pulse := sin(Time.get_ticks_msec() * 0.002) * 0.5 + 0.5
	if _glow:
		_glow.modulate.a = 0.15 + (pulse * 0.1)
		_glow.scale = Vector2.ONE * (1.0 + pulse * 0.15)
	
	# Rotate core slowly
	if _visual:
		_visual.rotation += delta * 0.5
	
	# Fade text based on player proximity
	if _player_ref and is_instance_valid(_player_ref) and _text_label:
		var distance := global_position.distance_to(_player_ref.global_position)
		var text_alpha := clamp(1.0 - (distance / fade_distance), 0.0, 1.0)
		_text_label.modulate.a = text_alpha * 0.7

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	
	# Store memory in player metadata
	var current_memories: Array = body.get_meta("collected_memories", [])
	if memory_text not in current_memories:
		current_memories.append(memory_text)
		body.set_meta("collected_memories", current_memories)
		_spawn_collection_effect()
		_play_memory_sound()
	
	queue_free()

func _spawn_collection_effect() -> void:
	for i in range(16):
		var particle := ColorRect.new()
		particle.size = Vector2(3, 3)
		particle.position = global_position + Vector2(-1.5, -1.5)
		particle.color = echo_color
		particle.z_index = 50
		get_tree().current_scene.add_child(particle)
		
		var angle := (TAU / 16.0) * i
		var offset := Vector2(cos(angle), sin(angle)) * 60.0
		
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "position", global_position + offset, 0.8)
		tween.tween_property(particle, "modulate:a", 0.0, 0.8)
		tween.tween_property(particle, "scale", Vector2.ZERO, 0.8)
		tween.finished.connect(particle.queue_free)

func _play_memory_sound() -> void:
	var player := AudioStreamPlayer.new()
	get_tree().current_scene.add_child(player)
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 1.0
	player.stream = gen
	player.volume_db = -15.0
	player.play()
	
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback:
		var frames := int(gen.mix_rate * 1.0)
		var phase := 0.0
		for i in range(frames):
			var t := float(i) / frames
			# Ethereal chord: three frequencies
			var freq1 := 300.0 * (1.0 - t * 0.3)
			var freq2 := 450.0 * (1.0 - t * 0.3)
			var freq3 := 600.0 * (1.0 - t * 0.3)
			
			phase += (freq1 + freq2 + freq3) / (3.0 * gen.mix_rate)
			var sample := sin(phase * TAU) * 0.15 * (1.0 - t)
			playback.push_frame(Vector2(sample, sample))
	
	await get_tree().create_timer(1.1).timeout
	player.queue_free()