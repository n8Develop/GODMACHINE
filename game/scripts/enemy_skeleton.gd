extends CharacterBody2D

@export var walk_speed: float = 50.0
@export var attack_range: float = 35.0
@export var attack_damage: int = 15
@export var attack_cooldown: float = 1.5
@export var bone_color: Color = Color(0.9, 0.9, 0.8, 1.0)

var _attack_timer: float = 0.0
var _target: Node2D = null

@onready var health: Node = $HealthComponent
@onready var sprite: ColorRect = $Sprite

func _ready() -> void:
	add_to_group("enemies")
	if health:
		health.died.connect(_on_died)

func _physics_process(delta: float) -> void:
	_attack_timer -= delta
	
	if not _target or not is_instance_valid(_target):
		_target = get_tree().get_first_node_in_group("player")
		if not _target:
			return
	
	var distance := global_position.distance_to(_target.global_position)
	
	# Attack if in range
	if distance <= attack_range and _attack_timer <= 0.0:
		_perform_attack()
		_attack_timer = attack_cooldown
		velocity = Vector2.ZERO
	else:
		# Walk toward player
		var direction := global_position.direction_to(_target.global_position)
		velocity = direction * walk_speed
	
	move_and_slide()

func _perform_attack() -> void:
	# Flash sprite white
	if sprite:
		sprite.modulate = Color(2.0, 2.0, 2.0, 1.0)
		await get_tree().create_timer(0.1).timeout
		if sprite:
			sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
	
	# Deal damage to player
	if _target and is_instance_valid(_target):
		var distance := global_position.distance_to(_target.global_position)
		if distance <= attack_range:
			var player_health := _target.get_node_or_null("HealthComponent")
			if player_health:
				player_health.take_damage(attack_damage)
	
	# Play attack sound
	_play_attack_sound()

func _play_attack_sound() -> void:
	var player := AudioStreamPlayer.new()
	get_tree().current_scene.add_child(player)
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.2
	player.stream = gen
	player.volume_db = -15.0
	player.play()
	
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback:
		var frames := int(gen.mix_rate * 0.2)
		for i in range(frames):
			var t := float(i) / frames
			var freq := 200.0 - (t * 150.0)  # Low bone-clack
			var phase := (i * freq / gen.mix_rate)
			var sample := sin(phase * TAU) * 0.2 * (1.0 - t)
			playback.push_frame(Vector2(sample, sample))
	
	await get_tree().create_timer(0.25).timeout
	player.queue_free()

func _on_died() -> void:
	# Death particles - bone fragments
	for i in range(8):
		var particle := ColorRect.new()
		particle.size = Vector2(4, 4)
		particle.position = global_position + Vector2(randf_range(-8, 8), randf_range(-8, 8))
		particle.color = bone_color
		particle.z_index = 50
		get_parent().add_child(particle)
		
		var dir := Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "position", particle.position + dir * 30.0, 0.5)
		tween.tween_property(particle, "modulate:a", 0.0, 0.5)
		tween.finished.connect(particle.queue_free)
	
	queue_free()