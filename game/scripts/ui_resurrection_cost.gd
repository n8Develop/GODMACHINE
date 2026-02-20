extends Control
class_name UIResurrectionCost

@export var fade_speed: float = 0.12
@export var cost_increase_per_death: float = 0.08

var _cost_overlay: ColorRect = null
var _current_alpha: float = 0.0
var _death_count: int = 0

func _ready() -> void:
	# Create persistent overlay that accumulates with each death
	_cost_overlay = ColorRect.new()
	_cost_overlay.color = Color(0.15, 0.05, 0.05, 0.0)
	_cost_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cost_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_cost_overlay)
	
	# Load death count
	_load_death_count()
	_update_cost()
	
	# Connect to player death
	await get_tree().process_frame
	var player := _get_player()
	if player:
		var health_comp := player.get_node_or_null("HealthComponent")
		if health_comp and health_comp.has_signal(&"died"):
			health_comp.died.connect(_on_player_died)

func _get_player() -> Node2D:
	var main := get_tree().current_scene
	if not main:
		return null
	return main.get_node_or_null("Player") as Node2D

func _load_death_count() -> void:
	var main := get_tree().current_scene
	if main:
		_death_count = main.get_meta("death_count", 0)

func _on_player_died() -> void:
	_death_count += 1
	_update_cost()
	_play_cost_sound()

func _update_cost() -> void:
	# Each death increases the permanent darkness
	_current_alpha = min(_death_count * cost_increase_per_death, 0.6)
	if _cost_overlay:
		_cost_overlay.color.a = _current_alpha

func _process(delta: float) -> void:
	# Gentle pulse to make the cost feel alive
	if _cost_overlay and _current_alpha > 0.0:
		var pulse := sin(Time.get_ticks_msec() * 0.001) * 0.02
		_cost_overlay.color.a = _current_alpha + pulse

func _play_cost_sound() -> void:
	var player := AudioStreamPlayer.new()
	get_tree().current_scene.add_child(player)
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 1.2
	player.stream = gen
	player.volume_db = -18.0
	player.play()
	
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback:
		var frames := int(gen.mix_rate * 1.2)
		var phase := randf() * TAU
		for i in range(frames):
			var t := float(i) / frames
			# Deep, grinding toll — the price of resurrection
			var freq := 80.0 - (t * 30.0)
			phase += freq / gen.mix_rate
			var sample := sin(phase * TAU) * 0.2 * (1.0 - t * 0.6)
			# Add harmonic for weight
			var harmonic := sin(phase * TAU * 2.0) * 0.1 * (1.0 - t)
			var final := sample + harmonic
			playback.push_frame(Vector2(final, final))
	
	await get_tree().create_timer(1.25).timeout
	player.queue_free()