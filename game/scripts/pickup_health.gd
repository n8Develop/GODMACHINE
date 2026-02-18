extends Area2D

@export var heal_amount: int = 25
@export var potion_type: String = "basic"  # basic, greater, full, shrine, orb
@export var is_shrine: bool = false
@export var shrine_cooldown: float = 10.0

const POTION_COLORS := {
	"basic": Color(0.9, 0.2, 0.2, 1.0),
	"greater": Color(1.0, 0.4, 0.8, 1.0),
	"full": Color(1.0, 0.8, 0.2, 1.0),
	"shrine": Color(1.0, 0.9, 0.4, 1.0),
	"orb": Color(1.0, 0.4, 0.4, 0.8)
}

const POTION_HEAL := {
	"basic": 25,
	"greater": 50,
	"full": 9999,
	"shrine": 50,
	"orb": 15
}

var _shrine_timer: float = 0.0
var _shrine_available: bool = true
var _shrine_visual: ColorRect = null
var _orbit_timer: float = 0.0
var _initial_pos: Vector2

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	
	if is_shrine:
		_create_shrine_visuals()
	elif potion_type == "orb":
		_initial_pos = position
	
	if POTION_HEAL.has(potion_type):
		heal_amount = POTION_HEAL[potion_type]

func _physics_process(delta: float) -> void:
	if is_shrine:
		_shrine_timer -= delta
		if _shrine_timer <= 0.0:
			_shrine_available = true
			_shrine_timer = 0.0
		_update_shrine_visual()
	elif potion_type == "orb":
		_orbit_timer += delta
		var offset := Vector2(
			sin(_orbit_timer * 2.0) * 12.0,
			cos(_orbit_timer * 1.3) * 8.0
		)
		position = _initial_pos + offset

func _create_shrine_visuals() -> void:
	var base := ColorRect.new()
	base.size = Vector2(32, 40)
	base.position = Vector2(-16, -40)
	base.color = Color(0.8, 0.7, 0.3, 1.0)
	add_child(base)
	
	var top := ColorRect.new()
	top.size = Vector2(40, 8)
	top.position = Vector2(-20, -44)
	top.color = Color(1.0, 0.9, 0.4, 1.0)
	add_child(top)
	
	_shrine_visual = ColorRect.new()
	_shrine_visual.size = Vector2(24, 32)
	_shrine_visual.position = Vector2(-12, -36)
	_shrine_visual.color = Color(1.0, 0.9, 0.4, 0.6)
	add_child(_shrine_visual)

func _update_shrine_visual() -> void:
	if not _shrine_visual:
		return
	
	var pulse := 0.6 + (sin(Time.get_ticks_msec() * 0.003) * 0.4)
	if _shrine_available:
		_shrine_visual.modulate.a = pulse
	else:
		_shrine_visual.modulate.a = 0.2

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	
	if is_shrine:
		if not _shrine_available:
			return
		_shrine_available = false
		_shrine_timer = shrine_cooldown
		_play_shrine_sound()
	
	var health := body.get_node_or_null("HealthComponent") as HealthComponent
	if health:
		var actual_heal := health.heal(heal_amount)
		if actual_heal > 0:
			_spawn_heal_text(body.global_position, actual_heal)
	
	if not is_shrine:
		# Spawn collection particles for non-shrine pickups
		for i in range(8):
			var particle := ColorRect.new()
			particle.size = Vector2(3, 3)
			particle.position = global_position + Vector2(-1.5, -1.5)
			particle.color = POTION_COLORS.get(potion_type, Color.WHITE)
			particle.z_index = 50
			get_tree().current_scene.add_child(particle)
			
			var angle := (TAU / 8.0) * i
			var offset := Vector2(cos(angle), sin(angle)) * 30.0
			
			var tween := create_tween()
			tween.set_parallel(true)
			tween.tween_property(particle, "position", global_position + offset, 0.4)
			tween.tween_property(particle, "modulate:a", 0.0, 0.4)
			tween.finished.connect(particle.queue_free)
		
		queue_free()

func _spawn_heal_text(pos: Vector2, amount: int) -> void:
	var label := Label.new()
	label.text = "+" + str(amount)
	label.add_theme_color_override(&"font_color", Color(0.2, 1.0, 0.3, 1.0))
	label.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	label.add_theme_constant_override(&"outline_size", 2)
	label.add_theme_font_size_override(&"font_size", 18)
	label.position = pos + Vector2(-15, -40)
	label.z_index = 100
	get_tree().current_scene.add_child(label)
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", pos.y - 70, 0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.8)
	tween.finished.connect(label.queue_free)

func _play_shrine_sound() -> void:
	var player := AudioStreamPlayer.new()
	get_tree().current_scene.add_child(player)
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.5
	player.stream = gen
	player.volume_db = -12.0
	player.play()
	
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback:
		var frames := int(gen.mix_rate * 0.5)
		var phase := 0.0
		for i in range(frames):
			var t := float(i) / frames
			var freq := 400.0 + (sin(t * TAU * 2.0) * 100.0)
			phase += freq / gen.mix_rate
			var sample := sin(phase * TAU) * 0.25 * (1.0 - t * 0.5)
			playback.push_frame(Vector2(sample, sample))
	
	await get_tree().create_timer(0.55).timeout
	player.queue_free()