extends Node
class_name HealthComponent

signal health_changed(new_hp: int)
signal max_health_changed(new_max: int)
signal died

@export var max_health: int = 100
@export var show_health_bar: bool = false

var current_health: int = 0
var _health_bar: ColorRect = null
var _health_bar_bg: ColorRect = null
var _flash_timer: float = 0.0

func _ready() -> void:
	current_health = max_health
	health_changed.emit(current_health)
	max_health_changed.emit(max_health)
	
	if show_health_bar:
		_create_health_bar()

func _process(delta: float) -> void:
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			_restore_color()
	
	if _health_bar and show_health_bar:
		_update_health_bar()

func _create_health_bar() -> void:
	var parent := get_parent()
	if not parent is Node2D:
		return
	
	# Background (black)
	_health_bar_bg = ColorRect.new()
	_health_bar_bg.size = Vector2(32, 4)
	_health_bar_bg.position = Vector2(-16, -24)
	_health_bar_bg.color = Color(0.0, 0.0, 0.0, 0.7)
	_health_bar_bg.z_index = 50
	parent.add_child(_health_bar_bg)
	
	# Foreground (red fill)
	_health_bar = ColorRect.new()
	_health_bar.size = Vector2(32, 4)
	_health_bar.position = Vector2(-16, -24)
	_health_bar.color = Color(0.8, 0.1, 0.1, 1.0)
	_health_bar.z_index = 51
	parent.add_child(_health_bar)

func _update_health_bar() -> void:
	if not _health_bar:
		return
	
	var percent := float(current_health) / float(max_health)
	_health_bar.size.x = 32.0 * percent
	
	# Color based on health
	if percent > 0.6:
		_health_bar.color = Color(0.2, 0.8, 0.2, 1.0)  # Green
	elif percent > 0.3:
		_health_bar.color = Color(0.9, 0.7, 0.1, 1.0)  # Yellow
	else:
		_health_bar.color = Color(0.8, 0.1, 0.1, 1.0)  # Red

func take_damage(amount: int) -> void:
	current_health = max(0, current_health - amount)
	health_changed.emit(current_health)
	
	_trigger_flash()
	_play_hit_sound()
	_spawn_particles()
	
	if current_health <= 0:
		died.emit()
		if _health_bar:
			_health_bar.queue_free()
		if _health_bar_bg:
			_health_bar_bg.queue_free()
		get_parent().queue_free()

func heal(amount: int) -> void:
	current_health = min(max_health, current_health + amount)
	health_changed.emit(current_health)

func _trigger_flash() -> void:
	var parent := get_parent()
	if not parent:
		return
	
	for child in parent.get_children():
		if child is ColorRect:
			child.modulate = Color(2.0, 2.0, 2.0)
	
	_flash_timer = 0.1

func _restore_color() -> void:
	var parent := get_parent()
	if not parent:
		return
	
	for child in parent.get_children():
		if child is ColorRect and child != _health_bar and child != _health_bar_bg:
			child.modulate = Color(1.0, 1.0, 1.0)

func _play_hit_sound() -> void:
	var player := AudioStreamPlayer.new()
	get_tree().current_scene.add_child(player)
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.1
	player.stream = gen
	player.volume_db = -12.0
	
	player.play()
	
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback:
		var frames := int(gen.mix_rate * 0.1)
		for i in range(frames):
			var sample := 1.0 if (i / 10) % 2 == 0 else -1.0
			sample *= 0.2
			playback.push_frame(Vector2(sample, sample))
	
	await get_tree().create_timer(0.15).timeout
	player.queue_free()

func _spawn_particles() -> void:
	var parent := get_parent()
	if not parent or not parent is Node2D:
		return
	
	for i in range(6):
		var particle := ColorRect.new()
		particle.size = Vector2(3, 3)
		particle.color = Color(0.9, 0.1, 0.1, 1.0)
		particle.position = parent.global_position + Vector2(randf_range(-8, 8), randf_range(-8, 8))
		particle.z_index = 100
		get_tree().current_scene.add_child(particle)
		
		var angle := randf() * TAU
		var speed := randf_range(30, 60)
		var dir := Vector2(cos(angle), sin(angle))
		
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "position", particle.position + dir * speed, 0.5)
		tween.tween_property(particle, "modulate:a", 0.0, 0.5)
		tween.finished.connect(particle.queue_free)