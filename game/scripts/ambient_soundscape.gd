extends Node
class_name AmbientSoundscape

@export var base_frequency: float = 120.0
@export var update_interval: float = 2.0

var _audio_player: AudioStreamPlayer
var _generator: AudioStreamGenerator
var _update_timer: float = 0.0
var _current_intensity: float = 0.5
var _target_intensity: float = 0.5

func _ready() -> void:
	_audio_player = AudioStreamPlayer.new()
	_generator = AudioStreamGenerator.new()
	_generator.mix_rate = 22050.0
	_generator.buffer_length = 0.5
	_audio_player.stream = _generator
	_audio_player.volume_db = -20.0
	_audio_player.autoplay = true
	add_child(_audio_player)
	_audio_player.play()

func _physics_process(delta: float) -> void:
	_update_timer += delta
	if _update_timer >= update_interval:
		_update_timer = 0.0
		_analyze_situation()
	
	# Smooth intensity transition
	_current_intensity = lerp(_current_intensity, _target_intensity, delta * 0.5)
	
	# Generate audio frames
	var playback := _audio_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback:
		var available := playback.get_frames_available()
		if available > 0:
			_generate_frames(playback, min(available, 256))

func _analyze_situation() -> void:
	# Get dungeon memory via get_node instead of type reference
	var memory := get_parent().get_node_or_null("DungeonMemory")
	if not memory:
		_target_intensity = 0.5
		return
	
	var threat: float = 0.5
	var desperate: bool = false
	
	if memory.has_method("get_threat_level"):
		threat = memory.get_threat_level()
	if memory.has_method("is_player_desperate"):
		desperate = memory.is_player_desperate()
	
	# Calculate target intensity
	if desperate:
		_target_intensity = 0.9
	elif threat > 0.7:
		_target_intensity = 0.8
	elif threat < 0.3:
		_target_intensity = 0.3
	else:
		_target_intensity = 0.5

func _generate_frames(playback: AudioStreamGeneratorPlayback, count: int) -> void:
	var phase := 0.0
	for i in range(count):
		var t := float(i) / count
		var freq := base_frequency + (_current_intensity * 80.0)
		phase += freq / _generator.mix_rate
		var sample := sin(phase * TAU) * 0.15 * _current_intensity
		playback.push_frame(Vector2(sample, sample))