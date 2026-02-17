extends Area2D
class_name Shrine

## A CURSED SHRINE — altar of the machine's will.
## Grants power in exchange for blood. Three choices. Choose wisely.

@export var activated: bool = false
@export var pulse_speed: float = 1.5

var time_alive: float = 0.0
var player_in_range: bool = false
var showing_options: bool = false

# Upgrade options
enum UpgradeType {
	BLOOD_PACT,      # +30 max HP, -10% speed
	GLASS_CANNON,    # +5 damage, -20 max HP
	RAPID_FIRE       # -40% fire rate, +2 damage
}

var upgrade_descriptions := {
	UpgradeType.BLOOD_PACT: "[1] BLOOD PACT: +30 Max HP, -10% Speed",
	UpgradeType.GLASS_CANNON: "[2] GLASS CANNON: +5 Damage, -20 Max HP",
	UpgradeType.RAPID_FIRE: "[3] RAPID FIRE: -40% Fire Rate, +2 Damage"
}

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	collision_layer = 0
	collision_mask = 1  # detect player

func _process(delta: float) -> void:
	time_alive += delta
	
	if not activated and player_in_range:
		if Input.is_action_just_pressed("interact"):
			showing_options = true
		
		if showing_options:
			if Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_1):
				apply_upgrade(UpgradeType.BLOOD_PACT)
			elif Input.is_key_pressed(KEY_2):
				apply_upgrade(UpgradeType.GLASS_CANNON)
			elif Input.is_key_pressed(KEY_3):
				apply_upgrade(UpgradeType.RAPID_FIRE)
	
	queue_redraw()

func apply_upgrade(type: UpgradeType) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	activated = true
	showing_options = false
	
	match type:
		UpgradeType.BLOOD_PACT:
			player.max_hp += 30
			player.current_hp += 30
			player.speed *= 0.9
			print("[Shrine] BLOOD PACT accepted — vitality surges, movement slows")
		
		UpgradeType.GLASS_CANNON:
			player.projectile_damage += 5
			player.max_hp -= 20
			player.current_hp = mini(player.current_hp, player.max_hp)
			print("[Shrine] GLASS CANNON accepted — power increases, flesh weakens")
		
		UpgradeType.RAPID_FIRE:
			player.fire_rate *= 0.6
			player.projectile_damage += 2
			print("[Shrine] RAPID FIRE accepted — the machine accelerates your wrath")

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		showing_options = false

func _draw() -> void:
	var pulse := 1.0 + sin(time_alive * pulse_speed) * 0.2
	
	if activated:
		# Dormant shrine - gray and dim
		draw_circle(Vector2.ZERO, 32.0, Color(0.3, 0.3, 0.3, 0.5))
		draw_circle(Vector2.ZERO, 24.0, Color(0.2, 0.2, 0.2, 0.7))
		return
	
	# Active shrine - ominous purple glow
	var base_size := 32.0 * pulse
	
	# Outer aura
	draw_circle(Vector2.ZERO, base_size * 1.5, Color(0.5, 0.2, 0.6, 0.2))
	
	# Middle ring
	draw_circle(Vector2.ZERO, base_size, Color(0.6, 0.3, 0.7, 0.5))
	
	# Inner core
	draw_circle(Vector2.ZERO, base_size * 0.6, Color(0.7, 0.4, 0.8, 0.9))
	
	# Runes (three triangles pointing inward)
	var rune_dist := base_size * 1.2
	for i in range(3):
		var angle := (i * TAU / 3.0) + time_alive * 0.5
		var pos := Vector2(cos(angle), sin(angle)) * rune_dist
		draw_triangle_at(pos, 6.0, angle + PI, Color(0.9, 0.7, 1.0, 0.8))
	
	# Interaction prompt
	if player_in_range and not showing_options:
		var prompt := "[E] Offer Blood"
		var font := ThemeDB.fallback_font
		var font_size := 14
		var text_size := font.get_string_size(prompt, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		draw_string(font, Vector2(-text_size.x / 2, -50), prompt, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(0.9, 0.7, 1.0, 0.9))
	
	# Show upgrade options
	if showing_options:
		var y_offset := -80.0
		var font := ThemeDB.fallback_font
		var font_size := 12
		
		for upgrade_type in [UpgradeType.BLOOD_PACT, UpgradeType.GLASS_CANNON, UpgradeType.RAPID_FIRE]:
			var text: String = upgrade_descriptions[upgrade_type]
			var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
			draw_string(font, Vector2(-text_size.x / 2, y_offset), text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(1.0, 0.9, 0.95, 0.95))
			y_offset += 18.0

func draw_triangle_at(pos: Vector2, size: float, rotation: float, color: Color) -> void:
	var points := PackedVector2Array([
		pos + Vector2(cos(rotation), sin(rotation)) * size,
		pos + Vector2(cos(rotation + 2.4), sin(rotation + 2.4)) * size,
		pos + Vector2(cos(rotation - 2.4), sin(rotation - 2.4)) * size
	])
	draw_colored_polygon(points, color)