extends Area2D
class_name PickupRustedCompass

@export var reveal_radius: float = 300.0
@export var pulse_interval: float = 2.0

func _ready() -> void:
	add_to_group("pickups")
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_on_body_entered)
	_create_visuals()

func _create_visuals() -> void:
	# Rusted metal body
	var body := ColorRect.new()
	body.size = Vector2(20, 20)
	body.position = Vector2(-10, -10)
	body.color = Color(0.4, 0.25, 0.15, 1.0)
	add_child(body)
	
	# Needle
	var needle := ColorRect.new()
	needle.size = Vector2(2, 10)
	needle.position = Vector2(-1, -8)
	needle.color = Color(0.8, 0.2, 0.2, 0.8)
	needle.rotation = 0.3
	add_child(needle)
	
	# Collision
	var shape := CircleShape2D.new()
	shape.radius = 12.0
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)

func _physics_process(_delta: float) -> void:
	# Subtle hover
	var time := Time.get_ticks_msec() / 1000.0
	position.y += sin(time * 2.0) * 0.3

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	
	body.set_meta("has_compass", true)
	body.set_meta("compass_radius", reveal_radius)
	body.set_meta("compass_pulse_interval", pulse_interval)
	
	_spawn_pickup_text(global_position)
	_create_compass_overlay(get_tree().current_scene, body)
	_play_pickup_sound()
	
	queue_free()

func _create_compass_overlay(main: Node, player: Node2D) -> void:
	var overlay := CanvasLayer.new()
	overlay.name = "CompassRevealOverlay"
	overlay.layer = 12
	main.add_child(overlay)
	
	var script := GDScript.new()
	script.source_code = """
extends CanvasLayer

var _player: Node2D = null
var _pulse_timer: float = 0.0
var _reveal_markers: Array[ColorRect] = []

func _ready() -> void:
	_player = get_node_or_null('/root/Main/Player')

func _process(delta: float) -> void:
	if not _player or not is_instance_valid(_player):
		return
	
	var radius: float = _player.get_meta('compass_radius', 300.0)
	var interval: float = _player.get_meta('compass_pulse_interval', 2.0)
	
	_pulse_timer += delta
	if _pulse_timer >= interval:
		_pulse_timer = 0.0
		_reveal_nearby_items(radius)

func _reveal_nearby_items(radius: float) -> void:
	if not _player:
		return
	
	var items := get_tree().get_nodes_in_group('pickups')
	var enemies := get_tree().get_nodes_in_group('enemies')
	var all_targets := items + enemies
	
	for target in all_targets:
		if not is_instance_valid(target) or not target is Node2D:
			continue
		
		var distance := _player.global_position.distance_to(target.global_position)
		if distance <= radius:
			_spawn_reveal_marker(target.global_position, target.is_in_group('enemies'))

func _spawn_reveal_marker(pos: Vector2, is_enemy: bool) -> void:
	var marker := ColorRect.new()
	marker.size = Vector2(8, 8)
	marker.position = pos - Vector2(4, 4)
	marker.color = Color(0.8, 0.2, 0.2, 0.6) if is_enemy else Color(0.2, 0.8, 0.9, 0.6)
	marker.z_index = 10
	add_child(marker)
	_reveal_markers.append(marker)
	
	# Pulse outward
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(marker, 'scale', Vector2(2.0, 2.0), 1.0)
	tween.tween_property(marker, 'modulate:a', 0.0, 1.0)
	tween.finished.connect(func(): 
		_reveal_markers.erase(marker)
		marker.queue_free()
	)
"""
	script.reload()
	overlay.set_script(script)

func _spawn_pickup_text(pos: Vector2) -> void:
	var label := Label.new()
	label.text = "RUSTED COMPASS"
	label.add_theme_color_override(&"font_color", Color(0.8, 0.6, 0.4, 1.0))
	label.add_theme_font_size_override(&"font_size", 16)
	label.position = pos + Vector2(-50, -40)
	label.z_index = 100
	get_tree().current_scene.add_child(label)
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", pos.y - 70, 1.2)
	tween.tween_property(label, "modulate:a", 0.0, 1.2)
	tween.finished.connect(label.queue_free)

func _play_pickup_sound() -> void:
	var player := AudioStreamPlayer.new()
	get_tree().current_scene.add_child(player)
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.3
	player.stream = gen
	player.volume_db = -14.0
	player.play()
	
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback:
		var frames := int(gen.mix_rate * 0.3)
		var phase := randf() * TAU
		for i in range(frames):
			var t := float(i) / frames
			var freq := 440.0 + (t * 220.0)  # Rising chime
			phase += freq / gen.mix_rate
			var sample := sin(phase * TAU) * 0.2 * (1.0 - t * 0.6)
			playback.push_frame(Vector2(sample, sample))
	
	await get_tree().create_timer(0.35).timeout
	player.queue_free()