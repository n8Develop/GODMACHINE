extends RoomBase

@export var hermit_dialogue: Array[String] = [
	"The deeper you go, the less you remember who you were.",
	"I counted my deaths once. Then I lost count. Then I lost myself.",
	"Light burns fast. Memory burns slower. Both leave ash.",
	"The dungeon doesn't kill you. It just waits until you forget why you're fighting.",
	"I offered the stone my blood. It offered me nothing. We are even."
]

@export var shrine_blessing_hp: int = 50
@export var shrine_cost_corruption: float = 0.03

var _hermit_sprite: ColorRect = null
var _dialogue_label: Label = null
var _shrine_active: bool = true
var _player_near: bool = false

func _ready() -> void:
	super._ready()
	_create_hermit()
	_create_shrine()
	_create_dialogue_prompt()
	_create_ambient_hum()

func _create_hermit() -> void:
	# Seated figure in corner
	_hermit_sprite = ColorRect.new()
	_hermit_sprite.size = Vector2(28, 42)
	_hermit_sprite.position = Vector2(80, 180)
	_hermit_sprite.color = Color(0.4, 0.35, 0.3, 0.9)
	add_child(_hermit_sprite)
	
	# Dim lantern beside hermit
	var lantern := ColorRect.new()
	lantern.size = Vector2(8, 12)
	lantern.position = Vector2(50, 208)
	lantern.color = Color(0.9, 0.6, 0.2, 0.5)
	add_child(lantern)

func _create_shrine() -> void:
	# Simple stone altar
	var altar := ColorRect.new()
	altar.size = Vector2(48, 32)
	altar.position = Vector2(296, 200)
	altar.color = Color(0.3, 0.3, 0.35, 1.0)
	add_child(altar)
	
	# Faint glow
	var glow := ColorRect.new()
	glow.size = Vector2(56, 8)
	glow.position = Vector2(292, 224)
	glow.color = Color(0.5, 0.7, 0.9, 0.3)
	glow.name = "ShrineGlow"
	add_child(glow)

func _create_dialogue_prompt() -> void:
	_dialogue_label = Label.new()
	_dialogue_label.add_theme_color_override(&"font_color", Color(0.7, 0.7, 0.6, 0.0))
	_dialogue_label.add_theme_font_size_override(&"font_size", 14)
	_dialogue_label.position = Vector2(120, 120)
	_dialogue_label.size = Vector2(400, 100)
	_dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_dialogue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dialogue_label.z_index = 50
	add_child(_dialogue_label)

func _create_ambient_hum() -> void:
	var player := AudioStreamPlayer.new()
	player.name = "HermitHum"
	add_child(player)
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 2.0
	player.stream = gen
	player.volume_db = -32.0
	player.autoplay = true
	
	call_deferred("_generate_hermit_hum", player)

func _generate_hermit_hum(player: AudioStreamPlayer) -> void:
	await get_tree().process_frame
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if not playback:
		return
	
	var gen := player.stream as AudioStreamGenerator
	var frames := int(gen.mix_rate * 2.0)
	var phase := randf() * TAU
	
	for i in range(frames):
		var t := float(i) / frames
		var base_freq := 52.0  # Very low, just above silence
		var wobble := sin(t * TAU * 0.3) * 3.0
		var freq := base_freq + wobble
		phase += freq / gen.mix_rate
		var sample := sin(phase * TAU) * 0.08
		playback.push_frame(Vector2(sample, sample))

func _physics_process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	var dist_to_hermit := player.global_position.distance_to(_hermit_sprite.global_position)
	var dist_to_shrine := player.global_position.distance_to(Vector2(320, 216))
	
	# Show dialogue when near hermit
	if dist_to_hermit < 80.0 and not _player_near:
		_player_near = true
		_show_random_dialogue()
	elif dist_to_hermit >= 80.0 and _player_near:
		_player_near = false
		_fade_dialogue()
	
	# Shrine interaction
	if dist_to_shrine < 50.0 and _shrine_active:
		if Input.is_action_just_pressed(&"attack"):
			_use_shrine(player)

