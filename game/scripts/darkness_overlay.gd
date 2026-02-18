extends CanvasLayer

var _darkness: ColorRect
var _torch_light: ColorRect
var _torch_active: bool = false
var _torch_fuel: float = 100.0
var _max_fuel: float = 100.0
var _fuel_drain_rate: float = 10.0  # per second
var _light_flicker_phase: float = 0.0

func _ready() -> void:
	layer = 100
	
	# Full-screen darkness
	_darkness = ColorRect.new()
	_darkness.color = Color(0.0, 0.0, 0.05, 0.85)
	_darkness.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_darkness.anchor_right = 1.0
	_darkness.anchor_bottom = 1.0
	add_child(_darkness)
	
	# Torch light (radial gradient simulated)
	_torch_light = ColorRect.new()
	_torch_light.size = Vector2(400, 400)
	_torch_light.position = Vector2(-200, -200)
	_torch_light.color = Color(1.0, 0.8, 0.4, 0.0)
	_torch_light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_torch_light.z_index = 1
	_darkness.add_child(_torch_light)
	
	# Fuel bar
	var fuel_bar := ColorRect.new()
	fuel_bar.name = "FuelBar"
	fuel_bar.color = Color(1.0, 0.6, 0.2, 0.8)
	fuel_bar.position = Vector2(20, 90)
	fuel_bar.size = Vector2(160, 8)
	add_child(fuel_bar)
	
	var fuel_label := Label.new()
	fuel_label.text = "TORCH"
	fuel_label.position = Vector2(20, 75)
	fuel_label.add_theme_font_size_override(&"font_size", 10)
	fuel_label.add_theme_color_override(&"font_color", Color(1.0, 0.8, 0.4, 1.0))
	add_child(fuel_label)

func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not player or not is_instance_valid(player):
		return
	
	# Check if player has torch item
	_torch_active = player.get_meta("has_torch", false)
	
	if _torch_active and _torch_fuel > 0.0:
		_torch_fuel -= _fuel_drain_rate * delta
		if _torch_fuel < 0.0:
			_torch_fuel = 0.0
		
		# Position light at player
		var viewport_size := get_viewport().get_visible_rect().size
		var player_screen_pos := player.get_global_transform_with_canvas().origin
		_torch_light.position = player_screen_pos - Vector2(200, 200)
		
		# Flicker effect
		_light_flicker_phase += delta * 8.0
		var flicker := 0.7 + (sin(_light_flicker_phase) * 0.15)
		var fuel_factor := clamp(_torch_fuel / _max_fuel, 0.3, 1.0)
		_torch_light.color.a = flicker * fuel_factor
		
		# Update darkness opacity based on fuel
		_darkness.color.a = 0.85 - (fuel_factor * 0.5)
	else:
		_torch_light.color.a = 0.0
		_darkness.color.a = 0.85
	
	# Update fuel bar
	var fuel_bar := get_node_or_null("FuelBar")
	if fuel_bar:
		var max_width := 160.0
		fuel_bar.size.x = max_width * (_torch_fuel / _max_fuel)
		fuel_bar.visible = _torch_active

func refuel(amount: float) -> void:
	_torch_fuel = min(_torch_fuel + amount, _max_fuel)