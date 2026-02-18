extends CharacterBody2D

enum State { PERCHED, FLEEING, CIRCLING }

@export var flee_speed: float = 180.0
@export var circle_radius: float = 120.0
@export var flee_distance: float = 80.0
@export var perch_time: float = 8.0

var state: State = State.PERCHED
var perch_timer: float = 0.0
var circle_center: Vector2 = Vector2.ZERO
var circle_angle: float = 0.0
var caw_timer: float = 0.0
var wing_phase: float = 0.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	add_to_group("ambient_creatures")
	
	perch_timer = randf_range(3.0, perch_time)
	circle_angle = randf() * TAU
	
	_create_visual()
	_create_audio()

func _create_visual() -> void:
	# Body
	var body := ColorRect.new()
	body.size = Vector2(12, 10)
	body.position = Vector2(-6, -5)
	body.color = Color(0.1, 0.1, 0.15, 1.0)
	body.name = "Body"
	add_child(body)
	
	# Wings (will flap)
	var left_wing := ColorRect.new()
	left_wing.size = Vector2(8, 4)
	left_wing.position = Vector2(-10, -3)
	left_wing.color = Color(0.15, 0.15, 0.2, 1.0)
	left_wing.name = "LeftWing"
	add_child(left_wing)
	
	var right_wing := ColorRect.new()
	right_wing.size = Vector2(8, 4)
	right_wing.position = Vector2(6, -3)
	right_wing.color = Color(0.15, 0.15, 0.2, 1.0)
	right_wing.name = "RightWing"
	add_child(right_wing)
	
	# Beak
	var beak := ColorRect.new()
	beak.size = Vector2(4, 2)
	beak.position = Vector2(6, 0)
	beak.color = Color(0.9, 0.8, 0.3, 1.0)
	add_child(beak)

func _create_audio() -> void:
	var player := AudioStreamPlayer.new()
	player.name = "AudioPlayer"
	player.volume_db = -22.0
	add_child(player)

func _physics_process(delta: float) -> void:
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if not player or not is_instance_valid(player):
		return
	
	var distance := global_position.distance_to(player.global_position)
	
	match state:
		State.PERCHED:
			perch_timer -= delta
			
			# Check if player approaches
			if distance < flee_distance:
				_start_fleeing(player.global_position)
			elif perch_timer <= 0.0:
				# Occasionally caw while perched
				caw_timer -= delta
				if caw_timer <= 0.0:
					_play_caw()
					caw_timer = randf_range(4.0, 8.0)
		
		State.FLEEING:
			# Fly away from player
			var away := global_position.direction_to(player.global_position) * -1.0
			velocity = away * flee_speed
			move_and_slide()
			
			# Start circling when far enough
			if distance > flee_distance * 2.0:
				_start_circling()
		
		State.CIRCLING:
			# Circle overhead
			circle_angle += delta * 0.8
			var offset := Vector2(cos(circle_angle), sin(circle_angle)) * circle_radius
			var target := circle_center + offset
			var dir := global_position.direction_to(target)
			velocity = dir * (flee_speed * 0.6)
			move_and_slide()
			
			# Eventually perch again if player leaves
			if distance > circle_radius * 2.5:
				_start_perching()
	
	# Animate wings based on velocity
	_update_wing_animation(delta)

func _start_fleeing(from_pos: Vector2) -> void:
	state = State.FLEEING
	circle_center = global_position + (global_position.direction_to(from_pos) * -circle_radius)
	_play_caw()

func _start_circling() -> void:
	state = State.CIRCLING
	circle_angle = randf() * TAU

func _start_perching() -> void:
	state = State.PERCHED
	perch_timer = randf_range(3.0, perch_time)
	caw_timer = randf_range(2.0, 5.0)
	velocity = Vector2.ZERO

func _update_wing_animation(delta: float) -> void:
	var left_wing := get_node_or_null("LeftWing") as ColorRect
	var right_wing := get_node_or_null("RightWing") as ColorRect
	
	if not left_wing or not right_wing:
		return
	
	if state == State.PERCHED:
		# Wings folded
		left_wing.position.x = -10.0
		right_wing.position.x = 6.0
	else:
		# Wings flapping
		wing_phase += delta * 12.0
		var flap := sin(wing_phase) * 3.0
		left_wing.position.x = -10.0 - abs(flap)
		right_wing.position.x = 6.0 + abs(flap)

func _play_caw() -> void:
	var player := get_node_or_null("AudioPlayer") as AudioStreamPlayer
	if not player:
		return
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.3
	player.stream = gen
	player.play()
	
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if not playback:
		return
	
	var frames := int(gen.mix_rate * 0.3)
	var phase := randf() * TAU
	
	for i in range(frames):
		var t := float(i) / frames
		# Harsh, descending squawk
		var freq := 1400.0 - (t * 600.0)
		var noise := (randf() - 0.5) * 0.4  # Add harshness
		phase += freq / gen.mix_rate
		var sample := sin(phase * TAU) * 0.2 + noise
		sample *= (1.0 - t * 0.7)  # Fade out
		playback.push_frame(Vector2(sample, sample))