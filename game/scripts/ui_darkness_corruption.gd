extends Control
class_name UIDarknessCorruption

@export var base_corruption_rate: float = 0.002  # Per second in darkness
@export var light_decay_rate: float = 0.001      # Recovers slower than it corrupts
@export var max_corruption: float = 0.55         # Cap to keep playable
@export var tendril_count: int = 6

var _corruption_level: float = 0.0
var _tendrils: Array[ColorRect] = []
var _base_overlay: ColorRect = null
var _player_ref: Node2D = null

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 12
	
	# Load persistent corruption
	_load_corruption()
	
	# Create base darkness overlay
	_base_overlay = ColorRect.new()
	_base_overlay.color = Color(0.08, 0.02, 0.08, 0.0)
	_base_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_base_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_base_overlay)
	
	# Create creeping tendrils from edges
	_create_tendrils()
	
	await get_tree().process_frame
	_player_ref = get_tree().get_first_node_in_group("player")

func _create_tendrils() -> void:
	# Six tendrils creeping from different edges
	var anchors := [
		{"left": 0.0, "top": 0.0, "right": 0.3, "bottom": 0.5},  # Top-left
		{"left": 0.7, "top": 0.0, "right": 1.0, "bottom": 0.5},  # Top-right
		{"left": 0.0, "top": 0.3, "right": 0.25, "bottom": 0.7}, # Mid-left
		{"left": 0.75, "top": 0.3, "right": 1.0, "bottom": 0.7}, # Mid-right
		{"left": 0.0, "top": 0.5, "right": 0.4, "bottom": 1.0},  # Bottom-left
		{"left": 0.6, "top": 0.5, "right": 1.0, "bottom": 1.0}   # Bottom-right
	]
	
	for i in range(tendril_count):
		var tendril := ColorRect.new()
		tendril.color = Color(0.0, 0.0, 0.0, 0.0)
		tendril.anchor_left = anchors[i]["left"]
		tendril.anchor_top = anchors[i]["top"]
		tendril.anchor_right = anchors[i]["right"]
		tendril.anchor_bottom = anchors[i]["bottom"]
		tendril.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tendril)
		_tendrils.append(tendril)

func _process(delta: float) -> void:
	if not _player_ref or not is_instance_valid(_player_ref):
		return
	
	# Check if player has light source
	var has_torch: bool = _player_ref.get_meta("has_torch", false)
	var is_lantern: bool = _player_ref.get_meta("is_lantern", false)
	var has_light: bool = has_torch or is_lantern
	
	# Accumulate corruption in darkness, decay slowly in light
	if has_light:
		_corruption_level = max(0.0, _corruption_level - (light_decay_rate * delta))
	else:
		_corruption_level = min(max_corruption, _corruption_level + (base_corruption_rate * delta))
	
	# Update visuals
	_update_corruption_visual()
	
	# Save periodically (every 3 seconds)
	if int(Time.get_ticks_msec() / 3000.0) != int((Time.get_ticks_msec() - delta * 1000.0) / 3000.0):
		_save_corruption()

func _update_corruption_visual() -> void:
	# Base overlay grows with corruption
	if _base_overlay:
		var target_alpha: float = _corruption_level * 0.6
		var pulse: float = sin(Time.get_ticks_msec() * 0.0008) * 0.02
		_base_overlay.color.a = lerpf(_base_overlay.color.a, target_alpha + pulse, 0.1)
	
	# Tendrils activate at different thresholds
	var thresholds: Array[float] = [0.1, 0.15, 0.2, 0.25, 0.3, 0.35]
	for i in range(_tendrils.size()):
		if _corruption_level >= thresholds[i]:
			var intensity: float = (_corruption_level - thresholds[i]) / (max_corruption - thresholds[i])
			intensity = clampf(intensity, 0.0, 1.0)
			var pulse: float = sin(Time.get_ticks_msec() * 0.001 + i * 0.5) * 0.03
			_tendrils[i].color.a = lerpf(_tendrils[i].color.a, intensity * 0.4 + pulse, 0.08)
		else:
			_tendrils[i].color.a = lerpf(_tendrils[i].color.a, 0.0, 0.05)

func _load_corruption() -> void:
	var save_path := "user://darkness_corruption.dat"
	if FileAccess.file_exists(save_path):
		var file := FileAccess.open(save_path, FileAccess.READ)
		if file:
			_corruption_level = file.get_float()
			file.close()

func _save_corruption() -> void:
	var save_path := "user://darkness_corruption.dat"
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_float(_corruption_level)
		file.close()

func _exit_tree() -> void:
	_save_corruption()