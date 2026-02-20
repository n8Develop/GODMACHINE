extends Control
class_name UIDeathMarks

@export var mark_fade_duration: float = 2.0
@export var marks_per_death: int = 3

var _death_count: int = 0
var _marks: Array[ColorRect] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 45
	
	anchors_preset = Control.PRESET_FULL_RECT
	
	_load_death_count()
	_create_existing_marks()
	
	var player := _get_player()
	if player:
		var health := player.get_node_or_null("HealthComponent")
		if health and health.has_signal("died"):
			health.died.connect(_on_player_died)

func _get_player() -> Node2D:
	return get_tree().get_first_node_in_group("player")

func _load_death_count() -> void:
	if FileAccess.file_exists("user://death_count.dat"):
		var file := FileAccess.open("user://death_count.dat", FileAccess.READ)
		if file:
			_death_count = file.get_32()
			file.close()

func _create_existing_marks() -> void:
	for i in range(_death_count):
		_add_mark_instant()

func _on_player_died() -> void:
	_death_count += 1
	for i in range(marks_per_death):
		await get_tree().create_timer(0.15 * i).timeout
		_add_mark_animated()
	_play_mark_sound()

func _add_mark_instant() -> void:
	var mark := ColorRect.new()
	mark.size = Vector2(randf_range(8, 16), randf_range(2, 4))
	
	# Random placement on arms/torso area
	var x := randf_range(50, 590)
	var y := randf_range(100, 380)
	mark.position = Vector2(x, y)
	
	# Dark crimson, semi-transparent
	mark.color = Color(0.3, 0.05, 0.08, 0.6)
	mark.rotation = randf_range(-PI/6, PI/6)
	mark.z_index = 45
	
	add_child(mark)
	_marks.append(mark)

func _add_mark_animated() -> void:
	var mark := ColorRect.new()
	mark.size = Vector2(randf_range(8, 16), randf_range(2, 4))
	
	var x := randf_range(50, 590)
	var y := randf_range(100, 380)
	mark.position = Vector2(x, y)
	
	mark.color = Color(0.8, 0.1, 0.15, 0.0)  # Start invisible
	mark.rotation = randf_range(-PI/6, PI/6)
	mark.z_index = 45
	
	add_child(mark)
	_marks.append(mark)
	
	# Fade in
	var tween := create_tween()
	tween.tween_property(mark, "color:a", 0.6, mark_fade_duration)
	tween.parallel().tween_property(mark, "color", Color(0.3, 0.05, 0.08, 0.6), mark_fade_duration)

func _play_mark_sound() -> void:
	var player := AudioStreamPlayer.new()
	get_tree().current_scene.add_child(player)
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.3
	player.stream = gen
	player.volume_db = -18.0
	player.play()
	
	await get_tree().create_timer(0.05).timeout
	
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback and playback.can_push_buffer(256):
		var phase := randf() * TAU
		for i in range(256):
			var t := float(i) / 256.0
			var freq := 120.0 - (t * 40.0)
			phase += freq / gen.mix_rate
			var sample := sin(phase * TAU) * 0.2 * (1.0 - t)
			playback.push_frame(Vector2(sample, sample))
	
	await get_tree().create_timer(0.35).timeout
	player.queue_free()