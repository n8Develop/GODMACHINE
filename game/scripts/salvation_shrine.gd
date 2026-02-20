extends Node2D
class_name SalvationShrine

@export var shrine_text: String = "Here, you were spared."
@export var glow_color: Color = Color(0.9, 0.7, 0.3, 0.6)
@export var pulse_speed: float = 1.2
@export var fade_duration: float = 60.0  # Shrines persist for 1 minute

var _lifetime: float = 0.0
var _label: Label = null

func _ready() -> void:
	# Create glow visual
	var glow := ColorRect.new()
	glow.size = Vector2(24, 24)
	glow.position = Vector2(-12, -12)
	glow.color = glow_color
	glow.z_index = -2
	add_child(glow)
	
	# Create inner light
	var core := ColorRect.new()
	core.size = Vector2(8, 8)
	core.position = Vector2(-4, -4)
	core.color = Color(1.0, 0.95, 0.8, 0.9)
	core.z_index = -1
	add_child(core)
	
	# Create whisper text (hidden until approached)
	_label = Label.new()
	_label.text = shrine_text
	_label.add_theme_color_override(&"font_color", Color(0.9, 0.8, 0.5, 0.0))
	_label.add_theme_font_size_override(&"font_size", 12)
	_label.position = Vector2(-60, -40)
	_label.z_index = 50
	add_child(_label)
	
	# Gentle audio hum
	_create_shrine_hum()

func _create_shrine_hum() -> void:
	var audio := AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.1
	audio.stream = gen
	audio.volume_db = -32.0
	audio.autoplay = true
	add_child(audio)
	
	audio.play()
	var playback := audio.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback and playback.can_push_buffer(256):
		call_deferred("_generate_hum_loop", playback)

func _generate_hum_loop(playback: AudioStreamGeneratorPlayback) -> void:
	var phase := randf() * TAU
	for i in range(256):
		var sample := sin(phase) * 0.08
		playback.push_frame(Vector2(sample, sample))
		phase += (220.0 / 22050.0) * TAU

func _physics_process(delta: float) -> void:
	_lifetime += delta
	
	# Pulse glow
	var pulse := 0.5 + (sin(_lifetime * pulse_speed) * 0.3)
	modulate.a = pulse
	
	# Check for nearby player
	var player := get_tree().get_first_node_in_group("player")
	if player and is_instance_valid(player):
		var distance := global_position.distance_to(player.global_position)
		if distance < 80.0:
			# Fade in whisper text
			var proximity := 1.0 - (distance / 80.0)
			if _label:
				_label.add_theme_color_override(&"font_color", Color(0.9, 0.8, 0.5, proximity * 0.7))
	else:
		if _label:
			_label.add_theme_color_override(&"font_color", Color(0.9, 0.8, 0.5, 0.0))
	
	# Fade out over time
	if _lifetime >= fade_duration:
		var fade_progress := (_lifetime - fade_duration) / 10.0
		modulate.a = max(0.0, pulse * (1.0 - fade_progress))
		if _lifetime >= fade_duration + 10.0:
			queue_free()