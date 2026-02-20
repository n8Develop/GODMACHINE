extends Control
class_name UIDeathWeight

@export var weight_per_death: float = 0.018
@export var max_weight: float = 0.4
@export var settle_speed: float = 0.3

var _current_weight: float = 0.0
var _target_weight: float = 0.0
var _vignette: ColorRect = null
var _death_count: int = 0

func _ready() -> void:
	# Full screen overlay, behind everything except darkness corruption
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 8  # Below darkness (15) and resurrection cost (10), above scars (5)
	
	# Create vignette
	_vignette = ColorRect.new()
	_vignette.anchor_right = 1.0
	_vignette.anchor_bottom = 1.0
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.color = Color(0.0, 0.0, 0.0, 0.0)
	add_child(_vignette)
	
	# Load saved death count
	_load_death_count()
	_target_weight = min(_death_count * weight_per_death, max_weight)
	_current_weight = _target_weight  # Start at full weight
	
	# Connect to player death
	var player := _get_player()
	if player:
		var health := player.get_node_or_null("HealthComponent")
		if health and health.has_signal(&"died"):
			health.died.connect(_on_player_died)

func _get_player() -> Node2D:
	return get_tree().get_first_node_in_group("player")

func _load_death_count() -> void:
	if FileAccess.file_exists("user://death_count.dat"):
		var file := FileAccess.open("user://death_count.dat", FileAccess.READ)
		if file:
			_death_count = file.get_32()
			file.close()

func _on_player_died() -> void:
	_death_count += 1
	_target_weight = min(_death_count * weight_per_death, max_weight)
	_play_settle_sound()

func _process(delta: float) -> void:
	# Slowly settle to target weight
	if abs(_current_weight - _target_weight) > 0.001:
		_current_weight = lerpf(_current_weight, _target_weight, settle_speed * delta)
	else:
		_current_weight = _target_weight
	
	# Update vignette - radial gradient effect via shader emulation
	# Center is clear, edges darken based on weight
	if _vignette:
		_vignette.color.a = _current_weight * 0.7  # Base darkness
		
		# Create "weight" effect: darken bottom more than top
		var material := _vignette.material as ShaderMaterial
		if not material:
			material = ShaderMaterial.new()
			var shader := Shader.new()
			shader.code = """
shader_type canvas_item;

uniform float weight : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 centered = UV - vec2(0.5, 0.5);
	float dist = length(centered);
	float vertical_bias = UV.y * 0.3;  // More weight at bottom
	float vignette = smoothstep(0.3, 1.0, dist + vertical_bias);
	COLOR = vec4(0.0, 0.0, 0.0, vignette * weight);
}
"""
			material.shader = shader
			_vignette.material = material
		
		material.set_shader_parameter("weight", _current_weight)

func _play_settle_sound() -> void:
	var player := AudioStreamPlayer.new()
	get_tree().current_scene.add_child(player)
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 1.2
	player.stream = gen
	player.volume_db = -22.0
	player.play()
	
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback:
		var frames := int(gen.mix_rate * 1.2)
		var phase := 0.0
		for i in range(frames):
			var t := float(i) / frames
			# Deep, settling rumble
			var freq := 40.0 + (sin(t * TAU * 0.5) * 10.0)
			phase += freq / gen.mix_rate
			var sample := sin(phase * TAU) * 0.4 * (1.0 - t * 0.6)
			playback.push_frame(Vector2(sample, sample))
	
	await get_tree().create_timer(1.25).timeout
	player.queue_free()