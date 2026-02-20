extends Control
class_name UIDeathScars

@export var scar_fade_speed: float = 0.15
@export var max_scars: int = 5

var _scars: Array[ColorRect] = []
var _scar_alphas: Array[float] = []

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 15
	
	# Connect to player death signal
	await get_tree().process_frame
	var player := _get_player()
	if player:
		var health := player.get_node_or_null("HealthComponent")
		if health and health.has_signal("died"):
			health.died.connect(_on_player_died)

func _get_player() -> Node2D:
	return get_tree().get_first_node_in_group("player")

func _on_player_died() -> void:
	_add_scar()

func _add_scar() -> void:
	# Remove oldest scar if at max
	if _scars.size() >= max_scars:
		var old_scar: ColorRect = _scars.pop_front()
		_scar_alphas.pop_front()
		old_scar.queue_free()
	
	# Create new scar
	var scar := ColorRect.new()
	scar.set_anchors_preset(Control.PRESET_FULL_RECT)
	scar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scar.z_index = 15 + _scars.size()
	
	# Ragged edge pattern - diagonal slash
	var slash_width: float = randf_range(60.0, 120.0)
	var slash_angle: float = randf_range(-0.3, 0.3)
	var slash_offset: float = randf_range(-100.0, 100.0)
	
	scar.color = Color(0.15, 0.0, 0.0, 0.0)  # Dark red, starts invisible
	scar.rotation = slash_angle
	scar.position.x = slash_offset
	
	add_child(scar)
	_scars.append(scar)
	_scar_alphas.append(0.25)  # Initial alpha
	
	# Flash effect
	var tween := create_tween()
	tween.tween_property(scar, "color:a", 0.25, 0.3)
	
	_play_scar_sound()

func _process(delta: float) -> void:
	# Fade all scars slowly
	for i in range(_scars.size()):
		if _scar_alphas[i] > 0.0:
			_scar_alphas[i] -= scar_fade_speed * delta
			_scar_alphas[i] = max(0.0, _scar_alphas[i])
			_scars[i].color.a = _scar_alphas[i]

func _play_scar_sound() -> void:
	var player := AudioStreamPlayer.new()
	get_tree().current_scene.add_child(player)
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.6
	player.stream = gen
	player.volume_db = -18.0
	player.play()
	
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback:
		var frames: int = int(gen.mix_rate * 0.6)
		var phase: float = 0.0
		for i in range(frames):
			var t: float = float(i) / float(frames)
			var freq: float = 120.0 - (t * 80.0)  # Descending groan
			phase += freq / gen.mix_rate
			var sample: float = sin(phase * TAU) * 0.2 * (1.0 - t * 0.7)
			playback.push_frame(Vector2(sample, sample))
	
	await get_tree().create_timer(0.65).timeout
	player.queue_free()