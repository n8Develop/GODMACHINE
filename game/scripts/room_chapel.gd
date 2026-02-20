extends RoomBase

@export var candle_count: int = 8
@export var prayer_echo_interval: float = 12.0
@export var blessing_cooldown: float = 20.0

var _prayer_timer: float = 0.0
var _blessing_timer: float = 0.0
var _altar: Node2D = null
var _candles: Array[Node2D] = []

const PRAYER_ECHOES := [
	"Please... let me see the surface again...",
	"I remember sunlight. Was it real?",
	"Forgive me for what I've done to survive.",
	"The bells rang once. Long ago.",
	"We built this place before the dark came.",
]

func _ready() -> void:
	super._ready()
	_create_chapel_structure()
	_create_altar()
	_create_candles()
	_create_chapel_ambience()
	_spawn_dust_motes()

func _create_chapel_structure() -> void:
	# Nave walls
	for i in range(4):
		var wall := ColorRect.new()
		wall.size = Vector2(8, 120)
		wall.position = Vector2(80 + (i * 120), 60)
		wall.color = Color(0.25, 0.22, 0.2, 1.0)
		add_child(wall)
	
	# Broken pews
	for i in range(3):
		var pew := ColorRect.new()
		pew.size = Vector2(80, 12)
		pew.position = Vector2(120 + (i * 100), 280)
		pew.color = Color(0.2, 0.18, 0.15, 1.0)
		pew.rotation = randf_range(-0.1, 0.1)
		add_child(pew)
	
	# Collapsed ceiling debris
	for i in range(6):
		var debris := ColorRect.new()
		debris.size = Vector2(randf_range(16, 40), randf_range(16, 40))
		debris.position = Vector2(randf_range(100, 540), randf_range(80, 380))
		debris.color = Color(0.3, 0.28, 0.25, 1.0)
		debris.rotation = randf_range(-0.3, 0.3)
		add_child(debris)

func _create_altar() -> void:
	_altar = Node2D.new()
	_altar.position = Vector2(320, 180)
	add_child(_altar)
	
	# Altar base
	var base := ColorRect.new()
	base.size = Vector2(80, 60)
	base.position = Vector2(-40, -30)
	base.color = Color(0.35, 0.33, 0.3, 1.0)
	_altar.add_child(base)
	
	# Altar glow (faint)
	var glow := ColorRect.new()
	glow.size = Vector2(60, 40)
	glow.position = Vector2(-30, -20)
	glow.color = Color(0.9, 0.85, 0.6, 0.15)
	_altar.add_child(glow)
	
	# Interaction prompt
	var prompt := Label.new()
	prompt.text = "[E] Pray"
	prompt.add_theme_color_override(&"font_color", Color(0.8, 0.8, 0.7, 0.6))
	prompt.add_theme_font_size_override(&"font_size", 14)
	prompt.position = Vector2(-25, -50)
	prompt.visible = false
	prompt.name = "Prompt"
	_altar.add_child(prompt)

func _create_candles() -> void:
	var positions := [
		Vector2(160, 140), Vector2(480, 140),
		Vector2(140, 260), Vector2(500, 260),
		Vector2(280, 120), Vector2(360, 120),
		Vector2(280, 340), Vector2(360, 340),
	]
	
	for i in candle_count:
		var candle := Node2D.new()
		candle.position = positions[i]
		add_child(candle)
		
		# Candle body
		var body := ColorRect.new()
		body.size = Vector2(6, 18)
		body.position = Vector2(-3, -18)
		body.color = Color(0.85, 0.8, 0.7, 1.0)
		candle.add_child(body)
		
		# Flame (subtle)
		var flame := ColorRect.new()
		flame.size = Vector2(8, 10)
		flame.position = Vector2(-4, -26)
		flame.color = Color(1.0, 0.7, 0.3, 0.6)
		flame.name = "Flame"
		candle.add_child(flame)
		
		_candles.append(candle)

func _create_chapel_ambience() -> void:
	var audio := AudioStreamPlayer.new()
	audio.name = "ChapelAmbience"
	add_child(audio)
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 4.0
	audio.stream = gen
	audio.volume_db = -26.0
	audio.autoplay = true
	audio.play()
	
	call_deferred("_generate_chapel_drone", audio)

