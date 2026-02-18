extends Control
class_name UIFuelGauge

@onready var _gauge_bar: ColorRect = null
@onready var _flicker_overlay: ColorRect = null
@onready var _label: Label = null
@onready var _warning_pulse: float = 0.0

func _ready() -> void:
	# Position in lower-right corner
	anchors_preset = Control.PRESET_BOTTOM_RIGHT
	offset_left = -140
	offset_top = -50
	offset_right = -20
	offset_bottom = -20
	
	_create_visuals()

func _create_visuals() -> void:
	# Background
	var bg := ColorRect.new()
	bg.size = Vector2(100, 20)
	bg.color = Color(0.1, 0.1, 0.12, 0.8)
	add_child(bg)
	
	# Fuel bar
	_gauge_bar = ColorRect.new()
	_gauge_bar.position = Vector2(2, 2)
	_gauge_bar.size = Vector2(96, 16)
	_gauge_bar.color = Color(1.0, 0.7, 0.2, 1.0)
	add_child(_gauge_bar)
	
	# Flicker overlay for low fuel warning
	_flicker_overlay = ColorRect.new()
	_flicker_overlay.position = Vector2(2, 2)
	_flicker_overlay.size = Vector2(96, 16)
	_flicker_overlay.color = Color(1.0, 0.2, 0.1, 0.0)
	add_child(_flicker_overlay)
	
	# Label
	_label = Label.new()
	_label.text = "FUEL"
	_label.add_theme_color_override(&"font_color", Color(0.9, 0.9, 0.8, 1.0))
	_label.add_theme_font_size_override(&"font_size", 10)
	_label.position = Vector2(4, -16)
	add_child(_label)

func _process(delta: float) -> void:
	var player := _get_player()
	if not player:
		return
	
	var fuel := player.get_meta("torch_fuel", 0.0) as float
	var max_fuel := player.get_meta("torch_max_fuel", 60.0) as float
	var has_light := player.get_meta("has_torch", false) or player.get_meta("is_lantern", false)
	
	# Only show if player has a light source
	visible = has_light
	
	if not visible:
		return
	
	var fuel_percent := fuel / max_fuel if max_fuel > 0.0 else 0.0
	
	# Update bar width
	_gauge_bar.size.x = 96.0 * fuel_percent
	
	# Change color based on fuel level
	if fuel_percent > 0.5:
		_gauge_bar.color = Color(1.0, 0.7, 0.2, 1.0)  # Orange
	elif fuel_percent > 0.25:
		_gauge_bar.color = Color(1.0, 0.5, 0.1, 1.0)  # Darker orange
	else:
		_gauge_bar.color = Color(1.0, 0.2, 0.1, 1.0)  # Red
	
	# Warning pulse when fuel is critical
	if fuel_percent < 0.2:
		_warning_pulse += delta * 4.0
		var pulse := (sin(_warning_pulse) * 0.5 + 0.5)
		_flicker_overlay.color.a = pulse * 0.4
		_label.modulate = Color(1.0, 1.0, 1.0, 0.6 + pulse * 0.4)
	else:
		_flicker_overlay.color.a = 0.0
		_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	
	# Update label text based on type
	if player.get_meta("is_lantern", false):
		_label.text = "LANTERN"
	else:
		_label.text = "TORCH"

func _get_player() -> Node2D:
	var main := get_tree().current_scene
	if not main:
		return null
	return main.get_node_or_null("Player")