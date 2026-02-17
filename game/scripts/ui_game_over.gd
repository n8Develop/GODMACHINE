extends Control
class_name UIGameOver

@onready var retry_button: Button = $Panel/VBoxContainer/RetryButton
@onready var message_label: Label = $Panel/VBoxContainer/MessageLabel

func _ready() -> void:
	hide()
	retry_button.pressed.connect(_on_retry_pressed)
	
	# Connect to player death
	var player := get_tree().get_first_node_in_group("player")
	if player:
		var health := player.get_node_or_null("HealthComponent") as HealthComponent
		if health:
			health.died.connect(_on_player_died)

func _on_player_died() -> void:
	show()
	get_tree().paused = true
	retry_button.grab_focus()

func _on_retry_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()