func _show_random_dialogue() -> void:
	_dialogue_label.text = hermit_dialogue.pick_random()
	var tween := create_tween()
	tween.tween_property(_dialogue_label, "modulate:a", 0.85, 0.8)
	_play_hermit_mutter()

func _fade_dialogue() -> void:
	var tween := create_tween()
	tween.tween_property(_dialogue_label, "modulate:a", 0.0, 0.5)

func _use_shrine(player: Node2D) -> void:
	var health_comp := player.get_node_or_null("HealthComponent")
	if not health_comp:
		return
	
	_shrine_active = false
	health_comp.heal(shrine_blessing_hp)
	
	# Add corruption cost
	var corruption_ui := get_tree().get_first_node_in_group("ui_darkness_corruption")
	if corruption_ui and corruption_ui.has_method("add_corruption"):
		corruption_ui.add_corruption(shrine_cost_corruption)
	
	_spawn_blessing_text(Vector2(320, 200))
	_spawn_corruption_warning(Vector2(320, 180))
	_play_shrine_sound()
	
	# Dim the glow
	var glow := get_node_or_null("ShrineGlow")
	if glow:
		var tween := create_tween()
		tween.tween_property(glow, "modulate:a", 0.1, 1.5)

func _spawn_blessing_text(pos: Vector2) -> void:
	var label := Label.new()
	label.text = "BLESSING GRANTED"
	label.add_theme_color_override(&"font_color", Color(0.5, 0.8, 0.9, 1.0))
	label.add_theme_font_size_override(&"font_size", 16)
	label.position = pos + Vector2(-80, 0)
	label.z_index = 100
	add_child(label)
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", pos.y - 40, 1.2)
	tween.tween_property(label, "modulate:a", 0.0, 1.2)
	tween.finished.connect(label.queue_free)

func _spawn_corruption_warning(pos: Vector2) -> void:
	var label := Label.new()
	label.text = "...but the darkness grows"
	label.add_theme_color_override(&"font_color", Color(0.6, 0.3, 0.3, 0.8))
	label.add_theme_font_size_override(&"font_size", 12)
	label.position = pos + Vector2(-70, 0)
	label.z_index = 100
	add_child(label)
	
	await get_tree().create_timer(0.4).timeout
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", pos.y - 30, 1.0)
	tween.tween_property(label, "modulate:a", 0.0, 1.0)
	tween.finished.connect(label.queue_free)

func _play_hermit_mutter() -> void:
	var player := AudioStreamPlayer.new()
	add_child(player)
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.8
	player.stream = gen
	player.volume_db = -22.0
	player.play()
	
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback:
		var frames := int(gen.mix_rate * 0.8)
		var phase := randf() * TAU
		for i in range(frames):
			var t := float(i) / frames
			var freq := 180.0 + sin(t * TAU * 3.0) * 40.0
			phase += freq / gen.mix_rate
			var sample := sin(phase * TAU) * 0.15 * (1.0 - t * 0.6)
			playback.push_frame(Vector2(sample, sample))
	
	await get_tree().create_timer(0.85).timeout
	player.queue_free()

func _play_shrine_sound() -> void:
	var player := AudioStreamPlayer.new()
	add_child(player)
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 1.5
	player.stream = gen
	player.volume_db = -14.0
	player.play()
	
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback:
		var frames := int(gen.mix_rate * 1.5)
		var phase := 0.0
		for i in range(frames):
			var t := float(i) / frames
			# Rising harmonic
			var freq := 240.0 + (t * 180.0)
			phase += freq / gen.mix_rate
			var sample := sin(phase * TAU) * 0.2 * (1.0 - t * 0.5)
			# Add second harmonic
			var harmonic := sin(phase * TAU * 1.5) * 0.1 * (1.0 - t * 0.4)
			sample += harmonic
			playback.push_frame(Vector2(sample, sample))
	
	await get_tree().create_timer(1.6).timeout
	player.queue_free()