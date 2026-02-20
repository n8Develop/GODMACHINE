extends Node
class_name SalvationTracker

const CRITICAL_HP_THRESHOLD := 0.25  # Below 25% health
const SalvationShrine := preload("res://scripts/salvation_shrine.gd")

func _ready() -> void:
	# Connect to all healing events
	_monitor_player_healing()

func _monitor_player_healing() -> void:
	var timer := Timer.new()
	timer.wait_time = 0.2
	timer.autostart = true
	timer.timeout.connect(_check_healing_events)
	add_child(timer)

var _last_hp: int = 100

func _check_healing_events() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not player or not is_instance_valid(player):
		return
	
	var health_comp := player.get_node_or_null("HealthComponent")
	if not health_comp:
		return
	
	var current_hp: int = health_comp.current_health
	var max_hp: int = health_comp.max_health
	var hp_percent := float(current_hp) / float(max_hp)
	
	# Detect healing while critical
	if current_hp > _last_hp:
		var was_critical := (float(_last_hp) / float(max_hp)) < CRITICAL_HP_THRESHOLD
		if was_critical and hp_percent > CRITICAL_HP_THRESHOLD:
			_spawn_salvation_shrine(player.global_position)
	
	_last_hp = current_hp

func _spawn_salvation_shrine(pos: Vector2) -> void:
	var shrine := Node2D.new()
	var script := SalvationShrine.new()
	shrine.set_script(load("res://scripts/salvation_shrine.gd"))
	shrine.global_position = pos
	
	# Add to current scene (not as player child)
	var main := get_tree().current_scene
	if main:
		main.add_child(shrine)
		_play_spawn_sound()

func _play_spawn_sound() -> void:
	var player := AudioStreamPlayer.new()
	get_tree().current_scene.add_child(player)
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.5
	player.stream = gen
	player.volume_db = -18.0
	player.play()
	
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback:
		var frames := int(gen.mix_rate * 0.5)
		var phase := 0.0
		for i in range(frames):
			var t := float(i) / frames
			var freq := 440.0 + (t * 220.0)  # Rising tone
			phase += freq / gen.mix_rate
			var sample := sin(phase * TAU) * 0.15 * (1.0 - t * 0.6)
			playback.push_frame(Vector2(sample, sample))
	
	await get_tree().create_timer(0.55).timeout
	player.queue_free()