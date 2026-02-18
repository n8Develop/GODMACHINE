extends Area2D

@export var fuel_capacity: float = 120.0  # Double torch capacity
@export var light_radius: float = 180.0  # Wider light
@export var fuel_efficiency: float = 0.5  # Burns slower

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	add_to_group("pickups")
	_create_visuals()

func _create_visuals() -> void:
	# Brass lantern body
	var body := ColorRect.new()
	body.size = Vector2(16, 24)
	body.position = Vector2(-8, -16)
	body.color = Color(0.8, 0.6, 0.2, 1.0)
	add_child(body)
	
	# Glass window
	var glass := ColorRect.new()
	glass.size = Vector2(12, 14)
	glass.position = Vector2(-6, -12)
	glass.color = Color(0.9, 0.9, 0.7, 0.6)
	add_child(glass)
	
	# Flame inside
	var flame := ColorRect.new()
	flame.size = Vector2(6, 10)
	flame.position = Vector2(-3, -10)
	flame.color = Color(1.0, 0.7, 0.2, 0.9)
	flame.name = "Flame"
	add_child(flame)
	
	# Handle
	var handle := ColorRect.new()
	handle.size = Vector2(20, 3)
	handle.position = Vector2(-10, -18)
	handle.color = Color(0.6, 0.4, 0.1, 1.0)
	add_child(handle)
	
	collision_layer = 0
	collision_mask = 2
	
	var shape := CircleShape2D.new()
	shape.radius = 12.0
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)

func _physics_process(_delta: float) -> void:
	# Flicker flame
	var flame := get_node_or_null("Flame")
	if flame:
		var flicker := sin(Time.get_ticks_msec() * 0.01) * 0.2 + 1.0
		flame.size.y = 10.0 * flicker

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	
	# Check if player already has darkness overlay
	var main := get_tree().current_scene
	var existing_overlay := main.get_node_or_null("DarknessOverlay")
	
	if existing_overlay:
		# Upgrade existing torch to lantern
		existing_overlay.set_meta("is_lantern", true)
		existing_overlay.set_meta("max_fuel", fuel_capacity)
		existing_overlay.set_meta("fuel", fuel_capacity)
		existing_overlay.set_meta("light_radius", light_radius)
		existing_overlay.set_meta("drain_rate", fuel_efficiency)
		_spawn_upgrade_text(body.global_position)
	else:
		# Create new lantern overlay
		_create_lantern_overlay(main, body)
		_spawn_pickup_text(body.global_position)
	
	_play_pickup_sound()
	_spawn_light_burst()
	queue_free()

