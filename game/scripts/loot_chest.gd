extends Area2D

@export var loot_scenes: Array[PackedScene] = []
@export var spawn_count: int = 3
@export var is_opened: bool = false

var _glow_phase: float = 0.0
var _echo_visual: ColorRect = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_create_visuals()
	
	# Create memory echo if loot was recently opened
	var main := get_tree().current_scene
	var memory := main.get_node_or_null("DungeonMemory") as DungeonMemory
	if memory and memory.get_meta("chests_opened", 0) > 0:
		_create_echo_visual()

func _create_echo_visual() -> void:
	_echo_visual = ColorRect.new()
	_echo_visual.size = Vector2(32, 32)
	_echo_visual.position = Vector2(-16, -16)
	_echo_visual.color = Color(1.0, 0.8, 0.3, 0.15)
	_echo_visual.z_index = -1
	add_child(_echo_visual)

func _physics_process(delta: float) -> void:
	if is_opened:
		return
	
	_glow_phase += delta * 2.0
	var glow := get_node_or_null("Glow")
	if glow:
		var pulse := 0.6 + (sin(_glow_phase * TAU) * 0.2)
		glow.modulate.a = pulse
	
	# Pulse echo
	if _echo_visual:
		var pulse := 0.1 + (sin(Time.get_ticks_msec() * 0.003) * 0.08)
		_echo_visual.modulate.a = pulse
		_echo_visual.rotation += delta * 0.3

func _create_visuals() -> void:
	# Outer glow
	var glow := ColorRect.new()
	glow.name = "Glow"
	glow.size = Vector2(28, 28)
	glow.position = Vector2(-14, -14)
	glow.color = Color(1.0, 0.8, 0.3, 0.4)
	add_child(glow)
	
	# Label
	var label := Label.new()
	label.name = "Label"
	label.text = "LOOT"
	label.add_theme_color_override(&"font_color", Color(1.0, 0.9, 0.3, 1.0))
	label.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	label.add_theme_constant_override(&"outline_size", 2)
	label.add_theme_font_size_override(&"font_size", 10)
	label.position = Vector2(-15, -28)
	add_child(label)

func _on_body_entered(body: Node2D) -> void:
	if is_opened or not body.is_in_group("player"):
		return
	
	is_opened = true
	_spawn_loot()
	_play_open_sound()
	
	# Record chest opened
	var main := get_tree().current_scene
	var memory := main.get_node_or_null("DungeonMemory") as DungeonMemory
	if memory:
		var count := memory.get_meta("chests_opened", 0)
		memory.set_meta("chests_opened", count + 1)
	
	# Update visuals
	var label := get_node_or_null("Label")
	if label:
		label.text = "EMPTY"
		label.add_theme_color_override(&"font_color", Color(0.5, 0.5, 0.5, 1.0))
	
	var glow := get_node_or_null("Glow")
	if glow:
		glow.modulate.a = 0.1

func _spawn_loot() -> void:
	if loot_scenes.is_empty():
		return
	
	for i in range(spawn_count):
		var scene := loot_scenes[randi() % loot_scenes.size()]
		if not scene:
			continue
		
		var item := scene.instantiate()
		if not item is Node2D:
			item.queue_free()
			continue
		
		# Position in arc around chest
		var angle := (TAU / spawn_count) * i
		var offset := Vector2(cos(angle), sin(angle)) * 40.0
		item.global_position = global_position + offset
		
		get_tree().current_scene.add_child(item)

func _play_open_sound() -> void:
	var player := AudioStreamPlayer.new()
	get_tree().current_scene.add_child(player)
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.4
	player.stream = gen
	player.volume_db = -10.0
	player.play()
	
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback:
		var frames := int(gen.mix_rate * 0.4)
		var phase := 0.0
		for i in range(frames):
			var t := float(i) / frames
			var freq := 300.0 + (t * 600.0)
			phase += freq / gen.mix_rate
			var sample := sin(phase * TAU) * 0.25 * (1.0 - t * 0.7)
			sample += sin(phase * TAU * 2.0) * 0.15 * (1.0 - t * 0.8)
			playback.push_frame(Vector2(sample, sample))
	
	await get_tree().create_timer(0.45).timeout
	player.queue_free()