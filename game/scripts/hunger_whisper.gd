extends Node
class_name HungerWhisper

@export var check_interval: float = 8.0
@export var no_heal_threshold: float = 25.0  # Seconds without healing

var _check_timer: float = 0.0
var _time_since_last_heal: float = 0.0
var _suppress_until: float = 0.0
var _last_hp: int = 0

const WHISPER_STAGES: Array[String] = [
	"You should rest soon.",
	"Hunger gnaws at the edges.",
	"Your strength is fading.",
	"The dungeon smells weakness.",
	"Starving. Desperate. Dying."
]

func _ready() -> void:
	var player := _get_player()
	if player:
		var health := player.get_node_or_null("HealthComponent")
		if health:
			_last_hp = health.current_health
			if health.has_signal("health_changed"):
				health.health_changed.connect(_on_health_changed)

func _physics_process(delta: float) -> void:
	_check_timer += delta
	_time_since_last_heal += delta
	
	if _check_timer >= check_interval:
		_check_timer = 0.0
		_check_hunger_state()

func _check_hunger_state() -> void:
	var current_time := Time.get_ticks_msec() / 1000.0
	
	# Suppress whispers if recently fed
	if current_time < _suppress_until:
		return
	
	if _time_since_last_heal < no_heal_threshold:
		return
	
	var elapsed: float = _time_since_last_heal - no_heal_threshold
	var stage_index: int = int(elapsed / 15.0)
	stage_index = clampi(stage_index, 0, WHISPER_STAGES.size() - 1)
	
	var whisper_text: String = WHISPER_STAGES[stage_index]
	_spawn_whisper_text(whisper_text)
	_play_whisper_sound(stage_index)

func _on_health_changed(new_hp: int) -> void:
	if new_hp > _last_hp:
		# Healing detected
		_time_since_last_heal = 0.0
	_last_hp = new_hp

func suppress_whispers(duration: float) -> void:
	var current_time := Time.get_ticks_msec() / 1000.0
	_suppress_until = current_time + duration
	_time_since_last_heal = 0.0

func is_whispering() -> bool:
	var current_time := Time.get_ticks_msec() / 1000.0
	if current_time < _suppress_until:
		return false
	return _time_since_last_heal >= no_heal_threshold

func _spawn_whisper_text(whisper_text: String) -> void:
	var main := get_tree().current_scene
	if not main:
		return
	
	var label := Label.new()
	label.text = whisper_text
	label.add_theme_color_override(&"font_color", Color(0.6, 0.5, 0.4, 0.8))
	label.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	label.add_theme_constant_override(&"outline_size", 2)
	label.add_theme_font_size_override(&"font_size", 14)
	label.position = Vector2(320 - 100, 360)
	label.z_index = 80
	main.add_child(label)
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", 340.0, 2.0)
	tween.tween_property(label, "modulate:a", 0.0, 2.0)
	tween.finished.connect(label.queue_free)

func _play_whisper_sound(stage: int) -> void:
	var player := AudioStreamPlayer.new()
	get_tree().current_scene.add_child(player)
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 1.0
	player.stream = gen
	player.volume_db = -20.0 + (stage * 2.0)  # Gets louder as urgency increases
	player.play()
	
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback:
		var frames := int(gen.mix_rate * 1.0)
		var phase := 0.0
		for i in range(frames):
			var t := float(i) / frames
			var freq := 80.0 + (stage * 20.0)  # Lower and more ominous as hunger worsens
			phase += freq / gen.mix_rate
			var sample := sin(phase * TAU) * 0.15 * (1.0 - t * 0.5)
			playback.push_frame(Vector2(sample, sample))
	
	await get_tree().create_timer(1.1).timeout
	player.queue_free()

func _get_player() -> Node2D:
	var main := get_tree().current_scene
	if main:
		return main.get_node_or_null("Player")
	return null