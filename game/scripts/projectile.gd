extends Area2D
class_name Projectile

## A magical projectile fired by the player or enemies.
## Travels in a direction, damages on hit, and expires after distance/time.

@export var speed: float = 400.0
@export var damage: int = 10
@export var max_distance: float = 500.0
@export var lifetime: float = 3.0
@export var piercing: bool = false

var direction: Vector2 = Vector2.RIGHT
var distance_traveled: float = 0.0
var time_alive: float = 0.0
var owner_group: String = ""  # "player" or "enemies"

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _process(delta: float) -> void:
	time_alive += delta
	if time_alive > lifetime:
		queue_free()
		return
	
	var movement := direction * speed * delta
	position += movement
	distance_traveled += movement.length()
	
	if distance_traveled > max_distance:
		queue_free()
	
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	# Hit walls
	if body is StaticBody2D:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	# Damage enemies or player
	if owner_group == "player" and area.get_parent() is EnemyBase:
		var enemy := area.get_parent() as EnemyBase
		enemy.take_damage(damage)
		if not piercing:
			queue_free()

func _draw() -> void:
	# Glowing orb visual
	var pulse := 1.0 + sin(time_alive * 15.0) * 0.2
	var radius := 4.0 * pulse
	
	# Glow
	draw_circle(Vector2.ZERO, radius * 1.5, Color(0.6, 0.8, 1.0, 0.3))
	# Core
	draw_circle(Vector2.ZERO, radius, Color(0.8, 0.95, 1.0, 0.95))
	# Trail effect
	for i in range(3):
		var trail_pos := -direction * (i + 1) * 6.0
		var trail_alpha := 0.4 - (i * 0.12)
		draw_circle(trail_pos, radius * 0.7, Color(0.6, 0.8, 1.0, trail_alpha))