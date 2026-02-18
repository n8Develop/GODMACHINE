extends Node
class_name HealthComponent

signal health_changed(new_hp: int)
signal max_health_changed(new_max: int)
signal died

@export var max_health: int = 100
@export var current_health: int = 100

var _hit_flash_timer: float = 0.0
var _blood_drop_timer: float = 0.0

func _ready() -> void:
	current_health = max_health
	health_changed.emit(current_health)

func _physics_process(delta: float) -> void:
	if _hit_flash_timer > 0.0:
		_hit_flash_timer -= delta
		if _hit_flash_timer <= 0.0:
			var parent := get_parent()
			if parent is Node2D:
				parent.modulate = Color.WHITE
	
	# Bleed drops when wounded
	if current_health < max_health and current_health > 0:
		_blood_drop_timer += delta
		if _blood_drop_timer >= 0.8:
			_blood_drop_timer = 0.0
			_spawn_blood_drop()

func take_damage(amount: int) -> void:
	if current_health <= 0:
		return
	
	current_health = max(0, current_health - amount)
	health_changed.emit(current_health)
	
	var parent := get_parent()
	if parent is Node2D:
		parent.modulate = Color.WHITE * 2.0
		_hit_flash_timer = 0.1
	
	_play_hit_sound()
	
	if current_health <= 0:
		died.emit()
		_spawn_death_stain()

func heal(amount: int) -> void:
	if current_health <= 0:
		return
	
	current_health = min(max_health, current_health + amount)
	health_changed.emit(current_health)

func _play_hit_sound() -> void:
	var player := AudioStreamPlayer.new()
	get_tree().current_scene.add_child(player)
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.1
	player.stream = gen
	player.volume_db = -15.0
	player.play()
	
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback:
		var frames := int(gen.mix_rate * 0.1)
		var phase := 0.0
		for i in range(frames):
			var t := float(i) / frames
			var freq := 400.0 - (t * 300.0)
			phase += freq / gen.mix_rate
			var sample := sin(phase * TAU) * 0.2 * (1.0 - t)
			playback.push_frame(Vector2(sample, sample))
	
	await get_tree().create_timer(0.15).timeout
	player.queue_free()

func _spawn_blood_drop() -> void:
	var parent := get_parent()
	if not parent is Node2D:
		return
	
	var room := parent.get_parent()
	if not room:
		return
	
	var drop := ColorRect.new()
	drop.size = Vector2(3, 3)
	drop.position = parent.global_position + Vector2(randf_range(-8, 8), randf_range(-8, 8))
	drop.color = Color(0.4, 0.05, 0.05, 0.7)
	drop.z_index = -3
	room.add_child(drop)
	
	var tween := create_tween()
	tween.tween_property(drop, "modulate:a", 0.0, 2.0)
	tween.finished.connect(drop.queue_free)

func _spawn_death_stain() -> void:
	var parent := get_parent()
	if not parent is Node2D:
		return
	
	var room := parent.get_parent()
	if not room:
		return
	
	# Create permanent blood stain at death location
	var stain := ColorRect.new()
	stain.size = Vector2(randf_range(20, 32), randf_range(16, 24))
	stain.position = parent.global_position - stain.size / 2.0
	stain.color = Color(0.3, 0.05, 0.05, 0.4)
	stain.rotation = randf_range(0, TAU)
	stain.z_index = -4
	room.add_child(stain)
	
	# Add a few smaller splatters around it
	for i in range(randi_range(3, 6)):
		var splatter := ColorRect.new()
		splatter.size = Vector2(randf_range(4, 8), randf_range(4, 8))
		var offset := Vector2(randf_range(-24, 24), randf_range(-24, 24))
		splatter.position = parent.global_position + offset - splatter.size / 2.0
		splatter.color = Color(0.35, 0.06, 0.06, 0.3)
		splatter.rotation = randf_range(0, TAU)
		splatter.z_index = -4
		room.add_child(splatter)