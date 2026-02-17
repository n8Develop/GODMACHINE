extends Area2D

@export var weapon_name: String = "Iron Sword"

func _ready() -> void:
	add_to_group("pickups")
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("equip_weapon"):
		body.equip_weapon()
		print("GODMACHINE: ", weapon_name, " acquired")
		queue_free()