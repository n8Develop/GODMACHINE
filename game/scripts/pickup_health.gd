extends Area2D

@export var heal_amount: int = 25

func _ready() -> void:
	add_to_group("pickups")
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		var health := body.get_node_or_null("HealthComponent") as HealthComponent
		if health:
			health.heal(heal_amount)
			queue_free()