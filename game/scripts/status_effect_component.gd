extends Node
class_name StatusEffectComponent

## Universal status effect system. Attach to any entity to track duration-based effects.
## Emits signals and sets metadata for UI consumption.

signal effect_applied(effect_name: StringName, duration: float)
signal effect_expired(effect_name: StringName)
signal effect_tick(effect_name: StringName, intensity: float)

## Active effects: { effect_name: { duration: float, tick_interval: float, tick_timer: float, intensity: float } }
var _active_effects: Dictionary = {}

func _ready() -> void:
	# Ensure parent can be queried by UI
	if get_parent():
		get_parent().set_meta(&"has_status_effects", true)

func _process(delta: float) -> void:
	var expired: Array[StringName] = []
	
	for effect_name in _active_effects.keys():
		var effect: Dictionary = _active_effects[effect_name]
		effect.duration -= delta
		
		# Tick damage/healing if applicable
		if effect.has("tick_interval"):
			effect.tick_timer -= delta
			if effect.tick_timer <= 0.0:
				effect.tick_timer = effect.tick_interval
				effect_tick.emit(effect_name, effect.intensity)
				_apply_tick_effect(effect_name, effect.intensity)
		
		# Set metadata for UI polling
		if get_parent():
			get_parent().set_meta("status_" + effect_name, effect.duration)
		
		if effect.duration <= 0.0:
			expired.append(effect_name)
	
	# Clean up expired effects
	for effect_name in expired:
		_remove_effect(effect_name)

func apply_effect(effect_name: StringName, duration: float, intensity: float = 1.0, tick_interval: float = 0.0) -> void:
	"""
	Apply or refresh a status effect.
	- effect_name: poison, burning, frozen, blessed, cursed, etc.
	- duration: how long it lasts (seconds)
	- intensity: damage/heal per tick, or magnitude for non-ticking effects
	- tick_interval: time between ticks (0 = no ticking)
	"""
	if _active_effects.has(effect_name):
		# Refresh duration if already active
		_active_effects[effect_name].duration = maxf(_active_effects[effect_name].duration, duration)
	else:
		_active_effects[effect_name] = {
			"duration": duration,
			"intensity": intensity,
			"tick_interval": tick_interval,
			"tick_timer": tick_interval
		}
		effect_applied.emit(effect_name, duration)
		
		# Set initial metadata
		if get_parent():
			get_parent().set_meta("status_" + effect_name, duration)

func remove_effect(effect_name: StringName) -> void:
	"""Manually remove an effect early."""
	_remove_effect(effect_name)

func has_effect(effect_name: StringName) -> bool:
	return _active_effects.has(effect_name)

func get_effect_duration(effect_name: StringName) -> float:
	if _active_effects.has(effect_name):
		return _active_effects[effect_name].duration
	return 0.0

func _remove_effect(effect_name: StringName) -> void:
	_active_effects.erase(effect_name)
	effect_expired.emit(effect_name)
	
	# Clear metadata
	if get_parent():
		get_parent().remove_meta("status_" + effect_name)

func _apply_tick_effect(effect_name: StringName, intensity: float) -> void:
	"""Apply damage/healing based on effect type."""
	var parent := get_parent()
	if not parent:
		return
	
	var health_comp := parent.get_node_or_null("HealthComponent")
	if not health_comp:
		return
	
	match effect_name:
		&"poison", &"burning":
			health_comp.take_damage(int(intensity))
		&"blessed":
			health_comp.heal(int(intensity))