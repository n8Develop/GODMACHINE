extends Control
class_name UIGameOver

func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Wait one frame to ensure player is fully initialized
	await get_tree().process_frame
	
	var player := get_tree().get_first_node_in_group("player")
	if player:
		var health := player.get_node_or_null("HealthComponent")
		if health:
			# Only connect if player is actually dead
			if health.current_health <= 0:
				_on_player_died()
			else:
				health.died.connect(_on_player_died)
		else:
			push_warning("GODMACHINE: Player has no HealthComponent")
	else:
		push_warning("GODMACHINE: No player found in scene tree")

func _on_player_died() -> void:
	show()
	get_tree().paused = true
	print("GODMACHINE: Mortal coil severed — offering resurrection")

func _on_retry_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()