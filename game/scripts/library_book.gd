extends Area2D
class_name LibraryBook

@export var book_title: String = "Forgotten Tome"
@export var book_text: String = "The pages are too faded to read."
@export var book_color: Color = Color(0.6, 0.5, 0.4, 1.0)
@export var read_distance: float = 50.0

var _is_read: bool = false
var _read_label: Label = null

func _ready() -> void:
	add_to_group("library_books")
	collision_layer = 0
	collision_mask = 2
	
	# Visual
	var visual := ColorRect.new()
	visual.size = Vector2(16, 20)
	visual.position = Vector2(-8, -10)
	visual.color = book_color
	add_child(visual)
	
	# Spine detail
	var spine := ColorRect.new()
	spine.size = Vector2(2, 20)
	spine.position = Vector2(-9, -10)
	spine.color = Color(book_color.r * 0.7, book_color.g * 0.7, book_color.b * 0.7, 1.0)
	visual.add_child(spine)
	
	# Collision
	var shape := RectangleShape2D.new()
	shape.size = Vector2(16, 20)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not _is_read:
		_show_text()
		_is_read = true

func _show_text() -> void:
	if _read_label:
		return
	
	_read_label = Label.new()
	_read_label.text = book_text
	_read_label.add_theme_color_override(&"font_color", Color(0.9, 0.9, 0.85, 1.0))
	_read_label.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	_read_label.add_theme_constant_override(&"outline_size", 2)
	_read_label.add_theme_font_size_override(&"font_size", 14)
	_read_label.position = global_position + Vector2(-80, -40)
	_read_label.z_index = 100
	_read_label.modulate.a = 0.0
	get_tree().current_scene.add_child(_read_label)
	
	# Fade in, hold, fade out
	var tween := create_tween()
	tween.tween_property(_read_label, "modulate:a", 1.0, 0.4)
	tween.tween_interval(3.0)
	tween.tween_property(_read_label, "modulate:a", 0.0, 0.8)
	tween.finished.connect(_read_label.queue_free)
	
	_play_read_sound()

func _play_read_sound() -> void:
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
			var freq := 400.0 + sin(t * TAU * 2.0) * 80.0
			phase += freq / gen.mix_rate
			var sample := sin(phase * TAU) * 0.2 * (1.0 - t * 0.5)
			playback.push_frame(Vector2(sample, sample))
	
	await get_tree().create_timer(0.35).timeout
	player.queue_free()