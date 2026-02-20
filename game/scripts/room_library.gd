extends RoomBase

@export var whisper_interval: float = 8.0
@export var book_count: int = 12

var _whisper_timer: float = 0.0
var _whisper_label: Label = null

const WHISPERS := [
	"...forgotten...",
	"...the reader never left...",
	"...these pages remember...",
	"...silence is knowledge...",
	"...dust settles on truth...",
]

const BOOK_TEXTS := [
	"'On the nature of the dungeon: It breathes, it remembers, it hungers.'",
	"'The hermit speaks truth. Listen when you can bear it.'",
	"'Light is finite. Darkness is patient.'",
	"'Each death leaves a mark. The world accumulates scars.'",
	"'The deeper you go, the more it knows you.'",
	"'Blood is just paint on stone. But it tells your story.'",
	"'The machine does not sleep. It only waits.'",
]

func _ready() -> void:
	super._ready()
	_create_bookshelves()
	_create_reading_desk()
	_create_scattered_books()
	_create_library_ambience()
	_spawn_readable_books()

func _create_bookshelves() -> void:
	# Left wall
	for i in range(3):
		var shelf := ColorRect.new()
		shelf.size = Vector2(100, 8)
		shelf.position = Vector2(60, 120 + i * 60)
		shelf.color = Color(0.3, 0.25, 0.2, 1.0)
		add_child(shelf)
	
	# Right wall
	for i in range(3):
		var shelf := ColorRect.new()
		shelf.size = Vector2(100, 8)
		shelf.position = Vector2(480, 120 + i * 60)
		shelf.color = Color(0.3, 0.25, 0.2, 1.0)
		add_child(shelf)

func _create_reading_desk() -> void:
	var desk := ColorRect.new()
	desk.size = Vector2(80, 40)
	desk.position = Vector2(280, 200)
	desk.color = Color(0.35, 0.3, 0.25, 1.0)
	add_child(desk)
	
	# Chair
	var chair := ColorRect.new()
	chair.size = Vector2(24, 24)
	chair.position = Vector2(308, 250)
	chair.color = Color(0.4, 0.35, 0.3, 1.0)
	add_child(chair)

func _create_scattered_books() -> void:
	for i in range(book_count):
		var book := ColorRect.new()
		book.size = Vector2(12, 16)
		book.position = Vector2(
			randf_range(100, 540),
			randf_range(100, 380)
		)
		book.rotation = randf_range(-0.3, 0.3)
		book.color = Color(
			randf_range(0.4, 0.7),
			randf_range(0.3, 0.6),
			randf_range(0.2, 0.5),
			1.0
		)
		book.z_index = -2
		add_child(book)

func _create_library_ambience() -> void:
	var audio := AudioStreamPlayer.new()
	audio.name = "LibraryDrone"
	add_child(audio)
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 2.0
	audio.stream = gen
	audio.volume_db = -28.0
	audio.autoplay = true
	
	call_deferred("_generate_library_drone", audio)

func _generate_library_drone(player: AudioStreamPlayer) -> void:
	await get_tree().process_frame
	if not is_instance_valid(player):
		return
	
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if not playback:
		return
	
	var phase := randf() * TAU
	while is_instance_valid(player):
		for i in range(128):
			var freq := 50.0 + sin(Time.get_ticks_msec() * 0.0002) * 15.0
			phase += freq / 22050.0
			var sample := sin(phase * TAU) * 0.25
			playback.push_frame(Vector2(sample, sample))
		await get_tree().create_timer(0.05).timeout

func _spawn_readable_books() -> void:
	var BookScene := load("res://scenes/library_book.tscn")
	
	var positions := [
		Vector2(290, 215),  # On desk
		Vector2(150, 140),  # Left shelf
		Vector2(520, 200),  # Right shelf
		Vector2(200, 320),  # Floor
		Vector2(450, 350),  # Floor
	]
	
	for i in range(min(5, BOOK_TEXTS.size())):
		var book := BookScene.instantiate()
		book.position = positions[i]
		book.book_text = BOOK_TEXTS[i]
		book.book_color = Color(
			randf_range(0.5, 0.7),
			randf_range(0.4, 0.6),
			randf_range(0.3, 0.5),
			1.0
		)
		add_child(book)

func _physics_process(delta: float) -> void:
	_whisper_timer += delta
	if _whisper_timer >= whisper_interval:
		_whisper_timer = 0.0
		_show_whisper()

func _show_whisper() -> void:
	if _whisper_label:
		return
	
	_whisper_label = Label.new()
	_whisper_label.text = WHISPERS.pick_random()
	_whisper_label.add_theme_color_override(&"font_color", Color(0.6, 0.5, 0.7, 0.8))
	_whisper_label.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 0.6))
	_whisper_label.add_theme_constant_override(&"outline_size", 2)
	_whisper_label.add_theme_font_size_override(&"font_size", 16)
	_whisper_label.position = Vector2(
		randf_range(200, 400),
		randf_range(50, 100)
	)
	_whisper_label.z_index = 50
	_whisper_label.modulate.a = 0.0
	add_child(_whisper_label)
	
	var tween := create_tween()
	tween.tween_property(_whisper_label, "modulate:a", 0.8, 1.0)
	tween.tween_interval(2.0)
	tween.tween_property(_whisper_label, "modulate:a", 0.0, 1.5)
	tween.finished.connect(_whisper_label.queue_free)
	tween.finished.connect(func(): _whisper_label = null)
	
	_play_whisper_sound()

func _play_whisper_sound() -> void:
	var player := AudioStreamPlayer.new()
	add_child(player)
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.5
	player.stream = gen
	player.volume_db = -22.0
	player.play()
	
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback:
		var frames := int(gen.mix_rate * 0.5)
		var phase := randf() * TAU
		for i in range(frames):
			var t := float(i) / frames
			var freq := 300.0 + sin(t * TAU * 3.0) * 100.0
			phase += freq / gen.mix_rate
			var sample := sin(phase * TAU) * 0.2 * (1.0 - t * 0.3)
			playback.push_frame(Vector2(sample, sample))
	
	await get_tree().create_timer(0.55).timeout
	player.queue_free()