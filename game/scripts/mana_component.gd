extends Node
class_name ManaComponent

signal mana_changed(new_mana: int)
signal mana_max_changed(new_max: int)
signal mana_depleted

@export var max_mana: int = 100
@export var regen_per_second: float = 5.0
@export var regen_delay: float = 2.0  # Delay after spending before regen starts

var current_mana: int = 100
var _regen_timer: float = 0.0

func _ready() -> void:
	current_mana = max_mana
	mana_changed.emit(current_mana)
	mana_max_changed.emit(max_mana)

func _process(delta: float) -> void:
	if current_mana < max_mana:
		if _regen_timer > 0.0:
			_regen_timer -= delta
		else:
			var regen_amount := regen_per_second * delta
			current_mana = mini(current_mana + int(regen_amount), max_mana)
			mana_changed.emit(current_mana)

func spend(amount: int) -> bool:
	if current_mana >= amount:
		current_mana -= amount
		_regen_timer = regen_delay
		mana_changed.emit(current_mana)
		if current_mana == 0:
			mana_depleted.emit()
		return true
	return false

func restore(amount: int) -> void:
	current_mana = mini(current_mana + amount, max_mana)
	mana_changed.emit(current_mana)

func set_max_mana(new_max: int) -> void:
	max_mana = new_max
	current_mana = mini(current_mana, max_mana)
	mana_max_changed.emit(max_mana)
	mana_changed.emit(current_mana)