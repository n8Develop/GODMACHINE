extends PickupBase

## Health pickup that spawns from defeated enemies.
## Restores HP to the player with a glowing red pulse.

@export var heal_amount: int = 15

func _ready() -> void:
	super._ready()
	pickup_radius = 12.0

func apply_effect(player: CharacterBody2D) -> void:
	if player.has_method("heal"):
		player.heal(heal_amount)
	else:
		# Fallback: direct HP manipulation
		if "current_hp" in player and "max_hp" in player:
			player.current_hp = mini(player.current_hp + heal_amount, player.max_hp)
			print("[Pickup] Player healed for ", heal_amount, " HP")

func _draw() -> void:
	var pulse := 1.0 + sin(time_alive * 4.0) * 0.2
	var radius := pickup_radius * pulse
	
	# Outer glow (red/pink)
	draw_circle(Vector2.ZERO, radius * 1.3, Color(0.9, 0.2, 0.3, 0.4))
	
	# Core orb
	draw_circle(Vector2.ZERO, radius, Color(0.95, 0.3, 0.35, 0.9))
	
	# Inner highlight
	draw_circle(Vector2(-3, -3), radius * 0.4, Color(1.0, 0.6, 0.6, 0.7))
	
	# Cross symbol (health icon)
	var cross_size := radius * 0.5
	var cross_thickness := 2.5
	draw_rect(Rect2(-cross_thickness/2, -cross_size, cross_thickness, cross_size * 2), Color(1.0, 0.9, 0.9, 0.95))
	draw_rect(Rect2(-cross_size, -cross_thickness/2, cross_size * 2, cross_thickness), Color(1.0, 0.9, 0.9, 0.95))