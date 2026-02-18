extends Control
class_name UIDeathCounter

var _death_count: int = 0
var _label: Label = null
var _skull_icon: ColorRect = null

func _ready() -> void:
	# Position in bottom-left corner
	anchors_preset = 2  # Bottom-left
	anchor_left = 0.0
	anchor_top = 1.0
	anchor_right = 0.0
	anchor_bottom = 1.0
	offset_left = 10.0
	offset_top = -50.0
	offset_right = 150.0
	offset_bottom = -10.0
	
	_create_skull_icon()
	_create_label()
	_load_death_count()
	_update_display()
	
	# Connect to player death
	await get_tree().process_frame
	var player := get_tree().get_first_node_in_group("player")
	if player:
		var health := player.get_node_or_null("HealthComponent")
		if health:
			health.died.connect(_on_player_died)

func _create_skull_icon() -> void:
	_skull_icon = ColorRect.new()
	_skull_icon.size = Vector2(24, 24)
	_skull_icon.position = Vector2(0, 8)
	_skull_icon.color = Color(0.7, 0.1, 0.1, 1.0)
	add_child(_skull_icon)
	
	# Add eye sockets (dark rectangles)
	var eye1 := ColorRect.new()
	eye1.size = Vector2(6, 8)
	eye1.position = Vector2(4, 4)
	eye1.color = Color(0.1, 0.0, 0.0, 1.0)
	_skull_icon.add_child(eye1)
	
	var eye2 := ColorRect.new()
	eye2.size = Vector2(6, 8)
	eye2.position = Vector2(14, 4)
	eye2.color = Color(0.1, 0.0, 0.0, 1.0)
	_skull_icon.add_child(eye2)

func _create_label() -> void:
	_label = Label.new()
	_label.position = Vector2(30, 0)
	_label.add_theme_color_override(&"font_color", Color(0.9, 0.2, 0.2, 1.0))
	_label.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	_label.add_theme_constant_override(&"outline_size", 2)
	_label.add_theme_font_size_override(&"font_size", 18)
	add_child(_label)

func _load_death_count() -> void:
	# Check if player has death count metadata
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_meta("total_deaths"):
		_death_count = player.get_meta("total_deaths", 0)

func _update_display() -> void:
	if _label:
		_label.text = "DEATHS: %d" % _death_count

func _on_player_died() -> void:
	_death_count += 1
	_update_display()
	_save_death_count()
	_play_count_sound()
	_flash_skull()

func _save_death_count() -> void:
	# Store on player for persistence across game over restarts
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.set_meta("total_deaths", _death_count)

func _flash_skull() -> void:
	if _skull_icon:
		var tween := create_tween()
		tween.tween_property(_skull_icon, "modulate", Color(2.0, 0.5, 0.5, 1.0), 0.1)
		tween.tween_property(_skull_icon, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.3)

func _play_count_sound() -> void:
	var player := AudioStreamPlayer.new()
	get_tree().current_scene.add_child(player)
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.3
	player.stream = gen
	player.volume_db = -14.0
	player.play()
	
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback:
		var frames := int(gen.mix_rate * 0.3)
		var phase := 0.0
		for i in range(frames):
			var t := float(i) / frames
			var freq := 200.0 - (t * 150.0)  # Descending death toll
			phase += freq / gen.mix_rate
			var sample := sin(phase * TAU) * 0.25 * (1.0 - t)
			playback.push_frame(Vector2(sample, sample))
	
	await get_tree().create_timer(0.35).timeout
	player.queue_free()