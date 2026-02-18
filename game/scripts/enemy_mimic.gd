extends CharacterBody2D

@export var chomp_damage: int = 25
@export var chomp_range: float = 45.0
@export var chomp_cooldown: float = 2.0
@export var leap_speed: float = 180.0
@export var aggro_range: float = 100.0

var _chomp_timer: float = 0.0
var _is_disguised: bool = true
var _aggro: bool = false

@onready var health: Node = $HealthComponent
@onready var sprite: ColorRect = $Sprite

func _ready() -> void:
	add_to_group("enemies")
	if health:
		health.died.connect(_on_died)
	
	# Start disguised as chest
	sprite.color = Color(0.6, 0.4, 0.2, 1.0)

func _physics_process(delta: float) -> void:
	if _chomp_timer > 0.0:
		_chomp_timer -= delta
	
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if not player:
		return
	
	var distance := global_position.distance_to(player.global_position)
	
	# Trigger disguise break
	if _is_disguised and distance < aggro_range:
		_reveal()
	
	if not _is_disguised:
		# Chase and chomp
		if distance > chomp_range:
			var direction := global_position.direction_to(player.global_position)
			velocity = direction * leap_speed
			move_and_slide()
		else:
			velocity = Vector2.ZERO
			if _chomp_timer <= 0.0:
				_perform_chomp(player)
				_chomp_timer = chomp_cooldown

func _reveal() -> void:
	_is_disguised = false
	_aggro = true
	
	# Visual change — sprout teeth
	sprite.color = Color(0.8, 0.3, 0.3, 1.0)
	
	# Spawn "teeth" indicators
	for i in range(4):
		var tooth := ColorRect.new()
		tooth.size = Vector2(6, 10)
		var angle := (TAU / 4.0) * i
		tooth.position = Vector2(cos(angle), sin(angle)) * 12.0
		tooth.color = Color(0.95, 0.95, 0.9, 1.0)
		sprite.add_child(tooth)
	
	_play_reveal_sound()

func _perform_chomp(player: Node2D) -> void:
	var player_health := player.get_node_or_null("HealthComponent")
	if player_health:
		player_health.take_damage(chomp_damage)
		_spawn_damage_number(player.global_position, chomp_damage)
	
	# Flash sprite
	sprite.modulate = Color(2.0, 2.0, 2.0, 1.0)
	await get_tree().create_timer(0.1).timeout
	if sprite:
		sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
	
	_play_chomp_sound()

func _spawn_damage_number(pos: Vector2, damage: int) -> void:
	var label := Label.new()
	label.text = str(damage)
	label.add_theme_color_override(&"font_color", Color(1.0, 0.3, 0.3, 1.0))
	label.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	label.add_theme_constant_override(&"outline_size", 2)
	label.add_theme_font_size_override(&"font_size", 20)
	label.position = pos + Vector2(-10, -30)
	label.z_index = 100
	get_tree().current_scene.add_child(label)
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", pos.y - 60, 0.6)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.finished.connect(label.queue_free)

func _play_reveal_sound() -> void:
	var player := AudioStreamPlayer.new()
	get_tree().current_scene.add_child(player)
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.3
	player.stream = gen
	player.volume_db = -8.0
	player.play()
	
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback:
		var frames := int(gen.mix_rate * 0.3)
		var phase := 0.0
		for i in range(frames):
			var t := float(i) / frames
			var freq := 300.0 + (t * 200.0)  # Rising snarl
			phase += freq / gen.mix_rate
			var sample := sin(phase * TAU) * 0.4 * (1.0 - t * 0.5)
			playback.push_frame(Vector2(sample, sample))
	
	await get_tree().create_timer(0.35).timeout
	player.queue_free()

func _play_chomp_sound() -> void:
	var player := AudioStreamPlayer.new()
	get_tree().current_scene.add_child(player)
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.2
	player.stream = gen
	player.volume_db = -10.0
	player.play()
	
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback:
		var frames := int(gen.mix_rate * 0.2)
		var phase := 0.0
		for i in range(frames):
			var t := float(i) / frames
			var freq := 180.0 if i < frames / 2 else 120.0  # Snap-close
			phase += freq / gen.mix_rate
			var sample := sin(phase * TAU) * 0.35 * (1.0 - t)
			playback.push_frame(Vector2(sample, sample))
	
	await get_tree().create_timer(0.25).timeout
	player.queue_free()

func _on_died() -> void:
	# Spawn fragments
	for i in range(8):
		var fragment := ColorRect.new()
		fragment.size = Vector2(6, 6)
		fragment.position = global_position
		fragment.color = Color(0.6, 0.3, 0.1, 1.0)
		fragment.z_index = 10
		get_tree().current_scene.add_child(fragment)
		
		var angle := (TAU / 8.0) * i
		var velocity := Vector2(cos(angle), sin(angle)) * 80.0
		
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(fragment, "position", fragment.position + velocity, 0.5)
		tween.tween_property(fragment, "modulate:a", 0.0, 0.5)
		tween.finished.connect(fragment.queue_free)
	
	queue_free()