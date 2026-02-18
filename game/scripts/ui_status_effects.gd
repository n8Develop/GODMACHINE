extends Control
class_name UIStatusEffects

@onready var grid: GridContainer = $Grid

var _active_effects: Dictionary = {}  # effect_name -> {icon: ColorRect, timer: float}

const EFFECT_COLORS := {
	"poisoned": Color(0.4, 0.9, 0.2, 0.9),
	"burning": Color(1.0, 0.4, 0.1, 0.9),
	"frozen": Color(0.3, 0.7, 1.0, 0.9),
	"blessed": Color(1.0, 0.9, 0.3, 0.9),
	"cursed": Color(0.6, 0.2, 0.8, 0.9),
}

func _ready() -> void:
	if not grid:
		grid = GridContainer.new()
		grid.name = "Grid"
		grid.columns = 5
		add_child(grid)
	
	# Position below health bar
	anchor_left = 0.0
	anchor_top = 0.0
	offset_left = 20.0
	offset_top = 70.0
	offset_right = 270.0
	offset_bottom = 110.0

func _process(delta: float) -> void:
	# Check player for status effects
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	# Poll for effect metadata
	for effect_name in EFFECT_COLORS.keys():
		var has_effect: bool = player.get_meta("status_" + effect_name, false)
		var duration: float = player.get_meta("status_" + effect_name + "_duration", 0.0)
		
		if has_effect and duration > 0.0:
			if not _active_effects.has(effect_name):
				_add_effect_icon(effect_name)
			
			# Update timer
			_active_effects[effect_name].timer -= delta
			if _active_effects[effect_name].timer <= 0.0:
				# Effect expired
				player.set_meta("status_" + effect_name, false)
				_remove_effect_icon(effect_name)
			else:
				# Pulse effect when low duration
				var icon: ColorRect = _active_effects[effect_name].icon
				if _active_effects[effect_name].timer < 2.0:
					var pulse := abs(sin(Time.get_ticks_msec() * 0.008))
					icon.modulate.a = 0.5 + (pulse * 0.5)
				else:
					icon.modulate.a = 1.0
		else:
			if _active_effects.has(effect_name):
				_remove_effect_icon(effect_name)

func _add_effect_icon(effect_name: String) -> void:
	var icon := ColorRect.new()
	icon.custom_minimum_size = Vector2(32, 32)
	icon.color = EFFECT_COLORS.get(effect_name, Color.WHITE)
	
	# Add a border
	var border := ColorRect.new()
	border.anchor_left = 0.0
	border.anchor_top = 0.0
	border.anchor_right = 1.0
	border.anchor_bottom = 1.0
	border.offset_left = 2
	border.offset_top = 2
	border.offset_right = -2
	border.offset_bottom = -2
	border.color = Color(0.1, 0.1, 0.1, 1.0)
	border.z_index = -1
	icon.add_child(border)
	
	grid.add_child(icon)
	
	var player := get_tree().get_first_node_in_group("player")
	var duration: float = player.get_meta("status_" + effect_name + "_duration", 3.0)
	
	_active_effects[effect_name] = {
		"icon": icon,
		"timer": duration
	}

func _remove_effect_icon(effect_name: String) -> void:
	if _active_effects.has(effect_name):
		var icon: ColorRect = _active_effects[effect_name].icon
		icon.queue_free()
		_active_effects.erase(effect_name)