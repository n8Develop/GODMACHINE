extends Node2D
class_name PlayerDeathGhost

@export var fade_duration: float = 3.0
@export var drift_speed: float = 15.0

var _lifetime: float = 0.0
var _drift_direction: Vector2 = Vector2.ZERO

func _ready() -> void:
	# Random upward drift
	_drift_direction = Vector2(randf_range(-0.3, 0.3), -1.0).normalized()
	
	# Create visual
	var sprite := ColorRect.new()
	sprite.size = Vector2(32, 32)
	sprite.position = Vector2(-16, -16)
	sprite.color = Color(0.3, 0.9, 0.5, 0.4)
	add_child(sprite)
	
	# Fade out over time
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, fade_duration)
	tween.finished.connect(queue_free)

func _physics_process(delta: float) -> void:
	_lifetime += delta
	position += _drift_direction * drift_speed * delta
	
	# Gentle wave motion
	var wave := sin(_lifetime * 2.0) * 8.0
	position.x += wave * delta