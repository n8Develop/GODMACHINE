extends CharacterBody2D

@export var crawl_speed: float = 45.0
@export var latch_range: float = 30.0
@export var drain_damage: int = 3
@export var drain_interval: float = 0.8
@export var blood_detection_range: float = 200.0
@export var engorged_threshold: int = 30  # HP drained before detaching

var _target_player: Node2D = null
var _is_latched: bool = false
var _latch_timer: float = 0.0
var _blood_drained: int = 0
var _pulse_phase: float = 0.0

@onready var _body_rect: ColorRect = $BodyRect
@onready var health: Node = $HealthComponent

func _ready() -> void:
	add_to_group("enemies")
	if health:
		health.died.connect(_on_died)
	_pulse_phase = randf() * TAU

func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if not player or not is_instance_valid(player):
		return
	
	var distance := global_position.distance_to(player.global_position)
	
	# Visual pulse when detecting blood
	var blood_trail := get_tree().get_first_node_in_group("blood_trail")
	var player_is_bleeding := false
	if blood_trail and blood_trail.has_method("is_bleeding"):
		player_is_bleeding = blood_trail.is_bleeding()
	
	if player_is_bleeding and distance < blood_detection_range:
		_pulse_phase += delta * 4.0
		var pulse := (sin(_pulse_phase) * 0.5 + 0.5) * 0.3
		_body_rect.color = Color(0.8 + pulse, 0.1, 0.1, 1.0)
	else:
		_body_rect.color = Color(0.6, 0.15, 0.15, 1.0)
	
	if _is_latched:
		# Attached to player — drain and grow
		global_position = player.global_position + Vector2(randf_range(-8, 8), randf_range(-12, -20))
		
		_latch_timer += delta
		if _latch_timer >= drain_interval:
			_latch_timer = 0.0
			_drain_blood(player)
		
		# Visual feedback: grow as it feeds
		var scale_mult := 1.0 + (_blood_drained / float(engorged_threshold)) * 0.5
		_body_rect.size = Vector2(12, 8) * scale_mult
		_body_rect.position = -_body_rect.size * 0.5
		
		# Detach when engorged
		if _blood_drained >= engorged_threshold:
			_detach()
	else:
		# Crawl toward player
		if distance > latch_range:
			var direction := global_position.direction_to(player.global_position)
			velocity = direction * crawl_speed
			move_and_slide()
		else:
			# Latch onto player
			_latch_onto(player)

func _latch_onto(player: Node2D) -> void:
	_is_latched = true
	_target_player = player
	_latch_timer = 0.0
	velocity = Vector2.ZERO
	_play_latch_sound()
	_spawn_latch_text()

func _drain_blood(player: Node2D) -> void:
	var health_comp := player.get_node_or_null("HealthComponent")
	if health_comp and health_comp.has_method("take_damage"):
		health_comp.take_damage(drain_damage)
		_blood_drained += drain_damage
		_spawn_drain_number(player.global_position)
		_play_drain_sound()

func _detach() -> void:
	_is_latched = false
	_target_player = null
	_blood_drained = 0
	
	# Flee after feeding
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		var flee_dir := global_position.direction_to(player.global_position) * -1.0
		velocity = flee_dir * crawl_speed * 1.5
	
	_spawn_detach_text()

func _spawn_latch_text() -> void:
	var label := Label.new()
	label.text = "LATCHED"
	label.add_theme_color_override(&"font_color", Color(0.9, 0.2, 0.2, 1.0))
	label.add_theme_font_size_override(&"font_size", 12)
	label.position = global_position + Vector2(-20, -40)
	label.z_index = 100
	get_tree().current_scene.add_child(label)
	
	var tween := create_tween()
	tween.tween_property(label, "modulate:a", 0.0, 0.8)
	tween.finished.connect(label.queue_free)

func _spawn_detach_text() -> void:
	var label := Label.new()
	label.text = "ENGORGED"
	label.add_theme_color_override(&"font_color", Color(0.8, 0.3, 0.1, 1.0))
	label.add_theme_font_size_override(&"font_size", 12)
	label.position = global_position + Vector2(-25, -40)
	label.z_index = 100
	get_tree().current_scene.add_child(label)
	
	var tween := create_tween()
	tween.tween_property(label, "modulate:a", 0.0, 0.8)
	tween.finished.connect(label.queue_free)

func _spawn_drain_number(pos: Vector2) -> void:
	var label := Label.new()
	label.text = "-" + str(drain_damage)
	label.add_theme_color_override(&"font_color", Color(0.9, 0.1, 0.1, 1.0))
	label.add_theme_font_size_override(&"font_size", 10)
	label.position = pos + Vector2(-8, -25)
	label.z_index = 100
	get_tree().current_scene.add_child(label)
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", pos.y - 40, 0.5)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.finished.connect(label.queue_free)

func _play_latch_sound() -> void:
	var player := AudioStreamPlayer.new()
	get_tree().current_scene.add_child(player)
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.25
	player.stream = gen
	player.volume_db = -18.0
	player.play()
	
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback:
		var frames := int(gen.mix_rate * 0.25)
		var phase := 0.0
		for i in range(frames):
			var t := float(i) / frames
			var freq := 300.0 + (t * 200.0)  # Rising squelch
			phase += freq / gen.mix_rate
			var sample := sin(phase * TAU) * 0.2 * (1.0 - t * 0.3)
			playback.push_frame(Vector2(sample, sample))
	
	await get_tree().create_timer(0.3).timeout
	player.queue_free()

func _play_drain_sound() -> void:
	var player := AudioStreamPlayer.new()
	get_tree().current_scene.add_child(player)
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.15
	player.stream = gen
	player.volume_db = -22.0
	player.play()
	
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback:
		var frames := int(gen.mix_rate * 0.15)
		var phase := 0.0
		for i in range(frames):
			var t := float(i) / frames
			var freq := 180.0 - (t * 60.0)  # Low slurp
			phase += freq / gen.mix_rate
			var sample := sin(phase * TAU) * 0.15
			playback.push_frame(Vector2(sample, sample))
	
	await get_tree().create_timer(0.2).timeout
	player.queue_free()

func _on_died() -> void:
	# Drop small blood splatter
	for i in range(6):
		var drop := ColorRect.new()
		drop.size = Vector2(3, 3)
		drop.position = global_position + Vector2(randf_range(-12, 12), randf_range(-12, 12))
		drop.color = Color(0.5, 0.1, 0.1, 0.6)
		drop.z_index = -4
		get_parent().add_child(drop)
	
	queue_free()