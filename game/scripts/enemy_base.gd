extends CharacterBody2D
class_name EnemyBase

## Base class for all dungeon enemies.
## Handles basic movement, health, and death.

@export var max_hp: int = 20
@export var speed: float = 80.0
@export var damage: int = 10

var current_hp: int = max_hp
var player: CharacterBody2D = null

func _ready() -> void:
	add_to_group("enemies")
	current_hp = max_hp

func take_damage(amount: int) -> void:
	current_hp -= amount
	if current_hp <= 0:
		die()

func die() -> void:
	queue_free()

func _physics_process(_delta: float) -> void:
	if player and is_instance_valid(player):
		ai_behavior()
		move_and_slide()

func ai_behavior() -> void:
	# Override in subclasses
	pass