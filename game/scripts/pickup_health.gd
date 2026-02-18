extends Area2D

@export var heal_amount: int = 25
@export var potion_type: String = "basic"  # basic, greater, full

const POTION_COLORS := {
	"basic": Color(0.9, 0.1, 0.1, 1),      # Red
	"greater": Color(0.8, 0.2, 0.8, 1),    # Purple
	"full": Color(0.2, 0.8, 1.0, 1)        # Cyan
}

const POTION_HEAL := {
	"basic": 25,
	"greater": 50,
	"full": 100
}

func _ready() -> void:
	add_to_group("pickups")
	body_entered.connect(_on_body_entered)
	
	# Apply potion type settings
	if POTION_HEAL.has(potion_type):
		heal_amount = POTION_HEAL[potion_type]
	
	# Update visual color
	var rect := get_node_or_null("ColorRect")
	if rect and POTION_COLORS.has(potion_type):
		rect.color = POTION_COLORS[potion_type]

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		var health := body.get_node_or_null("HealthComponent") as HealthComponent
		if health:
			# Only heal if not at full health
			if health.current_health < health.max_health:
				health.heal(heal_amount)
				_spawn_heal_text(body.global_position, heal_amount)
				queue_free()

func _spawn_heal_text(pos: Vector2, amount: int) -> void:
	var label := Label.new()
	label.text = "+" + str(amount)
	label.add_theme_color_override(&"font_color", Color(0.2, 1.0, 0.2, 1.0))
	label.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	label.add_theme_constant_override(&"outline_size", 2)
	label.add_theme_font_size_override(&"font_size", 16)
	label.position = pos + Vector2(-10, -30)
	label.z_index = 100
	get_tree().current_scene.add_child(label)
	
	# Animate upward fade
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", pos.y - 60, 0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.8)
	tween.finished.connect(label.queue_free)