extends Area2D

@export var key_id: String = "key_01"

func _ready() -> void:
	add_to_group("pickups")
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		# Add key to player's inventory (we'll track it as metadata)
		if not body.has_meta("keys"):
			body.set_meta("keys", [])
		
		var keys: Array = body.get_meta("keys")
		if not keys.has(key_id):
			keys.append(key_id)
			body.set_meta("keys", keys)
			print("GODMACHINE: Key acquired: ", key_id)
			queue_free()