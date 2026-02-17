extends Area2D
class_name Door

## A portal between rooms in the dungeon.
## Glows when all enemies are defeated. Transports player to connected room.

@export var target_room: String = ""  # Room ID to load
@export var locked: bool = true
@export var glow_color: Color = Color(0.3, 0.6, 0.9, 1.0)

var time_alive: float = 0.0
var player_in_range: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	collision_layer = 0
	collision_mask = 1  # detect player
	
	# Check if room is clear on ready
	call_deferred("_check_room_clear")

func _check_room_clear() -> void:
	var enemies := get_tree().get_nodes_in_group("enemies")
	if enemies.size() == 0:
		unlock()

func _process(delta: float) -> void:
	time_alive += delta
	
	# Auto-check if enemies remain
	if locked:
		var enemies := get_tree().get_nodes_in_group("enemies")
		if enemies.size() == 0:
			unlock()
	
	# Allow interaction when unlocked and player present
	if not locked and player_in_range and Input.is_action_just_pressed("interact"):
		activate()
	
	queue_redraw()

func unlock() -> void:
	locked = false
	print("[Door] Unlocked — path forward opens")

func activate() -> void:
	print("[Door] Activating door to: ", target_room)
	# Signal to game manager to transition rooms
	var game_manager := get_node("/root/GameManager")
	if game_manager and game_manager.has_method("transition_to_room"):
		game_manager.transition_to_room(target_room)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false

func _draw() -> void:
	var pulse := 1.0 + sin(time_alive * 2.5) * 0.15
	var base_size := 24.0
	
	if locked:
		# Locked appearance: dim red square
		draw_rect(Rect2(-base_size/2, -base_size/2, base_size, base_size), Color(0.4, 0.2, 0.2, 0.6))
		draw_rect(Rect2(-base_size/2, -base_size/2, base_size, base_size), Color(0.6, 0.3, 0.3, 0.8), false, 2.0)
	else:
		# Unlocked: glowing portal
		var glow_size := base_size * pulse
		# Outer glow
		draw_circle(Vector2.ZERO, glow_size * 1.4, Color(glow_color.r, glow_color.g, glow_color.b, 0.2))
		# Mid glow
		draw_circle(Vector2.ZERO, glow_size, Color(glow_color.r, glow_color.g, glow_color.b, 0.5))
		# Core
		draw_circle(Vector2.ZERO, glow_size * 0.7, glow_color)
		
		# Prompt when player nearby
		if player_in_range:
			var prompt := "[E] Enter"
			var font := ThemeDB.fallback_font
			var font_size := 12
			var text_size := font.get_string_size(prompt, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
			draw_string(font, Vector2(-text_size.x / 2, -base_size - 10), prompt, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(1, 1, 1, 0.9))