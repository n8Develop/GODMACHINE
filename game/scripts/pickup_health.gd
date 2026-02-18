extends Area2D

@export var heal_amount: int = 25
@export var potion_type: String = "basic"  # basic, greater, full, shrine
@export var is_shrine: bool = false
@export var shrine_cooldown: float = 10.0

const POTION_COLORS := {
	"basic": Color(0.9, 0.1, 0.1, 1),
	"greater": Color(0.8, 0.2, 0.8, 1),
	"full": Color(0.2, 0.8, 1.0, 1),
	"shrine": Color(1.0, 0.9, 0.3, 1)
}

const POTION_HEAL := {
	"basic": 25,
	"greater": 50,
	"full": 100,
	"shrine": 50
}

var _shrine_ready: bool = true
var _shrine_timer: float = 0.0
var _glow_phase: float = 0.0

func _ready() -> void:
	add_to_group("pickups")
	body_entered.connect(_on_body_entered)
	
	# Apply potion type settings
	if POTION_HEAL.has(potion_type):
		heal_amount = POTION_HEAL[potion_type]
	
	# Update visual color
	var rect := get_node_or_null("ColorRect")
	if rect and POTION_COLORS.has(potion_type):
		rect.color = POTION_COLORS[potion_type]
	
	# Create shrine-specific visuals
	if is_shrine:
		_create_shrine_visuals()

func _physics_process(delta: float) -> void:
	if not is_shrine:
		return
	
	# Cooldown timer
	if not _shrine_ready:
		_shrine_timer -= delta
		if _shrine_timer <= 0.0:
			_shrine_ready = true
			_update_shrine_visual()
	
	# Glow animation
	_glow_phase += delta * 2.0
	var inner := get_node_or_null("InnerGlow")
	if inner:
		var pulse := 0.5 + (sin(_glow_phase * TAU) * 0.3)
		inner.modulate.a = pulse if _shrine_ready else pulse * 0.3

func _create_shrine_visuals() -> void:
	# Inner glow
	var inner := ColorRect.new()
	inner.name = "InnerGlow"
	inner.size = Vector2(12, 12)
	inner.position = Vector2(-6, -6)
	inner.color = Color(1.0, 1.0, 0.8, 0.6)
	add_child(inner)
	
	# Status label
	var label := Label.new()
	label.name = "StatusLabel"
	label.text = "SHRINE"
	label.add_theme_color_override(&"font_color", Color(1.0, 0.9, 0.3, 1.0))
	label.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	label.add_theme_constant_override(&"outline_size", 2)
	label.add_theme_font_size_override(&"font_size", 10)
	label.position = Vector2(-20, -25)
	add_child(label)

func _update_shrine_visual() -> void:
	var label := get_node_or_null("StatusLabel")
	if label:
		if _shrine_ready:
			label.text = "SHRINE"
			label.add_theme_color_override(&"font_color", Color(1.0, 0.9, 0.3, 1.0))
		else:
			label.text = str(int(_shrine_timer)) + "s"
			label.add_theme_color_override(&"font_color", Color(0.5, 0.5, 0.5, 1.0))

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		var health := body.get_node_or_null("HealthComponent") as HealthComponent
		if health:
			# Check if healing is needed
			if health.current_health < health.max_health:
				# Shrine logic
				if is_shrine:
					if _shrine_ready:
						health.heal(heal_amount)
						_spawn_heal_text(body.global_position, heal_amount)
						_play_shrine_sound()
						_shrine_ready = false
						_shrine_timer = shrine_cooldown
						_update_shrine_visual()
				else:
					# Regular potion — consume on pickup
					health.heal(heal_amount)
					_spawn_heal_text(body.global_position, heal_amount)
					queue_free()

func _spawn_heal_text(pos: Vector2, amount: int) -> void:
	var label := Label.new()
	label.text = "+" + str(amount)
	label.add_theme_color_override(&"font_color", Color(0.2, 1.0, 0.2, 1.0))
	label.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	label.add_theme_constant_override(&"outline_size", 2)
	label.add_theme_font_size_override(&"font_size", 16)
	label.position = pos + Vector2(-10, -30)
	label.z_index = 100
	get_tree().current_scene.add_child(label)
	
	# Animate upward fade
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", pos.y - 60, 0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.8)
	tween.finished.connect(label.queue_free)

func _play_shrine_sound() -> void:
	var player := AudioStreamPlayer.new()
	get_tree().current_scene.add_child(player)
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.5
	player.stream = gen
	player.volume_db = -8.0
	player.play()
	
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback:
		var frames := int(gen.mix_rate * 0.5)
		var phase := 0.0
		for i in range(frames):
			var t := float(i) / frames
			# Bell-like harmonic sound
			var freq := 440.0 + (sin(t * TAU * 2.0) * 110.0)
			phase += freq / gen.mix_rate
			var sample := sin(phase * TAU) * 0.25 * (1.0 - t * 0.7)
			# Add harmonics
			sample += sin(phase * TAU * 2.0) * 0.15 * (1.0 - t * 0.8)
			playback.push_frame(Vector2(sample, sample))
	
	await get_tree().create_timer(0.55).timeout
	player.queue_free()