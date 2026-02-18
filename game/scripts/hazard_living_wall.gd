extends Node2D
class_name LivingWall

## A wall segment that pulses, watches, and sometimes reaches out to strike the unwary.

@export var pulse_interval: float = 2.5
@export var reach_distance: float = 60.0
@export var reach_damage: int = 15
@export var reach_cooldown: float = 5.0
@export var detection_range: float = 80.0

var _pulse_timer: float = 0.0
var _reach_timer: float = 0.0
var _eye_glow: ColorRect = null
var _tendril: ColorRect = null
var _audio_player: AudioStreamPlayer = null

func _ready() -> void:
	_create_visual()
	_create_audio()

func _create_visual() -> void:
	# Wall segment base
	var wall := ColorRect.new()
	wall.size = Vector2(32, 64)
	wall.position = Vector2(-16, -32)
	wall.color = Color(0.15, 0.12, 0.18, 1.0)
	add_child(wall)
	
	# Pulsing eye
	_eye_glow = ColorRect.new()
	_eye_glow.size = Vector2(8, 8)
	_eye_glow.position = Vector2(-4, -4)
	_eye_glow.color = Color(0.8, 0.2, 0.3, 0.6)
	_eye_glow.z_index = 1
	add_child(_eye_glow)
	
	# Veins
	for i in range(4):
		var vein := ColorRect.new()
		vein.size = Vector2(2, randf_range(12, 28))
		vein.position = Vector2(randf_range(-12, 12), randf_range(-24, 20))
		vein.rotation = randf_range(-0.3, 0.3)
		vein.color = Color(0.3, 0.15, 0.2, 0.4)
		add_child(vein)
	
	# Tendril (hidden initially)
	_tendril = ColorRect.new()
	_tendril.size = Vector2(4, 0)
	_tendril.position = Vector2(-2, 0)
	_tendril.color = Color(0.4, 0.2, 0.25, 0.9)
	_tendril.z_index = 2
	_tendril.hide()
	add_child(_tendril)

func _create_audio() -> void:
	_audio_player = AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.3
	_audio_player.stream = gen
	_audio_player.volume_db = -18.0
	add_child(_audio_player)

func _physics_process(delta: float) -> void:
	_pulse_timer += delta
	_reach_timer -= delta
	
	# Pulse eye
	var pulse := abs(sin(_pulse_timer * TAU / pulse_interval))
	if _eye_glow:
		_eye_glow.modulate.a = 0.4 + (pulse * 0.4)
	
	# Check for nearby player
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if not player or not is_instance_valid(player):
		return
	
	var distance := global_position.distance_to(player.global_position)
	
	# Detection range - eye tracks player
	if distance < detection_range and _eye_glow:
		var to_player := global_position.direction_to(player.global_position)
		var angle := to_player.angle()
		_eye_glow.rotation = angle
	
	# Reach attack
	if distance < reach_distance and _reach_timer <= 0.0:
		_perform_reach(player)
		_reach_timer = reach_cooldown

func _perform_reach(player: Node2D) -> void:
	if not _tendril:
		return
	
	var to_player := global_position.direction_to(player.global_position)
	var angle := to_player.angle()
	
	_tendril.show()
	_tendril.rotation = angle
	
	# Animate tendril extension
	var tween := create_tween()
	tween.tween_property(_tendril, "size:y", reach_distance, 0.3)
	tween.tween_callback(_check_tendril_hit.bind(player))
	tween.tween_interval(0.1)
	tween.tween_property(_tendril, "size:y", 0.0, 0.2)
	tween.finished.connect(func(): _tendril.hide())
	
	_play_reach_sound()

func _check_tendril_hit(player: Node2D) -> void:
	if not player or not is_instance_valid(player):
		return
	
	var distance := global_position.distance_to(player.global_position)
	if distance < reach_distance:
		var health := player.get_node_or_null("HealthComponent")
		if health and health.has_method("take_damage"):
			health.take_damage(reach_damage)
			_spawn_hit_text(player.global_position)

func _spawn_hit_text(pos: Vector2) -> void:
	var label := Label.new()
	label.text = str(reach_damage)
	label.add_theme_color_override(&"font_color", Color(0.8, 0.3, 0.4, 1.0))
	label.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	label.add_theme_constant_override(&"outline_size", 2)
	label.add_theme_font_size_override(&"font_size", 18)
	label.position = pos + Vector2(-10, -30)
	label.z_index = 100
	get_tree().current_scene.add_child(label)
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", pos.y - 60, 0.6)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.finished.connect(label.queue_free)

func _play_reach_sound() -> void:
	if not _audio_player or not is_instance_valid(_audio_player):
		return
	
	_audio_player.play()
	
	var playback := _audio_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if not playback:
		return
	
	var gen := _audio_player.stream as AudioStreamGenerator
	var frames := int(gen.mix_rate * 0.3)
	var phase := 0.0
	
	for i in range(min(frames, 256)):
		var t := float(i) / frames
		# Low growl rising to wet slap
		var freq := 80.0 + (t * 220.0)
		phase += freq / gen.mix_rate
		var sample := sin(phase * TAU) * 0.2
		# Add texture
		sample += (randf() * 2.0 - 1.0) * 0.05 * t
		sample *= (1.0 - t * 0.7)
		playback.push_frame(Vector2(sample, sample))