func _generate_chapel_drone(audio: AudioStreamPlayer) -> void:
	var playback := audio.get_stream_playback() as AudioStreamGeneratorPlayback
	if not playback:
		return
	
	var gen := audio.stream as AudioStreamGenerator
	var frames := int(gen.mix_rate * 4.0)
	var phase := randf() * TAU
	
	for i in range(frames):
		var t := float(i) / frames
		# Very low harmonic drone with slow beat
		var freq := 45.0 + sin(t * TAU * 0.25) * 5.0
		phase += (freq / gen.mix_rate) * TAU
		var sample := sin(phase) * 0.15
		# Add slow pulse
		sample *= 0.7 + 0.3 * sin(t * TAU * 2.0)
		playback.push_frame(Vector2(sample, sample))

func _physics_process(delta: float) -> void:
	_prayer_timer += delta
	_blessing_timer += delta
	
	# Flicker candles
	for candle in _candles:
		var flame := candle.get_node_or_null("Flame")
		if flame:
			var flicker := sin(Time.get_ticks_msec() * 0.005 + candle.position.x * 0.1)
			flame.modulate.a = 0.5 + flicker * 0.2
	
	# Check altar proximity
	var player := get_tree().get_first_node_in_group("player")
	if player and _altar:
		var prompt := _altar.get_node_or_null("Prompt")
		if prompt:
			var distance := player.global_position.distance_to(_altar.global_position)
			prompt.visible = distance < 60.0
			
			if distance < 60.0 and Input.is_action_just_pressed(&"ui_accept"):
				if _blessing_timer >= blessing_cooldown:
					_offer_blessing(player)
					_blessing_timer = 0.0
	
	# Random prayer echoes
	if _prayer_timer >= prayer_echo_interval:
		_prayer_timer = 0.0
		_show_prayer_echo()

func _offer_blessing(player: Node2D) -> void:
	var health := player.get_node_or_null("HealthComponent")
	if not health:
		return
	
	# Small heal + temporary defense buff
	var heal_amount := 20
	health.heal(heal_amount)
	
	# Visual feedback
	_spawn_blessing_light()
	_spawn_blessing_text(player.global_position)
	_play_blessing_sound()
	
	# Apply defense buff via status effect component
	var status := player.get_node_or_null("StatusEffectComponent")
	if status and status.has_method("apply_effect"):
		status.apply_effect("blessed", 30.0, {"damage_reduction": 0.3})

func _spawn_blessing_light() -> void:
	if not _altar:
		return
	
	var light := ColorRect.new()
	light.size = Vector2(120, 120)
	light.position = _altar.global_position + Vector2(-60, -60)
	light.color = Color(1.0, 0.95, 0.7, 0.5)
	light.z_index = 50
	get_tree().current_scene.add_child(light)
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(light, "modulate:a", 0.0, 1.5)
	tween.tween_property(light, "scale", Vector2(1.5, 1.5), 1.5)
	tween.finished.connect(light.queue_free)

func _spawn_blessing_text(pos: Vector2) -> void:
	var label := Label.new()
	label.text = "Blessed"
	label.add_theme_color_override(&"font_color", Color(1.0, 0.95, 0.6, 1.0))
	label.add_theme_color_override(&"font_outline_color", Color(0.3, 0.25, 0.2, 1.0))
	label.add_theme_constant_override(&"outline_size", 2)
	label.add_theme_font_size_override(&"font_size", 18)
	label.position = pos + Vector2(-30, -40)
	label.z_index = 100
	get_tree().current_scene.add_child(label)
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", pos.y - 80, 1.2)
	tween.tween_property(label, "modulate:a", 0.0, 1.2)
	tween.finished.connect(label.queue_free)

func _show_prayer_echo() -> void:
	var text := PRAYER_ECHOES.pick_random()
	
	var label := Label.new()
	label.text = text
	label.add_theme_color_override(&"font_color", Color(0.7, 0.65, 0.5, 0.7))
	label.add_theme_font_size_override(&"font_size", 14)
	label.position = Vector2(randf_range(120, 520), randf_range(100, 300))
	label.z_index = 60
	add_child(label)
	
	var tween := create_tween()
	tween.tween_property(label, "modulate:a", 0.0, 4.0)
	tween.finished.connect(label.queue_free)

func _play_blessing_sound() -> void:
	var player := AudioStreamPlayer.new()
	get_tree().current_scene.add_child(player)
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.8
	player.stream = gen
	player.volume_db = -15.0
	player.play()
	
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback:
		var frames := int(gen.mix_rate * 0.8)
		var phase := 0.0
		for i in range(frames):
			var t := float(i) / frames
			# Ascending bell-like tone
			var freq := 400.0 + (t * 300.0)
			phase += (freq / gen.mix_rate) * TAU
			var sample := sin(phase) * 0.25 * (1.0 - t * 0.6)
			playback.push_frame(Vector2(sample, sample))
	
	await get_tree().create_timer(0.85).timeout
	player.queue_free()