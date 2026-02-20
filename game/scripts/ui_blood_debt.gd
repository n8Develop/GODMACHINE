extends Control
class_name UIBloodDebt

@export var debt_increase_per_resurrection: int = 10
@export var pulse_speed: float = 1.2
@export var warning_threshold: int = 50

var _current_debt: int = 0
var _pulse_timer: float = 0.0
var _debt_bar: ColorRect = null
var _debt_label: Label = null
var _warning_glow: ColorRect = null

func _ready() -> void:
	# Full-screen overlay, non-interactive
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 5  # Below death weight but above gameplay
	
	_load_debt()
	_create_debt_display()
	
	# Connect to player death
	var player := _get_player()
	if player:
		var health := player.get_node_or_null("HealthComponent")
		if health and health.has_signal(&"died"):
			health.died.connect(_on_player_died)

func _create_debt_display() -> void:
	# Bottom-left corner display
	var container := Control.new()
	container.position = Vector2(20, 420)
	container.size = Vector2(200, 40)
	add_child(container)
	
	# Warning glow (only visible when debt is high)
	_warning_glow = ColorRect.new()
	_warning_glow.size = Vector2(220, 60)
	_warning_glow.position = Vector2(-10, -10)
	_warning_glow.color = Color(0.8, 0.1, 0.1, 0.0)
	_warning_glow.z_index = -1
	container.add_child(_warning_glow)
	
	# Background
	var bg := ColorRect.new()
	bg.size = Vector2(200, 40)
	bg.color = Color(0.08, 0.02, 0.02, 0.85)
	container.add_child(bg)
	
	# Debt bar (fills based on debt)
	_debt_bar = ColorRect.new()
	_debt_bar.position = Vector2(5, 5)
	_debt_bar.size = Vector2(0, 30)
	_debt_bar.color = Color(0.7, 0.05, 0.1, 0.9)
	container.add_child(_debt_bar)
	
	# Label
	_debt_label = Label.new()
	_debt_label.position = Vector2(10, 8)
	_debt_label.add_theme_color_override(&"font_color", Color(0.9, 0.85, 0.8, 1.0))
	_debt_label.add_theme_font_size_override(&"font_size", 14)
	container.add_child(_debt_label)
	
	_update_display()

func _process(delta: float) -> void:
	_pulse_timer += delta * pulse_speed
	
	# Pulse the debt bar
	if _debt_bar and _current_debt > 0:
		var pulse := 0.85 + (sin(_pulse_timer * TAU) * 0.15)
		_debt_bar.modulate = Color(pulse, pulse * 0.3, pulse * 0.3, 1.0)
	
	# Warning glow when debt is high
	if _warning_glow and _current_debt >= warning_threshold:
		var glow_intensity := 0.15 + (sin(_pulse_timer * TAU * 2.0) * 0.1)
		_warning_glow.color.a = glow_intensity

func _get_player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D

func _on_player_died() -> void:
	_current_debt += debt_increase_per_resurrection
	_save_debt()
	_update_display()
	_play_debt_sound()
	
	# Flash the display
	if _debt_bar:
		var tween := create_tween()
		tween.tween_property(_debt_bar, "modulate", Color(2.0, 0.5, 0.5, 1.0), 0.2)
		tween.tween_property(_debt_bar, "modulate", Color(1.0, 0.3, 0.3, 1.0), 0.3)

func _update_display() -> void:
	if not _debt_label or not _debt_bar:
		return
	
	_debt_label.text = "BLOOD DEBT: %d" % _current_debt
	
	# Bar grows with debt (capped visually at 100)
	var visual_debt := mini(_current_debt, 100)
	var bar_width := (visual_debt / 100.0) * 190.0
	_debt_bar.size.x = bar_width
	
	# Color shifts from dark red to bright crimson as debt grows
	var debt_ratio := clampf(float(_current_debt) / 100.0, 0.0, 1.0)
	_debt_bar.color = Color(
		0.5 + (debt_ratio * 0.5),
		0.05,
		0.1,
		0.9
	)

func _load_debt() -> void:
	if not FileAccess.file_exists("user://blood_debt.save"):
		return
	
	var file := FileAccess.open("user://blood_debt.save", FileAccess.READ)
	if file:
		_current_debt = file.get_32()
		file.close()

func _save_debt() -> void:
	var file := FileAccess.open("user://blood_debt.save", FileAccess.WRITE)
	if file:
		file.store_32(_current_debt)
		file.close()

func _play_debt_sound() -> void:
	var player := AudioStreamPlayer.new()
	get_tree().current_scene.add_child(player)
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.5
	player.stream = gen
	player.volume_db = -14.0
	player.play()
	
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback:
		var frames := int(gen.mix_rate * 0.5)
		var phase := 0.0
		for i in range(frames):
			var t := float(i) / frames
			# Low, ominous toll
			var freq := 120.0 - (t * 40.0)
			phase += freq / gen.mix_rate
			var sample := sin(phase * TAU) * 0.4 * (1.0 - t * 0.6)
			playback.push_frame(Vector2(sample, sample))
	
	await get_tree().create_timer(0.55).timeout
	player.queue_free()

func get_current_debt() -> int:
	return _current_debt

func _exit_tree() -> void:
	_save_debt()