func _create_lantern_overlay(main: Node, player: Node2D) -> void:
	var overlay := CanvasLayer.new()
	overlay.name = "DarknessOverlay"
	overlay.layer = 100
	overlay.set_meta("is_lantern", true)
	overlay.set_meta("max_fuel", fuel_capacity)
	overlay.set_meta("fuel", fuel_capacity)
	overlay.set_meta("light_radius", light_radius)
	overlay.set_meta("drain_rate", fuel_efficiency)
	
	var script := GDScript.new()
	script.source_code = """
extends CanvasLayer

func _ready() -> void:
	var darkness := ColorRect.new()
	darkness.name = "Darkness"
	darkness.color = Color(0, 0, 0, 0.95)
	darkness.size = Vector2(640, 480)
	add_child(darkness)
	
	var light := ColorRect.new()
	light.name = "Light"
	light.color = Color(0, 0, 0, 0)
	var radius: float = get_meta("light_radius", 140.0)
	light.size = Vector2(radius * 2, radius * 2)
	light.position = Vector2(-radius, -radius)
	darkness.add_child(light)
	
	var fuel_bar := ColorRect.new()
	fuel_bar.name = "FuelBar"
	fuel_bar.color = Color(1.0, 0.7, 0.2, 0.8)
	fuel_bar.size = Vector2(100, 8)
	fuel_bar.position = Vector2(20, 70)
	add_child(fuel_bar)
	
	var fuel_bg := ColorRect.new()
	fuel_bg.color = Color(0.2, 0.2, 0.2, 0.6)
	fuel_bg.size = Vector2(100, 8)
	fuel_bg.position = Vector2(0, 0)
	fuel_bg.z_index = -1
	fuel_bar.add_child(fuel_bg)

func _process(delta: float) -> void:
	var main := get_tree().current_scene
	if not main:
		return
	
	var player := main.get_node_or_null("Player")
	if not player:
		return
	
	var fuel: float = get_meta("fuel", 60.0)
	var drain_rate: float = get_meta("drain_rate", 1.0)
	var max_fuel: float = get_meta("max_fuel", 60.0)
	var is_lantern: bool = get_meta("is_lantern", false)
	
	if fuel > 0.0:
		fuel -= delta * drain_rate
		set_meta("fuel", fuel)
	
	var light := get_node_or_null("Darkness/Light")
	var fuel_bar := get_node_or_null("FuelBar")
	
	if light:
		var cam := player.get_node_or_null("Camera2D")
		if cam:
			var screen_pos := cam.get_screen_center_position()
			var radius: float = get_meta("light_radius", 140.0)
			light.position = screen_pos - Vector2(radius, radius)
		
		if fuel > 0.0:
			var flicker_phase := Time.get_ticks_msec() * 0.003
			var flicker := sin(flicker_phase) * 0.03 + 0.97
			if fuel < max_fuel * 0.2:
				flicker = sin(flicker_phase * 3.0) * 0.15 + 0.85
			
			var alpha := 0.95 * flicker
			if is_lantern:
				alpha = 0.92 * flicker  # Lantern slightly brighter
			light.color = Color(0, 0, 0, alpha)
		else:
			light.color = Color(0, 0, 0, 0.0)
	
	if fuel_bar:
		var fuel_percent := fuel / max_fuel
		fuel_bar.size.x = 100.0 * fuel_percent
		if is_lantern:
			fuel_bar.color = Color(0.9, 0.7, 0.3, 0.8)  # Golden for lantern
		else:
			fuel_bar.color = Color(1.0, 0.7, 0.2, 0.8)
"""
	script.reload()
	overlay.set_script(script)
	main.add_child(overlay)

func _spawn_pickup_text(pos: Vector2) -> void:
	var label := Label.new()
	label.text = "LANTERN"
	label.add_theme_color_override(&"font_color", Color(0.9, 0.7, 0.3, 1.0))
	label.add_theme_font_size_override(&"font_size", 16)
	label.position = pos + Vector2(-30, -40)
	label.z_index = 100
	get_tree().current_scene.add_child(label)
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", pos.y - 70, 1.0)
	tween.tween_property(label, "modulate:a", 0.0, 1.0)
	tween.finished.connect(label.queue_free)

func _spawn_upgrade_text(pos: Vector2) -> void:
	var label := Label.new()
	label.text = "TORCH → LANTERN"
	label.add_theme_color_override(&"font_color", Color(1.0, 0.9, 0.4, 1.0))
	label.add_theme_font_size_override(&"font_size", 18)
	label.position = pos + Vector2(-60, -40)
	label.z_index = 100
	get_tree().current_scene.add_child(label)
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", pos.y - 70, 1.2)
	tween.tween_property(label, "modulate:a", 0.0, 1.2)
	tween.finished.connect(label.queue_free)

func _spawn_light_burst() -> void:
	for i in range(16):
		var particle := ColorRect.new()
		particle.size = Vector2(3, 3)
		particle.position = global_position + Vector2(-1.5, -1.5)
		particle.color = Color(1.0, 0.8, 0.3, 1.0)
		particle.z_index = 50
		get_tree().current_scene.add_child(particle)
		
		var angle := (TAU / 16.0) * i
		var offset := Vector2(cos(angle), sin(angle)) * 60.0
		
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "position", global_position + offset, 0.6)
		tween.tween_property(particle, "modulate:a", 0.0, 0.6)
		tween.finished.connect(particle.queue_free)

func _play_pickup_sound() -> void:
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
			var freq := 600.0 + (t * 300.0)  # Rising chime
			phase += freq / gen.mix_rate
			var sample := sin(phase * TAU) * 0.25 * (1.0 - t)
			playback.push_frame(Vector2(sample, sample))
	
	await get_tree().create_timer(0.55).timeout
	player.queue_free()