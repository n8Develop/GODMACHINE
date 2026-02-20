extends CharacterBody2D

@export var crawl_speed: float = 30.0
@export var corpse_spawn_chance: float = 0.3
@export var spawn_on_death: bool = true
@export var max_spawns: int = 2

var _spawn_count: int = 0
var _birth_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group("enemies")
	_birth_position = global_position
	
	# Create worm-like visual
	var segment_count := 4
	for i in range(segment_count):
		var segment := ColorRect.new()
		segment.size = Vector2(12 - i * 2, 10 - i * 2)
		segment.position = Vector2(-(12 - i * 2) / 2.0, -(10 - i * 2) / 2.0 + i * 8.0)
		var darkness := float(i) / segment_count * 0.3
		segment.color = Color(0.4 - darkness, 0.3 - darkness, 0.2 - darkness, 1.0)
		add_child(segment)
	
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(12, 32)
	collision.shape = shape
	add_child(collision)
	
	var health := get_node_or_null("HealthComponent")
	if health:
		health.died.connect(_on_died)
	
	# Quiet skittering sound
	_create_skitter_audio()

func _create_skitter_audio() -> void:
	var player := AudioStreamPlayer.new()
	player.name = "SkitterAudio"
	add_child(player)
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.15
	player.stream = gen
	player.volume_db = -28.0
	player.autoplay = true
	
	call_deferred("_generate_skitter_loop", player)

func _generate_skitter_loop(player: AudioStreamPlayer) -> void:
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if not playback:
		return
	
	var frames := int(22050.0 * 0.15)
	for i in range(frames):
		var t := float(i) / frames
		# Dry clicking noise
		var click := sin(t * TAU * 12.0) * (randf() * 0.4)
		var sample := click * 0.15
		playback.push_frame(Vector2(sample, sample))

func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if not player:
		return
	
	# Crawlers prefer corpses over players
	var best_target := _find_nearest_corpse()
	if best_target == Vector2.ZERO:
		best_target = player.global_position
	
	var direction := global_position.direction_to(best_target)
	velocity = direction * crawl_speed
	
	# Undulating motion
	var wave := sin(Time.get_ticks_msec() * 0.008) * 15.0
	velocity.x += wave * delta * 60.0
	
	move_and_slide()

func _find_nearest_corpse() -> Vector2:
	var blood_stains := get_tree().get_nodes_in_group("blood_stain")
	if blood_stains.is_empty():
		return Vector2.ZERO
	
	var nearest_pos := Vector2.ZERO
	var nearest_dist := 999999.0
	
	for stain in blood_stains:
		if stain is Node2D:
			var dist := global_position.distance_to(stain.global_position)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest_pos = stain.global_position
	
	# Only pursue if close enough
	if nearest_dist < 200.0:
		return nearest_pos
	return Vector2.ZERO

func _on_died() -> void:
	# Spawn smaller crawlers on death if spawning enabled
	if spawn_on_death and _spawn_count < max_spawns and randf() < corpse_spawn_chance:
		_spawn_offspring()
	
	# Small dust puff
	for i in range(6):
		var particle := ColorRect.new()
		particle.size = Vector2(3, 3)
		particle.position = global_position + Vector2(-1.5, -1.5)
		particle.color = Color(0.3, 0.25, 0.2, 0.8)
		particle.z_index = 50
		get_tree().current_scene.add_child(particle)
		
		var angle := (TAU / 6.0) * i
		var offset := Vector2(cos(angle), sin(angle)) * 25.0
		
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "position", global_position + offset, 0.4)
		tween.tween_property(particle, "modulate:a", 0.0, 0.4)
		tween.finished.connect(particle.queue_free)

func _spawn_offspring() -> void:
	var offspring_scene := load("res://scenes/enemy_corpse_crawler.tscn") as PackedScene
	if not offspring_scene:
		return
	
	for i in range(2):
		var offspring := offspring_scene.instantiate() as CharacterBody2D
		if not offspring:
			continue
		
		# Position near death site with small offset
		var offset := Vector2(randf_range(-30, 30), randf_range(-30, 30))
		offspring.global_position = global_position + offset
		
		# Mark as offspring to prevent infinite spawning
		offspring.spawn_on_death = false
		offspring._spawn_count = _spawn_count + 1
		
		# Smaller and weaker
		offspring.scale = Vector2(0.7, 0.7)
		var health := offspring.get_node_or_null("HealthComponent")
		if health:
			health.max_health = int(health.max_health * 0.6)
			health.current_health = health.max_health
		
		get_tree().current_scene.add_child(offspring)
	
	_spawn_split_text()

func _spawn_split_text() -> void:
	var label := Label.new()
	label.text = "SPLIT"
	label.add_theme_color_override(&"font_color", Color(0.6, 0.4, 0.3, 1.0))
	label.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	label.add_theme_constant_override(&"outline_size", 2)
	label.add_theme_font_size_override(&"font_size", 14)
	label.position = global_position + Vector2(-20, -40)
	label.z_index = 100
	get_tree().current_scene.add_child(label)
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", global_position.y - 70, 0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.8)
	tween.finished.connect(label.queue_free)