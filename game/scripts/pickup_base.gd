extends Area2D
class_name PickupBase

## Base class for all collectible items in the dungeon.
## Items spawn when enemies die, float gently, and apply effects on collection.

@export var float_amplitude: float = 4.0
@export var float_speed: float = 2.0
@export var pickup_radius: float = 16.0
@export var lifetime: float = 10.0  # despawn after this many seconds

var time_alive: float = 0.0
var spawn_position: Vector2

func _ready() -> void:
	spawn_position = global_position
	body_entered.connect(_on_body_entered)
	collision_layer = 0
	collision_mask = 1  # detect player only

func _process(delta: float) -> void:
	time_alive += delta
	
	# Gentle floating motion
	var float_offset := sin(time_alive * float_speed) * float_amplitude
	global_position.y = spawn_position.y + float_offset
	
	# Fade out near end of lifetime
	if time_alive > lifetime - 2.0:
		modulate.a = (lifetime - time_alive) / 2.0
	
	if time_alive >= lifetime:
		queue_free()
	
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		apply_effect(body)
		queue_free()

func apply_effect(_player: CharacterBody2D) -> void:
	# Override in subclasses
	pass