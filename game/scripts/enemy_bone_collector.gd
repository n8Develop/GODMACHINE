extends CharacterBody2D

@export var shuffle_speed: float = 25.0
@export var collection_range: float = 80.0
@export var bones_needed: int = 3
@export var empowered_speed: float = 85.0
@export var empowered_damage: int = 28

var _bones_collected: int = 0
var _is_empowered: bool = false
var _collection_timer: float = 0.0
var _shuffle_timer: float = 0.0
var _wander_direction: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group("enemies")
	_shuffle_timer = randf_range(1.5, 3.0)
	_wander_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	
	# Visual
	var body := ColorRect.new()
	body.size = Vector2(28, 24)
	body.position = Vector2(-14, -12)
	body.color = Color(0.55, 0.5, 0.45, 1.0)
	add_child(body)
	
	# Bone sack visual
	var sack := ColorRect.new()
	sack.name = "BoneSack"
	sack.size = Vector2(16, 12)
	sack.position = Vector2(-8, -6)
	sack.color = Color(0.35, 0.3, 0.25, 0.6)
	add_child(sack)
	
	# Collision
	var shape := RectangleShape2D.new()
	shape.size = Vector2(28, 24)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	
	# Health
	var health := get_node_or_null("HealthComponent")
	if health:
		health.died.connect(_on_died)
	
	# Shuffle sound
	_create_shuffle_audio()

func _create_shuffle_audio() -> void:
	var audio := AudioStreamPlayer.new()
	audio.name = "ShuffleAudio"
	audio.volume_db = -22.0
	add_child(audio)
	
	call_deferred("_generate_shuffle_loop", audio)

func _generate_shuffle_loop(player: AudioStreamPlayer) -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.8
	player.stream = gen
	player.play()
	
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback:
		var frames := int(gen.mix_rate * 0.8)
		var phase := randf() * TAU
		for i in range(frames):
			var t := float(i) / frames
			var noise := (randf() - 0.5) * 0.08  # Bone rattle
			var sample := noise * sin(t * 20.0)  # Irregular rhythm
			playback.push_frame(Vector2(sample, sample))

func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	_collection_timer -= delta
	_shuffle_timer -= delta
	
	# Search for corpses (blood stains) to collect
	if not _is_empowered and _collection_timer <= 0.0:
		_search_for_bones()
		_collection_timer = 1.0
	
	# Movement
	if _shuffle_timer <= 0.0:
		_wander_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		_shuffle_timer = randf_range(1.5, 3.5)
	
	var speed := shuffle_speed if not _is_empowered else empowered_speed
	velocity = _wander_direction * speed
	
	# If empowered, chase player
	if _is_empowered:
		var to_player := global_position.direction_to(player.global_position)
		velocity = to_player * empowered_speed
		
		# Attack if close enough
		var distance := global_position.distance_to(player.global_position)
		if distance < 40.0:
			_perform_attack(player)
	
	move_and_slide()

func _search_for_bones() -> void:
	var blood_stains := get_tree().get_nodes_in_group("blood_stain")
	if blood_stains.is_empty():
		return
	
	# Find nearest bone pile
	var nearest: Node2D = null
	var nearest_dist := INF
	
	for stain in blood_stains:
		if not is_instance_valid(stain) or not stain is Node2D:
			continue
		var dist := global_position.distance_to(stain.global_position)
		if dist < nearest_dist and dist < collection_range:
			nearest = stain
			nearest_dist = dist
	
	if nearest and nearest_dist < 25.0:  # Close enough to collect
		_collect_bones(nearest)

func _collect_bones(bone_node: Node2D) -> void:
	_bones_collected += 1
	bone_node.queue_free()
	
	_spawn_collection_text()
	_play_collect_sound()
	
	# Update visual size
	var sack := get_node_or_null("BoneSack")
	if sack:
		var scale_factor := 1.0 + (_bones_collected * 0.15)
		sack.scale = Vector2(scale_factor, scale_factor)
	
	# Check if empowered
	if _bones_collected >= bones_needed and not _is_empowered:
		_become_empowered()

