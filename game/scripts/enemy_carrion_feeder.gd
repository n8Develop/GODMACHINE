extends CharacterBody2D

@export var scuttle_speed: float = 65.0
@export var feast_range: float = 40.0
@export var feast_duration: float = 3.0
@export var growth_per_feast: float = 0.3
@export var max_size_multiplier: float = 2.5

var _state: String = "searching"  # searching, feasting, fleeing
var _feast_timer: float = 0.0
var _feast_target: Node2D = null
var _size_scale: float = 1.0
var _feasts_consumed: int = 0

@onready var _sprite: ColorRect = $Sprite
@onready var _health: Node = $HealthComponent

func _ready() -> void:
	add_to_group("enemies")
	if _health:
		_health.died.connect(_on_died)
	_update_visual_size()

func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if not player:
		return
	
	match _state:
		"searching":
			_search_for_corpses(delta, player)
		"feasting":
			_consume_corpse(delta)
		"fleeing":
			_flee_from_player(delta, player)

func _search_for_corpses(delta: float, player: Node2D) -> void:
	# Look for death stains (blood_stain group)
	var stains := get_tree().get_nodes_in_group("blood_stain")
	var nearest_stain: Node2D = null
	var nearest_distance := 999999.0
	
	for stain in stains:
		if not is_instance_valid(stain):
			continue
		var distance := global_position.distance_to(stain.global_position)
		if distance < nearest_distance and distance < 300.0:
			nearest_distance = distance
			nearest_stain = stain
	
	# If we find a corpse marker, move toward it
	if nearest_stain:
		var direction := global_position.direction_to(nearest_stain.global_position)
		velocity = direction * scuttle_speed
		
		# Check if close enough to feast
		if global_position.distance_to(nearest_stain.global_position) < feast_range:
			_start_feast(nearest_stain)
	else:
		# Wander if no corpses nearby
		var to_player := global_position.direction_to(player.global_position)
		var distance_to_player := global_position.distance_to(player.global_position)
		
		# Flee if player is too close
		if distance_to_player < 100.0:
			_state = "fleeing"
		else:
			# Random scuttling
			var wander_angle := sin(Time.get_ticks_msec() * 0.002) * 2.0
			velocity = Vector2(cos(wander_angle), sin(wander_angle)) * (scuttle_speed * 0.5)
	
	move_and_slide()

func _start_feast(target: Node2D) -> void:
	_state = "feasting"
	_feast_target = target
	_feast_timer = feast_duration
	velocity = Vector2.ZERO
	_spawn_feast_text()

func _consume_corpse(delta: float) -> void:
	_feast_timer -= delta
	
	# Visual feedback — pulse while eating
	if _sprite:
		var pulse := 1.0 + (sin(Time.get_ticks_msec() * 0.01) * 0.1)
		_sprite.scale = Vector2.ONE * _size_scale * pulse
	
	if _feast_timer <= 0.0:
		# Feast complete — grow larger
		_feasts_consumed += 1
		_size_scale = min(_size_scale + growth_per_feast, max_size_multiplier)
		_update_visual_size()
		
		# Heal from feasting
		if _health:
			_health.heal(15)
		
		# Remove the corpse marker
		if is_instance_valid(_feast_target):
			_feast_target.queue_free()
		
		_state = "searching"
		_spawn_growth_text()
		_play_feast_sound()

func _flee_from_player(delta: float, player: Node2D) -> void:
	var away_from_player := global_position.direction_to(player.global_position) * -1.0
	velocity = away_from_player * (scuttle_speed * 1.5)
	move_and_slide()
	
	# Return to searching if far enough away
	if global_position.distance_to(player.global_position) > 150.0:
		_state = "searching"

func _update_visual_size() -> void:
	if _sprite:
		_sprite.scale = Vector2.ONE * _size_scale
	
	# Larger = different color (darker, more saturated)
	if _sprite:
		var base_color := Color(0.4, 0.3, 0.25, 1.0)
		var growth_factor := (_size_scale - 1.0) / (max_size_multiplier - 1.0)
		_sprite.color = base_color.lerp(Color(0.2, 0.15, 0.1, 1.0), growth_factor)
	
	# Larger = more HP
	if _health:
		var bonus_hp := int(_feasts_consumed * 10.0)
		_health.max_health = _health.max_health + bonus_hp
		_health.current_health = _health.max_health

func _spawn_feast_text() -> void:
	var label := Label.new()
	label.text = "FEASTING..."
	label.add_theme_color_override(&"font_color", Color(0.6, 0.3, 0.1, 1.0))
	label.add_theme_font_size_override(&"font_size", 12)
	label.position = global_position + Vector2(-30, -40)
	label.z_index = 100
	get_tree().current_scene.add_child(label)
	
	var tween := create_tween()
	tween.tween_property(label, "modulate:a", 0.0, feast_duration)
	tween.finished.connect(label.queue_free)

func _spawn_growth_text() -> void:
	var label := Label.new()
	label.text = "GROWS"
	label.add_theme_color_override(&"font_color", Color(0.8, 0.4, 0.1, 1.0))
	label.add_theme_font_size_override(&"font_size", 14)
	label.position = global_position + Vector2(-20, -50)
	label.z_index = 100
	get_tree().current_scene.add_child(label)
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", global_position.y - 70, 0.6)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.finished.connect(label.queue_free)

func _play_feast_sound() -> void:
	var player := AudioStreamPlayer.new()
	get_tree().current_scene.add_child(player)
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.3
	player.stream = gen
	player.volume_db = -18.0
	player.play()
	
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback:
		var frames := int(gen.mix_rate * 0.3)
		var phase := randf() * TAU
		for i in range(frames):
			var t := float(i) / frames
			# Wet crunching — low frequency with noise
			var freq := 120.0 + (sin(t * 8.0) * 40.0)
			phase += freq / gen.mix_rate
			var sample := sin(phase * TAU) * 0.2
			# Add noise for crunch texture
			sample += (randf() - 0.5) * 0.15 * (1.0 - t)
			playback.push_frame(Vector2(sample, sample))
	
	await get_tree().create_timer(0.35).timeout
	player.queue_free()

func _on_died() -> void:
	# Spawn death particles
	for i in range(8):
		var particle := ColorRect.new()
		particle.size = Vector2(6, 6) * _size_scale
		particle.position = global_position + Vector2(-3, -3) * _size_scale
		particle.color = Color(0.3, 0.2, 0.15, 1.0)
		particle.z_index = 50
		get_tree().current_scene.add_child(particle)
		
		var angle := (TAU / 8.0) * i
		var offset := Vector2(cos(angle), sin(angle)) * 30.0 * _size_scale
		
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "position", global_position + offset, 0.5)
		tween.tween_property(particle, "modulate:a", 0.0, 0.5)
		tween.finished.connect(particle.queue_free)
	
	queue_free()