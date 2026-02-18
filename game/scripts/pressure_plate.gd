extends Area2D

signal activated
signal deactivated

@export var plate_id: String = "plate_1"
@export var required_weight: int = 1  # Number of entities needed

var _current_weight: int = 0
var _is_active: bool = false

@onready var visual: ColorRect = $Visual
@onready var indicator: ColorRect = $Indicator

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_update_visual()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.is_in_group("enemies"):
		_current_weight += 1
		_check_activation()

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") or body.is_in_group("enemies"):
		_current_weight -= 1
		_check_activation()

func _check_activation() -> void:
	var should_be_active := _current_weight >= required_weight
	
	if should_be_active and not _is_active:
		_is_active = true
		activated.emit()
		_update_visual()
		print("GODMACHINE: Plate ", plate_id, " activated")
	elif not should_be_active and _is_active:
		_is_active = false
		deactivated.emit()
		_update_visual()
		print("GODMACHINE: Plate ", plate_id, " deactivated")

func _update_visual() -> void:
	if _is_active:
		visual.color = Color(0.2, 0.8, 0.3, 1.0)  # Green when active
		indicator.color = Color(0.3, 1.0, 0.4, 1.0)
	else:
		visual.color = Color(0.5, 0.5, 0.5, 1.0)  # Gray when inactive
		indicator.color = Color(0.7, 0.7, 0.7, 0.6)