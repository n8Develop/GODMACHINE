extends Node
class_name AmbientSoundscape

## Generates ambient soundscape based on dungeon memory state
## The dungeon hums with different frequencies depending on threat and desperation

@export var base_frequency: float = 120.0
@export var update_interval: float = 2.0

var _audio_player: AudioStreamPlayer
var _generator: AudioStreamGenerator
var _update_timer: float = 0.0
var _current_threat: float = 0.0
var _current_desperation: bool = false

func _ready() -> void:
	_create_audio_system()

func _create_audio_system() -> void:
	_audio_player = AudioStreamPlayer.new()
	_generator = AudioStreamGenerator.new()
	_generator.mix_rate = 22050.0
	_generator.buffer_length = 0.5
	_audio_player.stream = _generator
	_audio_player.volume_db = -18.0
	_audio_player.bus = &"Master"
	add_child(_audio_player)
	_audio_player.play()

func _physics_process(delta: float) -> void:
	_update_timer += delta
	if _update_timer >= update_interval:
		_update_timer = 0.0
		_refresh_soundscape()
	
	_generate_audio_frames()

func _refresh_soundscape() -> void:
	var memory := _get_dungeon_memory()
	if not memory:
		return
	
	_current_threat = memory.get_threat_level()
	_current_desperation = memory.is_player_desperate()

func _get_dungeon_memory() -> DungeonMemory:
	var main := get_tree().current_scene
	if not main:
		return null
	return main.get_node_or_null("DungeonMemory")

func _generate_audio_frames() -> void:
	var playback := _audio_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if not playback:
		return
	
	var frames_available := playback.get_frames_available()
	if frames_available <= 0:
		return
	
	# Limit to prevent overload
	var frames_to_fill := mini(frames_available, 512)
	
	for i in range(frames_to_fill):
		var sample := _compute_sample(i)
		playback.push_frame(Vector2(sample, sample))

func _compute_sample(frame_index: int) -> float:
	var time := (Time.get_ticks_msec() / 1000.0) + (float(frame_index) / _generator.mix_rate)
	
	# Base drone - lower when desperate, higher when threatened
	var drone_freq := base_frequency
	if _current_desperation:
		drone_freq *= 0.7  # Lower, more ominous
	elif _current_threat > 0.6:
		drone_freq *= 1.3  # Higher, more tense
	
	var drone := sin(time * drone_freq * TAU) * 0.08
	
	# Threat pulse - faster with higher threat
	var pulse_freq := 0.5 + (_current_threat * 1.5)
	var pulse := sin(time * pulse_freq * TAU) * 0.03
	
	# Desperation flutter - only when desperate
	var flutter := 0.0
	if _current_desperation:
		flutter = sin(time * 8.0 * TAU) * sin(time * 0.8 * TAU) * 0.04
	
	# Combine layers
	var combined := drone + pulse + flutter
	
	# Soft limiting to prevent clipping
	combined = clamp(combined, -0.3, 0.3)
	
	return combined