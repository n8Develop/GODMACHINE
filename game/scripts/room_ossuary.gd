extends RoomBase

@export var bone_pile_count: int = 8
@export var rattle_interval: float = 15.0

var _rattle_timer: float = 0.0
var _ambient_player: AudioStreamPlayer = null

func _ready() -> void:
	super._ready()
	_create_ossuary_floor()
	_create_bone_piles()
	_create_grave_markers()
	_create_ossuary_ambience()

func _create_ossuary_floor() -> void:
	# Dark stone floor
	var floor := ColorRect.new()
	floor.size = Vector2(640, 480)
	floor.color = Color(0.12, 0.11, 0.1, 1.0)
	floor.z_index = -10
	add_child(floor)

func _create_bone_piles() -> void:
	var positions := [
		Vector2(120, 140), Vector2(520, 140),
		Vector2(160, 240), Vector2(480, 240),
		Vector2(200, 340), Vector2(440, 340),
		Vector2(280, 120), Vector2(360, 360),
	]
	
	for i in bone_pile_count:
		var pile := Node2D.new()
		pile.position = positions[i]
		add_child(pile)
		
		# Multiple bones in pile
		for j in range(randi_range(3, 6)):
			var bone := ColorRect.new()
			bone.size = Vector2(randf_range(8, 16), randf_range(3, 5))
			bone.position = Vector2(
				randf_range(-12, 12),
				randf_range(-8, 8)
			)
			bone.rotation = randf_range(-PI, PI)
			bone.color = Color(0.85, 0.82, 0.75, 1.0)
			bone.z_index = -4
			pile.add_child(bone)

func _create_grave_markers() -> void:
	for i in range(4):
		var marker := ColorRect.new()
		marker.size = Vector2(10, 18)
		marker.position = Vector2(
			80 + i * 160,
			380
		)
		marker.color = Color(0.3, 0.28, 0.25, 1.0)
		marker.z_index = -3
		add_child(marker)
		
		# Crack in marker
		var crack := ColorRect.new()
		crack.size = Vector2(8, 1)
		crack.position = Vector2(1, 8)
		crack.color = Color(0.15, 0.13, 0.12, 1.0)
		marker.add_child(crack)

func _create_ossuary_ambience() -> void:
	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.volume_db = -28.0
	add_child(_ambient_player)
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.1
	_ambient_player.stream = gen
	_ambient_player.autoplay = true
	_ambient_player.play()

func _physics_process(delta: float) -> void:
	_rattle_timer += delta
	
	# Generate ambient drone
	if _ambient_player and _ambient_player.playing:
		var playback := _ambient_player.get_stream_playback() as AudioStreamGeneratorPlayback
		if playback and playback.can_push_buffer(64):
			var phase := randf() * TAU
			for i in range(64):
				var freq := 48.0 + sin(Time.get_ticks_msec() * 0.0001) * 8.0
				phase += freq / 22050.0
				var sample := sin(phase * TAU) * 0.2
				playback.push_frame(Vector2(sample, sample))
	
	# Periodic bone rattle
	if _rattle_timer >= rattle_interval:
		_rattle_timer = 0.0
		_show_whisper()
		_play_rattle_sound()

func _show_whisper() -> void:
	var texts := [
		"The bones remember...",
		"We were many...",
		"Rest is a lie...",
		"Buried but not forgotten...",
	]
	
	var label := Label.new()
	label.text = texts.pick_random()
	label.add_theme_color_override(&"font_color", Color(0.6, 0.55, 0.5, 0.7))
	label.add_theme_font_size_override(&"font_size", 14)
	label.position = Vector2(
		randf_range(200, 440),
		randf_range(80, 120)
	)
	label.z_index = 60
	label.modulate.a = 0.0
	add_child(label)
	
	var tween := create_tween()
	tween.tween_property(label, "modulate:a", 0.7, 1.0)
	tween.tween_interval(2.5)
	tween.tween_property(label, "modulate:a", 0.0, 1.5)
	tween.finished.connect(label.queue_free)

func _play_rattle_sound() -> void:
	var player := AudioStreamPlayer.new()
	add_child(player)
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.3
	player.stream = gen
	player.volume_db = -24.0
	player.play()
	
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback:
		var frames := int(gen.mix_rate * 0.3)
		for i in range(frames):
			var t := float(i) / frames
			var noise := randf() * 2.0 - 1.0
			var decay := 1.0 - (t * t)
			var sample := noise * decay * 0.25
			playback.push_frame(Vector2(sample, sample))
	
	await get_tree().create_timer(0.35).timeout
	player.queue_free()