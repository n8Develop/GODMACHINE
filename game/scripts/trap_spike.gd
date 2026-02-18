extends Area2D

@export var damage: int = 15
@export var trigger_interval: float = 2.0
@export var active_duration: float = 0.8

var _timer: float = 0.0
var _is_active: bool = false
var _active_timer: float = 0.0

@onready var spikes: ColorRect = $Spikes
@onready var warning: ColorRect = $Warning

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # Player layer
	body_entered.connect(_on_body_entered)
	
	if warning:
		warning.hide()

func _physics_process(delta: float) -> void:
	_timer += delta
	
	# Warning phase (0.3s before activation)
	if _timer >= trigger_interval - 0.3 and _timer < trigger_interval and not _is_active:
		if warning:
			warning.show()
			# Pulse warning
			var pulse := abs(sin(Time.get_ticks_msec() * 0.02))
			warning.modulate.a = 0.5 + (pulse * 0.5)
	
	# Activation
	if _timer >= trigger_interval and not _is_active:
		_activate()
	
	# Active phase
	if _is_active:
		_active_timer += delta
		if _active_timer >= active_duration:
			_deactivate()

func _activate() -> void:
	_is_active = true
	_active_timer = 0.0
	
	if spikes:
		spikes.color = Color(0.9, 0.1, 0.1, 1.0)
	if warning:
		warning.hide()
	
	# Play activation sound
	_play_spike_sound()
	
	# Damage any overlapping bodies
	var bodies := get_overlapping_bodies()
	for body in bodies:
		_damage_body(body)

func _deactivate() -> void:
	_is_active = false
	_timer = 0.0
	
	if spikes:
		spikes.color = Color(0.4, 0.4, 0.4, 1.0)

func _on_body_entered(body: Node2D) -> void:
	if _is_active:
		_damage_body(body)

func _damage_body(body: Node2D) -> void:
	if body.is_in_group("player"):
		var health := body.get_node_or_null("HealthComponent")
		if health:
			health.take_damage(damage)
			print("GODMACHINE: Spike trap triggered — ", damage, " damage inflicted")

func _play_spike_sound() -> void:
	var player := AudioStreamPlayer.new()
	get_tree().current_scene.add_child(player)
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.1
	player.stream = gen
	player.volume_db = -8.0
	
	player.play()
	
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback:
		var frames := int(gen.mix_rate * 0.1)
		var phase := 0.0
		for i in range(frames):
			var t := float(i) / frames
			# Sharp metallic spike sound
			var freq := 200.0 + (t * 400.0)
			phase += freq / gen.mix_rate
			var sample := sin(phase * TAU)
			sample *= 0.3 * (1.0 - t)
			playback.push_frame(Vector2(sample, sample))
	
	await get_tree().create_timer(0.15).timeout
	player.queue_free()