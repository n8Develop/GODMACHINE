extends RoomBase

@export var footstep_interval: float = 0.35
@export var min_speed_threshold: float = 20.0

var _footstep_timer: float = 0.0
var _footstep_player: AudioStreamPlayer = null

func _ready() -> void:
	super._ready()
	_create_footstep_audio()

func _create_footstep_audio() -> void:
	_footstep_player = AudioStreamPlayer.new()
	_footstep_player.volume_db = -18.0
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.08
	_footstep_player.stream = gen
	
	add_child(_footstep_player)

func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
	if not player:
		return
	
	var velocity: Vector2 = player.velocity
	var speed := velocity.length()
	
	if speed < min_speed_threshold:
		_footstep_timer = 0.0
		return
	
	var adjusted_interval := footstep_interval * (100.0 / speed)
	adjusted_interval = clamp(adjusted_interval, 0.15, 0.6)
	
	_footstep_timer += delta
	if _footstep_timer >= adjusted_interval:
		_footstep_timer = 0.0
		_play_footstep()

func _play_footstep() -> void:
	if not _footstep_player:
		return
	
	_footstep_player.stop()
	_footstep_player.play()
	
	var playback := _footstep_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if not playback:
		return
	
	var gen := _footstep_player.stream as AudioStreamGenerator
	var frames := int(gen.mix_rate * 0.08)
	
	for i in range(frames):
		var t := float(i) / frames
		var noise := randf() * 2.0 - 1.0
		var decay := 1.0 - (t * t * t)
		var sample := noise * decay * 0.15
		playback.push_frame(Vector2(sample, sample))