extends RoomBase

@export var whisper_interval: float = 8.0
@export var book_count: int = 12

var _whisper_timer: float = 0.0
var _whispers: Array[String] = [
	"The ink remembers what the flesh forgot.",
	"Each page a tomb. Each word a ghost.",
	"They wrote their names here. Then they stopped writing.",
	"The silence between sentences grows longer.",
	"Dust settles on unfinished thoughts.",
	"The last reader never left.",
]

func _ready() -> void:
	super._ready()
	_create_bookshelves()
	_create_reading_desk()
	_create_scattered_books()
	_create_library_ambience()
	_spawn_memory_pickups()

func _create_bookshelves() -> void:
	# Four tall shelves along the walls
	for i in range(4):
		var shelf := ColorRect.new()
		shelf.size = Vector2(80, 140)
		shelf.color = Color(0.25, 0.2, 0.18, 1.0)
		
		match i:
			0: shelf.position = Vector2(50, 100)
			1: shelf.position = Vector2(510, 100)
			2: shelf.position = Vector2(50, 300)
			3: shelf.position = Vector2(510, 300)
		
		add_child(shelf)
		
		# Book spines on shelves
		for j in range(5):
			var book := ColorRect.new()
			book.size = Vector2(12, 18)
			book.position = Vector2(8 + (j * 14), 30 + (randf() * 80))
			book.color = Color(
				0.3 + randf() * 0.4,
				0.2 + randf() * 0.3,
				0.15 + randf() * 0.25,
				1.0
			)
			shelf.add_child(book)

func _create_reading_desk() -> void:
	# Desk in center
	var desk := ColorRect.new()
	desk.size = Vector2(100, 60)
	desk.position = Vector2(270, 220)
	desk.color = Color(0.3, 0.25, 0.2, 1.0)
	add_child(desk)
	
	# Open book on desk
	var book := ColorRect.new()
	book.size = Vector2(40, 30)
	book.position = Vector2(30, 15)
	book.color = Color(0.85, 0.82, 0.75, 1.0)
	desk.add_child(book)
	
	# Faint text lines
	for i in range(6):
		var line := ColorRect.new()
		line.size = Vector2(30, 2)
		line.position = Vector2(5, 5 + (i * 4))
		line.color = Color(0.2, 0.2, 0.2, 0.3)
		book.add_child(line)

func _create_scattered_books() -> void:
	# Books on floor - evidence of abandonment
	for i in range(book_count):
		var book := ColorRect.new()
		book.size = Vector2(20, 14)
		book.position = Vector2(
			100 + randf() * 440,
			120 + randf() * 280
		)
		book.rotation = randf() * TAU
		book.color = Color(
			0.4 + randf() * 0.3,
			0.3 + randf() * 0.2,
			0.2 + randf() * 0.2,
			1.0
		)
		book.z_index = -5
		add_child(book)

func _create_library_ambience() -> void:
	var audio := AudioStreamPlayer.new()
	audio.name = "LibraryAmbience"
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
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if not playback:
		return
	
	var gen := player.stream as AudioStreamGenerator
	var frames := int(gen.mix_rate * 2.0)
	var phase1 := randf() * TAU
	var phase2 := randf() * TAU
	
	for i in range(frames):
		# Very low drone suggesting old knowledge
		var sample1 := sin(phase1) * 0.15
		var sample2 := sin(phase2) * 0.12
		var combined := (sample1 + sample2) * 0.5
		
		playback.push_frame(Vector2(combined, combined))
		
		phase1 += (52.0 / gen.mix_rate) * TAU  # Low hum
		phase2 += (78.0 / gen.mix_rate) * TAU  # Harmonic

func _spawn_memory_pickups() -> void:
	# Spawn 2-3 echo memories in the library
	var memory_scene := load("res://scenes/pickup_echo_memory.tscn")
	var memory_texts := [
		"The last librarian locked the doors from inside.",
		"They tried to write their way out.",
		"Knowledge could not save them.",
	]
	
	var spawn_count := 2 + randi() % 2
	for i in range(spawn_count):
		var memory := memory_scene.instantiate()
		memory.position = Vector2(
			150 + randf() * 340,
			160 + randf() * 240
		)
		memory.memory_text = memory_texts[i % memory_texts.size()]
		memory.echo_color = Color(0.7, 0.6, 0.8, 0.8)
		call_deferred("add_child", memory)

func _physics_process(delta: float) -> void:
	_whisper_timer += delta
	
	if _whisper_timer >= whisper_interval:
		_whisper_timer = 0.0
		_show_whisper()

func _show_whisper() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if not player:
		return
	
	var label := Label.new()
	label.text = _whispers.pick_random()
	label.add_theme_color_override(&"font_color", Color(0.6, 0.5, 0.7, 0.9))
	label.add_theme_font_size_override(&"font_size", 14)
	label.position = Vector2(320 - 100, 100)
	label.z_index = 100
	add_child(label)
	
	# Fade out
	var tween := create_tween()
	tween.tween_property(label, "modulate:a", 0.0, 4.0)
	tween.finished.connect(label.queue_free)
	
	_play_whisper_sound()

func _play_whisper_sound() -> void:
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
			# High frequency whisper
			var freq := 3200.0 + (sin(t * TAU * 3.0) * 400.0)
			phase += (freq / gen.mix_rate) * TAU
			var sample := sin(phase) * 0.15 * (1.0 - t)
			# Add noise texture
			var noise := (randf() - 0.5) * 0.08
			playback.push_frame(Vector2(sample + noise, sample + noise))
	
	await get_tree().create_timer(0.85).timeout
	player.queue_free()