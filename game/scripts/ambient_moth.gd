extends CharacterBody2D

@export var flutter_speed: float = 35.0
@export var attraction_range: float = 180.0
@export var light_seek_strength: float = 1.5

var _flutter_phase: float = 0.0
var _direction_timer: float = 0.0
var _base_direction := Vector2.ZERO
var _audio_player: AudioStreamPlayer

func _ready() -> void:
	add_to_group("ambient_creatures")
	collision_layer = 0
	collision_mask = 1
	
	_flutter_phase = randf() * TAU
	_direction_timer = randf() * 2.0
	_base_direction = Vector2(randf() - 0.5, randf() - 0.5).normalized()
	
	_create_visuals()
	_create_audio()

func _create_visuals() -> void:
	# Body
	var body := ColorRect.new()
	body.size = Vector2(4, 6)
	body.position = Vector2(-2, -3)
	body.color = Color(0.85, 0.82, 0.75, 0.9)
	add_child(body)
	
	# Wings (left)
	var wing_left := ColorRect.new()
	wing_left.size = Vector2(5, 3)
	wing_left.position = Vector2(-7, -2)
	wing_left.color = Color(0.95, 0.93, 0.88, 0.7)
	wing_left.name = "WingLeft"
	add_child(wing_left)
	
	# Wings (right)
	var wing_right := ColorRect.new()
	wing_right.size = Vector2(5, 3)
	wing_right.position = Vector2(2, -2)
	wing_right.color = Color(0.95, 0.93, 0.88, 0.7)
	wing_right.name = "WingRight"
	add_child(wing_right)
	
	# Dust trail
	var dust := ColorRect.new()
	dust.size = Vector2(2, 2)
	dust.position = Vector2(-1, 4)
	dust.color = Color(0.9, 0.9, 0.85, 0.3)
	dust.name = "Dust"
	add_child(dust)

func _create_audio() -> void:
	_audio_player = AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.1
	_audio_player.stream = gen
	_audio_player.volume_db = -28.0
	_audio_player.autoplay = true
	add_child(_audio_player)

func _physics_process(delta: float) -> void:
	_flutter_phase += delta * 8.0
	_direction_timer -= delta
	
	# Wing flutter animation
	var wing_left := get_node_or_null("WingLeft") as ColorRect
	var wing_right := get_node_or_null("WingRight") as ColorRect
	if wing_left and wing_right:
		var flutter := abs(sin(_flutter_phase))
		wing_left.size.y = 3.0 + flutter * 2.0
		wing_right.size.y = 3.0 + flutter * 2.0
		wing_left.position.y = -2.0 - flutter
		wing_right.position.y = -2.0 - flutter
	
	# Dust trail fade
	var dust := get_node_or_null("Dust") as ColorRect
	if dust:
		dust.modulate.a = 0.3 + abs(sin(_flutter_phase * 0.5)) * 0.3
	
	# Change direction periodically
	if _direction_timer <= 0.0:
		_base_direction = Vector2(randf() - 0.5, randf() - 0.5).normalized()
		_direction_timer = randf_range(1.5, 3.0)
	
	# Seek light sources (torches, shrines, player with torch)
	var light_dir := Vector2.ZERO
	var player := get_tree().get_first_node_in_group("player")
	
	if player and is_instance_valid(player):
		var distance := global_position.distance_to(player.global_position)
		if distance < attraction_range:
			# Check if player has torch
			if player.get_meta("has_torch", false):
				light_dir = global_position.direction_to(player.global_position)
				light_dir *= light_seek_strength
	
	# Look for shrine lights
	var shrines := get_tree().get_nodes_in_group("shrine")
	for shrine in shrines:
		if shrine and is_instance_valid(shrine):
			var distance := global_position.distance_to(shrine.global_position)
			if distance < attraction_range:
				var dir := global_position.direction_to(shrine.global_position)
				light_dir += dir * (light_seek_strength * 0.5)
	
	# Combine base flutter with light attraction
	var flutter_offset := Vector2(
		sin(_flutter_phase) * 0.3,
		cos(_flutter_phase * 1.3) * 0.3
	)
	
	velocity = (_base_direction + light_dir + flutter_offset).normalized() * flutter_speed
	move_and_slide()
	
	# Audio flutter (high frequency chirps)
	if _audio_player and _audio_player.playing:
		var playback := _audio_player.get_stream_playback() as AudioStreamGeneratorPlayback
		if playback:
			var frames_available := playback.get_frames_available()
			if frames_available > 0:
				var frames := mini(frames_available, 128)
				for i in range(frames):
					var t := float(i) / frames
					var freq := 3200.0 + sin(_flutter_phase + t * TAU) * 400.0
					var phase := fmod(_flutter_phase * freq * 0.001, TAU)
					var sample := sin(phase) * 0.15 * abs(sin(_flutter_phase * 0.5))
					playback.push_frame(Vector2(sample, sample))