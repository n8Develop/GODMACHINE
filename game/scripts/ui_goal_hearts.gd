extends Control
class_name UIGoalHearts

@onready var label := $Label

const HEARTS_NEEDED := 3  # Simple goal: collect 3 hearts to win

func _ready() -> void:
	# Position in bottom-right corner
	anchors_preset = Control.PRESET_BOTTOM_RIGHT
	anchor_left = 1.0
	anchor_top = 1.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = -180.0
	offset_top = -50.0
	offset_right = -20.0
	offset_bottom = -20.0
	
	_create_label()
	_update_display()

func _create_label() -> void:
	label = Label.new()
	label.name = "Label"
	label.anchors_preset = Control.PRESET_FULL_RECT
	label.anchor_right = 1.0
	label.anchor_bottom = 1.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override(&"font_color", Color(1.0, 0.3, 0.4, 1.0))
	label.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	label.add_theme_constant_override(&"outline_size", 2)
	label.add_theme_font_size_override(&"font_size", 18)
	add_child(label)

func _process(_delta: float) -> void:
	_update_display()

func _update_display() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not player or not label:
		return
	
	var hearts_collected: int = player.get_meta("hearts_collected", 0)
	
	# Build heart string
	var heart_str := ""
	for i in range(HEARTS_NEEDED):
		if i < hearts_collected:
			heart_str += "♥"  # Filled heart
		else:
			heart_str += "♡"  # Empty heart
	
	label.text = "GOAL: " + heart_str
	
	# Check win condition
	if hearts_collected >= HEARTS_NEEDED:
		_trigger_victory()

func _trigger_victory() -> void:
	# Only trigger once
	if get_meta("victory_triggered", false):
		return
	set_meta("victory_triggered", true)
	
	# Flash the UI
	var tween := create_tween()
	tween.tween_property(label, "modulate", Color(1.0, 1.0, 0.3, 1.0), 0.3)
	tween.tween_property(label, "modulate", Color(1.0, 0.3, 0.4, 1.0), 0.3)
	tween.set_loops(3)
	
	# Play victory sound
	_play_victory_sound()
	
	# Show victory message after delay
	await get_tree().create_timer(2.0).timeout
	_show_victory_screen()

func _play_victory_sound() -> void:
	var player := AudioStreamPlayer.new()
	get_tree().current_scene.add_child(player)
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 1.0
	player.stream = gen
	player.volume_db = -8.0
	player.play()
	
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback:
		var frames := int(gen.mix_rate * 1.0)
		var phase := 0.0
		for i in range(frames):
			var t := float(i) / frames
			# Rising victory chord
			var freq1 := 440.0 + (t * 220.0)
			var freq2 := 550.0 + (t * 275.0)
			var freq3 := 660.0 + (t * 330.0)
			phase += (freq1 + freq2 + freq3) / (3.0 * gen.mix_rate)
			var sample := sin(phase * TAU) * 0.3 * (1.0 - t * 0.5)
			playback.push_frame(Vector2(sample, sample))
	
	await get_tree().create_timer(1.1).timeout
	player.queue_free()

func _show_victory_screen() -> void:
	# Create fullscreen victory overlay
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0)
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 200
	get_tree().current_scene.get_node("CanvasLayer").add_child(overlay)
	
	# Fade in
	var tween := create_tween()
	tween.tween_property(overlay, "color:a", 0.85, 0.5)
	
	# Victory text
	var victory_label := Label.new()
	victory_label.text = "VICTORY\n\nYou collected all hearts.\nThe dungeon yields."
	victory_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	victory_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	victory_label.anchor_right = 1.0
	victory_label.anchor_bottom = 1.0
	victory_label.add_theme_color_override(&"font_color", Color(1.0, 0.8, 0.2, 1.0))
	victory_label.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	victory_label.add_theme_constant_override(&"outline_size", 4)
	victory_label.add_theme_font_size_override(&"font_size", 32)
	overlay.add_child(victory_label)