func _become_empowered() -> void:
	_is_empowered = true
	
	# Visual change - darker, larger
	var body := get_child(0) as ColorRect
	if body:
		body.color = Color(0.25, 0.2, 0.15, 1.0)
		body.size = Vector2(36, 32)
		body.position = Vector2(-18, -16)
	
	_spawn_empower_text()
	_play_empower_sound()
	
	# Update health if component exists
	var health := get_node_or_null("HealthComponent")
	if health:
		health.max_health = int(health.max_health * 1.5)
		health.current_health = health.max_health

func _perform_attack(player: Node2D) -> void:
	var health := player.get_node_or_null("HealthComponent")
	if health:
		var damage := empowered_damage if _is_empowered else 12
		health.take_damage(damage)
		_spawn_damage_number(player.global_position, damage)
		_flash_attack()

func _flash_attack() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1.5, 1.2, 1.0, 1.0), 0.1)
	tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.1)

func _spawn_collection_text() -> void:
	var label := Label.new()
	label.text = "GATHERED"
	label.add_theme_color_override(&"font_color", Color(0.8, 0.7, 0.6, 1.0))
	label.add_theme_font_size_override(&"font_size", 12)
	label.position = global_position + Vector2(-20, -40)
	label.z_index = 100
	get_tree().current_scene.add_child(label)
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 30, 1.2)
	tween.tween_property(label, "modulate:a", 0.0, 1.2)
	tween.finished.connect(label.queue_free)

func _spawn_empower_text() -> void:
	var label := Label.new()
	label.text = "EMPOWERED"
	label.add_theme_color_override(&"font_color", Color(1.0, 0.3, 0.2, 1.0))
	label.add_theme_font_size_override(&"font_size", 16)
	label.position = global_position + Vector2(-35, -50)
	label.z_index = 100
	get_tree().current_scene.add_child(label)
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 40, 1.5)
	tween.tween_property(label, "modulate:a", 0.0, 1.5)
	tween.finished.connect(label.queue_free)

func _spawn_damage_number(pos: Vector2, damage: int) -> void:
	var label := Label.new()
	label.text = str(damage)
	label.add_theme_color_override(&"font_color", Color(1.0, 0.3, 0.3, 1.0))
	label.add_theme_font_size_override(&"font_size", 18)
	label.position = pos + Vector2(-10, -30)
	label.z_index = 100
	get_tree().current_scene.add_child(label)
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", pos.y - 60, 0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.8)
	tween.finished.connect(label.queue_free)

func _play_collect_sound() -> void:
	var player := AudioStreamPlayer.new()
	get_tree().current_scene.add_child(player)
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.25
	player.stream = gen
	player.volume_db = -14.0
	player.play()
	
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback:
		var frames := int(gen.mix_rate * 0.25)
		var phase := 0.0
		for i in range(frames):
			var t := float(i) / frames
			# Bone rattle - multiple frequencies
			var freq := 400.0 + sin(t * 30.0) * 150.0
			phase += freq / gen.mix_rate
			var sample := sin(phase * TAU) * 0.25 * (1.0 - t)
			playback.push_frame(Vector2(sample, sample))
	
	await get_tree().create_timer(0.3).timeout
	player.queue_free()

func _play_empower_sound() -> void:
	var player := AudioStreamPlayer.new()
	get_tree().current_scene.add_child(player)
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.6
	player.stream = gen
	player.volume_db = -10.0
	player.play()
	
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback:
		var frames := int(gen.mix_rate * 0.6)
		var phase := 0.0
		for i in range(frames):
			var t := float(i) / frames
			# Deep rumble rising
			var freq := 80.0 + (t * 200.0)
			phase += freq / gen.mix_rate
			var sample := sin(phase * TAU) * 0.35 * (1.0 - t * 0.3)
			playback.push_frame(Vector2(sample, sample))
	
	await get_tree().create_timer(0.65).timeout
	player.queue_free()

func _on_died() -> void:
	# Drop bones if empowered
	if _is_empowered:
		for i in range(_bones_collected):
			_spawn_bone_drop(i)
	
	queue_free()

func _spawn_bone_drop(index: int) -> void:
	var bone := ColorRect.new()
	bone.size = Vector2(8, 8)
	bone.color = Color(0.9, 0.85, 0.75, 1.0)
	bone.position = global_position + Vector2(randf_range(-20, 20), randf_range(-20, 20))
	bone.z_index = -3
	get_tree().current_scene.add_child(bone)
	
	# Bones don't fade - they become collectible again
	bone.add_to_group("blood_stain")