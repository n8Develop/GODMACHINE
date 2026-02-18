extends Node2D
class_name BloodTrail

# Tracks player movement and leaves blood drops when wounded
@export var drop_interval: float = 0.4  # Time between drops
@export var hp_threshold: float = 0.5  # Only bleed below 50% HP
@export var drop_size_min: Vector2 = Vector2(3, 3)
@export var drop_size_max: Vector2 = Vector2(7, 7)

var _drop_timer: float = 0.0
var _last_position: Vector2 = Vector2.ZERO
var _min_distance: float = 20.0  # Minimum movement to drop

func _ready() -> void:
	z_index = -4
	_last_position = global_position

func _physics_process(delta: float) -> void:
	var player := get_parent() as Node2D
	if not player or not is_instance_valid(player):
		return
	
	var health_comp := player.get_node_or_null("HealthComponent")
	if not health_comp:
		return
	
	var hp_percent := float(health_comp.current_health) / float(health_comp.max_health)
	
	# Only bleed when wounded and moving
	if hp_percent >= hp_threshold:
		return
	
	var distance_moved := global_position.distance_to(_last_position)
	if distance_moved < _min_distance:
		return
	
	_drop_timer += delta
	if _drop_timer >= drop_interval:
		_drop_timer = 0.0
		_spawn_blood_drop(hp_percent)
		_last_position = global_position

func _spawn_blood_drop(hp_percent: float) -> void:
	var drop := ColorRect.new()
	
	# Size varies with wound severity
	var severity := 1.0 - (hp_percent / hp_threshold)
	var size := lerp(drop_size_min, drop_size_max, severity)
	drop.size = size
	drop.position = global_position - (size * 0.5)
	
	# Color darkens as player dies
	var red := lerp(0.6, 0.9, severity)
	drop.color = Color(red, 0.0, 0.0, 0.4)
	drop.z_index = -4
	
	# Add to room, not player (stays behind)
	var room := get_tree().current_scene.get_node_or_null("CurrentRoom")
	if room:
		room.add_child(drop)
	else:
		get_tree().current_scene.add_child(drop)
	
	# Fade very slowly to permanent stain
	var tween := create_tween()
	tween.tween_property(drop, "modulate:a", 0.15, 8.0)
	
	# Small drip sound
	_play_drip_sound(severity)

func _play_drip_sound(severity: float) -> void:
	var player := AudioStreamPlayer.new()
	get_tree().current_scene.add_child(player)
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.08
	player.stream = gen
	player.volume_db = -28.0
	player.play()
	
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback:
		var frames := int(gen.mix_rate * 0.08)
		var phase := randf() * TAU
		for i in range(frames):
			var t := float(i) / frames
			var freq := 180.0 + (severity * 120.0)
			phase += freq / gen.mix_rate
			var sample := sin(phase * TAU) * 0.15 * (1.0 - t * 0.8)
			playback.push_frame(Vector2(sample, sample))
	
	await get_tree().create_timer(0.1).timeout
	player.queue_free()