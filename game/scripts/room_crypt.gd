extends RoomBase

@export var crypt_type: String = "forgotten"  # forgotten, haunted, defiled
@export var spawn_chance: float = 0.7

var _ambient_audio: AudioStreamPlayer = null
var _has_spawned: bool = false

func _ready() -> void:
	super._ready()
	room_id = "crypt_" + str(randi())
	_adapt_to_memory()
	_create_crypt_ambience()
	_create_tombstones()
	
	# Adaptive spawning based on player state
	if randf() < spawn_chance and not _has_spawned:
		_spawn_adaptive_threat()

func _adapt_to_memory() -> void:
	var main := get_tree().current_scene
	var memory := main.get_node_or_null("DungeonMemory")
	if not memory:
		return
	
	var is_desperate: bool = memory.is_player_desperate() if memory.has_method("is_player_desperate") else false
	var threat: float = memory.get_threat_level() if memory.has_method("get_threat_level") else 0.5
	
	# Adjust crypt type based on player state
	if is_desperate:
		crypt_type = "forgotten"  # Offer respite
		spawn_chance = 0.3
	elif threat > 0.7:
		crypt_type = "haunted"  # Escalate tension
		spawn_chance = 0.8
	else:
		crypt_type = "defiled"  # Neutral ground
		spawn_chance = 0.5

func _create_crypt_ambience() -> void:
	_ambient_audio = AudioStreamPlayer.new()
	add_child(_ambient_audio)
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 2.0
	_ambient_audio.stream = gen
	_ambient_audio.volume_db = -26.0
	_ambient_audio.autoplay = true
	_ambient_audio.play()
	
	# Start audio generation in background
	_generate_crypt_drone.call_deferred()

func _generate_crypt_drone() -> void:
	var playback := _ambient_audio.get_stream_playback() as AudioStreamGeneratorPlayback
	if not playback:
		return
	
	var gen := _ambient_audio.stream as AudioStreamGenerator
	var frames := int(gen.mix_rate * 2.0)
	var phase := randf() * TAU
	
	# Different tones for different crypt types
	var base_freq: float = 50.0
	match crypt_type:
		"forgotten":
			base_freq = 45.0  # Lower, peaceful
		"haunted":
			base_freq = 60.0  # Higher, tense
		"defiled":
			base_freq = 52.0  # Middle ground
	
	for i in range(frames):
		var t := float(i) / frames
		var pulse := sin(t * TAU * 0.3)  # Slow breath
		var freq := base_freq + (pulse * 8.0)
		phase += freq / gen.mix_rate
		var sample := sin(phase * TAU) * 0.15 * (0.7 + pulse * 0.3)
		playback.push_frame(Vector2(sample, sample))

func _create_tombstones() -> void:
	var tombstone_count := randi_range(3, 7)
	
	for i in range(tombstone_count):
		var stone := ColorRect.new()
		stone.size = Vector2(12, 20)
		stone.position = Vector2(
			randf_range(100, 540),
			randf_range(100, 360)
		)
		
		# Color based on crypt type
		match crypt_type:
			"forgotten":
				stone.color = Color(0.5, 0.5, 0.45, 0.6)  # Weathered gray
			"haunted":
				stone.color = Color(0.3, 0.35, 0.4, 0.8)  # Dark stone
			"defiled":
				stone.color = Color(0.4, 0.3, 0.3, 0.7)  # Blood-stained
		
		stone.z_index = -5
		add_child(stone)
		
		# Some stones have inscriptions (visual only)
		if randf() < 0.3:
			var mark := ColorRect.new()
			mark.size = Vector2(8, 2)
			mark.position = Vector2(2, 8)
			mark.color = Color(0.2, 0.2, 0.2, 0.4)
			stone.add_child(mark)

func _spawn_adaptive_threat() -> void:
	var main := get_tree().current_scene
	var memory := main.get_node_or_null("DungeonMemory")
	var player := get_tree().get_first_node_in_group("player")
	
	if not player:
		return
	
	var spawn_pos := Vector2(320, 240)
	var threat_type := "skeleton"
	
	# Choose threat based on crypt type and player state
	match crypt_type:
		"forgotten":
			# Minimal threat — echo shades or rats
			if randf() < 0.5:
				var echo_scene := load("res://scenes/enemy_echo_shade.tscn")
				if echo_scene:
					var echo := echo_scene.instantiate()
					echo.global_position = spawn_pos
					add_child(echo)
			_has_spawned = true
			return
			
		"haunted":
			# Spiritual threat — wraiths or echo shades
			threat_type = "wraith"
			var wraith_scene := load("res://scenes/enemy_bat_wraith.tscn")
			if wraith_scene:
				var wraith := wraith_scene.instantiate()
				wraith.global_position = spawn_pos
				add_child(wraith)
			
		"defiled":
			# Undead threat — skeletons
			threat_type = "skeleton"
			var skeleton_scene := load("res://scenes/enemy_skeleton.tscn")
			if skeleton_scene:
				var skeleton := skeleton_scene.instantiate()
				skeleton.global_position = spawn_pos
				add_child(skeleton)
	
	# Record threat in memory
	if memory and memory.has_method("record_room_entry"):
		var hp_percent := 1.0
		var health_comp := player.get_node_or_null("HealthComponent")
		if health_comp:
			hp_percent = float(health_comp.current_health) / float(health_comp.max_health)
		memory.record_room_entry("crypt_" + crypt_type, hp_percent)
	
	_has_spawned = true

func _physics_process(_delta: float) -> void:
	# Keep ambient audio running
	if _ambient_audio and not _ambient_audio.playing:
		_ambient_audio.play()
		_generate_crypt_drone.call_deferred()