extends Node
class_name HealthComponent

signal health_changed(new_health: int)
signal max_health_changed(new_max: int)
signal died

@export var max_health: int = 100
@export var current_health: int = max_health

func _ready() -> void:
	current_health = max_health
	health_changed.emit(current_health)

func take_damage(amount: int) -> void:
	if current_health <= 0:
		return  # Already dead, ignore further damage
	
	current_health = maxi(0, current_health - amount)
	health_changed.emit(current_health)
	
	# Visual feedback
	if get_parent() is Node2D:
		_flash_white()
	
	# Play hit sound
	_play_hit_sound()
	
	if current_health <= 0:
		died.emit()

func heal(amount: int) -> void:
	if current_health <= 0:
		return  # Dead entities can't heal
	
	current_health = mini(max_health, current_health + amount)
	health_changed.emit(current_health)

func set_max_health(new_max: int) -> void:
	max_health = new_max
	current_health = mini(current_health, max_health)
	max_health_changed.emit(max_health)
	health_changed.emit(current_health)

func _flash_white() -> void:
	var parent := get_parent()
	if not parent:
		return
	
	# Find all ColorRect children
	for child in parent.get_children():
		if child is ColorRect:
			var original_modulate := child.modulate
			child.modulate = Color(2.0, 2.0, 2.0, 1.0)
			
			var timer := get_tree().create_timer(0.1)
			timer.timeout.connect(func() -> void:
				if is_instance_valid(child):
					child.modulate = original_modulate
			)

func _play_hit_sound() -> void:
	var player := AudioStreamPlayer.new()
	get_tree().current_scene.add_child(player)
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.1
	player.stream = gen
	player.volume_db = -12.0
	
	player.play()
	
	# Generate square wave beep
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback:
		var frames := int(gen.mix_rate * 0.08)
		var phase := 0.0
		for i in range(frames):
			phase += 440.0 / gen.mix_rate
			var sample := 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
			sample *= 0.15
			playback.push_frame(Vector2(sample, sample))
	
	await get_tree().create_timer(0.15).timeout
	player.queue_free()