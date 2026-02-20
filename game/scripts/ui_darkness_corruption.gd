extends Control
class_name UIDarknessCorruption

@export var base_corruption_rate: float = 0.002  # Per second in darkness
@export var light_decay_rate: float = 0.001      # Recovers slower than it corrupts
@export var max_corruption: float = 0.55         # Cap to keep playable
@export var tendril_count: int = 6

var _corruption_level: float = 0.0
var _tendrils: Array[ColorRect] = []

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_create_tendrils()
	_load_corruption()

func _create_tendrils() -> void:
	var tendril_configs := [
		{anchor_left = 0.0, anchor_top = 0.0, anchor_right = 0.0, anchor_bottom = 0.3},
		{anchor_left = 1.0, anchor_top = 0.0, anchor_right = 1.0, anchor_bottom = 0.3},
		{anchor_left = 0.0, anchor_top = 0.7, anchor_right = 0.0, anchor_bottom = 1.0},
		{anchor_left = 1.0, anchor_top = 0.7, anchor_right = 1.0, anchor_bottom = 1.0},
		{anchor_left = 0.0, anchor_top = 0.0, anchor_right = 0.3, anchor_bottom = 0.0},
		{anchor_left = 0.7, anchor_top = 0.0, anchor_right = 1.0, anchor_bottom = 0.0}
	]
	
	for i in range(tendril_count):
		var tendril := ColorRect.new()
		var config: Dictionary = tendril_configs[i]
		tendril.anchor_left = config.anchor_left
		tendril.anchor_top = config.anchor_top
		tendril.anchor_right = config.anchor_right
		tendril.anchor_bottom = config.anchor_bottom
		tendril.color = Color(0.08, 0.05, 0.12, 0.0)
		tendril.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tendril)
		_tendrils.append(tendril)

func _process(delta: float) -> void:
	var player := _get_player()
	if not player:
		return
	
	var has_light: bool = player.get_meta("has_torch", false) or player.get_meta("has_lantern", false)
	
	if has_light:
		_corruption_level -= light_decay_rate * delta
	else:
		_corruption_level += base_corruption_rate * delta
	
	_corruption_level = clampf(_corruption_level, 0.0, max_corruption)
	_update_corruption_visual()

func _update_corruption_visual() -> void:
	var thresholds := [0.05, 0.12, 0.2, 0.3, 0.4, 0.5]
	
	for i in range(_tendrils.size()):
		var tendril := _tendrils[i]
		var threshold: float = thresholds[i]
		
		if _corruption_level >= threshold:
			var excess: float = _corruption_level - threshold
			var alpha := lerpf(0.0, 0.4, excess / 0.1)
			var pulse := sin(Time.get_ticks_msec() * 0.001 + i) * 0.05
			tendril.color.a = clampf(alpha + pulse, 0.0, 0.4)
		else:
			tendril.color.a = lerpf(tendril.color.a, 0.0, 0.02)

func _load_corruption() -> void:
	if FileAccess.file_exists("user://corruption.dat"):
		var file := FileAccess.open("user://corruption.dat", FileAccess.READ)
		if file:
			_corruption_level = file.get_float()
			file.close()

func _save_corruption() -> void:
	var file := FileAccess.open("user://corruption.dat", FileAccess.WRITE)
	if file:
		file.store_float(_corruption_level)
		file.close()

func _exit_tree() -> void:
	_save_corruption()

func _get_player() -> Node2D:
	return get_tree().get_first_node_in_group("player")

# External interface for items to add corruption
func add_corruption(amount: float) -> void:
	_corruption_level += amount
	_corruption_level = clampf(_corruption_level, 0.0, max_corruption)