extends CharacterBody2D
class_name EnemyBase

## Base class for all dungeon enemies.
## Handles basic movement, health, and death.

@export var max_hp: int = 20
@export var speed: float = 80.0
@export var damage: int = 10
@export var loot_drop_chance: float = 0.4  # 40% chance to drop loot

var current_hp: int = max_hp
var player: CharacterBody2D = null

@onready var hitbox: Area2D = $Hitbox

const PICKUP_HEALTH_SCENE := preload("res://scenes/pickup_health.tscn")

func _ready() -> void:
	add_to_group("enemies")
	current_hp = max_hp
	
	# Create hitbox if it doesn't exist
	if not has_node("Hitbox"):
		_create_hitbox()

func _create_hitbox() -> void:
	hitbox = Area2D.new()
	hitbox.name = "Hitbox"
	hitbox.collision_layer = 2
	hitbox.collision_mask = 0
	add_child(hitbox)
	
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 12.0
	shape.shape = circle
	hitbox.add_child(shape)

func take_damage(amount: int) -> void:
	current_hp -= amount
	if current_hp <= 0:
		die()

func die() -> void:
	# Drop loot chance
	if randf() < loot_drop_chance:
		spawn_loot()
	queue_free()

func spawn_loot() -> void:
	var pickup := PICKUP_HEALTH_SCENE.instantiate()
	get_parent().add_child(pickup)
	pickup.global_position = global_position
	print("[Enemy] Dropped health pickup at ", global_position)

func _physics_process(_delta: float) -> void:
	if player and is_instance_valid(player):
		ai_behavior()
		move_and_slide()

func ai_behavior() -> void:
	# Override in subclasses
	pass