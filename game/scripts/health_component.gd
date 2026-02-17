extends Node
class_name HealthComponent

signal health_changed(new_hp: int)
signal max_health_changed(new_max_hp: int)
signal died

@export var max_health: int = 100
var current_health: int = 100

func _ready() -> void:
	current_health = max_health
	health_changed.emit(current_health)
	max_health_changed.emit(max_health)

func take_damage(amount: int) -> void:
	current_health = maxi(0, current_health - amount)
	health_changed.emit(current_health)
	
	# Play hit sound (simple beep)
	_play_hit_sound()
	
	# Visual flash (existing)
	var parent := get_parent()
	if parent:
		for child in parent.get_children():
			if child is ColorRect:
				child.modulate = Color(2.0, 2.0, 2.0)
				var flash_timer := 0.1
				await get_tree().create_timer(flash_timer).timeout
				if is_instance_valid(child):
					child.modulate = Color(1.0, 1.0, 1.0)
	
	if current_health <= 0:
		_spawn_death_particles()
		died.emit()

func heal(amount: int) -> void:
	current_health = mini(max_health, current_health + amount)
	health_changed.emit(current_health)

func _spawn_death_particles() -> void:
	var parent := get_parent()
	if not parent or not parent is Node2D:
		return
	
	var origin := (parent as Node2D).global_position
	for i in range(8):
		var particle := ColorRect.new()
		particle.size = Vector2(4, 4)
		particle.color = Color(0.9, 0.1, 0.1, 1.0)
		particle.position = origin + Vector2(-2, -2)
		particle.z_index = 100
		get_tree().current_scene.add_child(particle)
		
		var angle := (i / 8.0) * TAU
		var velocity := Vector2(cos(angle), sin(angle)) * 120.0
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "position", origin + velocity * 0.5, 0.4)
		tween.tween_property(particle, "modulate:a", 0.0, 0.4)
		tween.finished.connect(particle.queue_free)

func _play_hit_sound() -> void:
	# Create simple procedural hit sound
	var player := AudioStreamPlayer.new()
	get_tree().current_scene.add_child(player)
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.1
	player.stream = gen
	player.volume_db = -8.0
	
	player.play()
	
	# Generate square wave beep
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback:
		var frames := int(gen.mix_rate * 0.1)
		var freq := 440.0
		var phase := 0.0
		for i in range(frames):
			phase += freq / gen.mix_rate
			var sample := 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
			sample *= 0.3 * (1.0 - float(i) / frames)  # Fade out
			playback.push_frame(Vector2(sample, sample))
	
	# Auto-cleanup
	await get_tree().create_timer(0.15).timeout
	player.queue_free()