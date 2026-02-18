extends Node
class_name DungeonBreath

## The dungeon breathes — a low harmonic presence that shifts with danger and desperation.
## This is the subsonic texture beneath all other sounds.

@export var base_frequency: float = 40.0  # Below human hearing threshold
@export var danger_frequency: float = 65.0  # Rises with threat
@export var breath_rate: float = 0.08  # Slow, like sleeping
@export var volume_db: float = -24.0

var _audio_player: AudioStreamPlayer
var _phase: float = 0.0
var _current_freq: float = 40.0
var _breath_timer: float = 0.0

func _ready() -> void:
	_audio_player = AudioStreamPlayer.new()
	add_child(_audio_player)
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.5
	_audio_player.stream = gen
	_audio_player.volume_db = volume_db
	_audio_player.autoplay = true
	_audio_player.play()

func _process(delta: float) -> void:
	_breath_timer += delta
	
	# Query dungeon state
	var threat := 0.0
	var main := get_tree().current_scene
	if main:
		var memory := main.get_node_or_null("DungeonMemory")
		if memory and memory.has_method("get_threat_level"):
			threat = memory.get_threat_level()
	
	# Target frequency rises with danger
	var target_freq := lerpf(base_frequency, danger_frequency, threat)
	_current_freq = lerpf(_current_freq, target_freq, delta * 0.5)
	
	# Generate breath wave
	var playback := _audio_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback and playback.can_push_buffer(128):
		for i in range(128):
			var breath_cycle := sin(_breath_timer * breath_rate * TAU)
			var amplitude := 0.15 + (breath_cycle * 0.05)
			
			_phase += _current_freq / 22050.0
			if _phase >= 1.0:
				_phase -= 1.0
			
			var sample := sin(_phase * TAU) * amplitude
			playback.push_frame(Vector2(sample, sample))