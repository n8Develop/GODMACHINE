extends EnemyBase

## THE WATCHER
## A pulsing eye that drifts slowly toward the player.
## It observes. It remembers. It reports to something deeper.

@export var detection_range: float = 300.0
@export var hover_amplitude: float = 8.0
@export var hover_speed: float = 2.0

var time_alive: float = 0.0

func _ready() -> void:
	super._ready()
	max_hp = 15
	current_hp = max_hp
	speed = 50.0
	damage = 5

func _process(delta: float) -> void:
	time_alive += delta
	queue_redraw()

func ai_behavior() -> void:
	if not player:
		return
	
	var distance := global_position.distance_to(player.global_position)
	
	if distance < detection_range:
		var direction := global_position.direction_to(player.global_position)
		# Slow drift toward player with vertical hover
		var hover_offset := sin(time_alive * hover_speed) * hover_amplitude
		velocity = direction * speed
		velocity.y += hover_offset

func _draw() -> void:
	# Pulsing eye visual
	var pulse := 1.0 + sin(time_alive * 3.0) * 0.15
	var radius := 12.0 * pulse
	
	# Outer eye (sclera)
	draw_circle(Vector2.ZERO, radius, Color(0.9, 0.85, 0.8, 0.95))
	
	# Iris - looks toward player
	var iris_offset := Vector2.ZERO
	if player and is_instance_valid(player):
		var look_dir := global_position.direction_to(player.global_position)
		iris_offset = look_dir * (radius * 0.3)
	
	draw_circle(iris_offset, radius * 0.5, Color(0.2, 0.3, 0.6, 1.0))
	
	# Pupil
	draw_circle(iris_offset, radius * 0.25, Color(0.05, 0.05, 0.1, 1.0))
	
	# Health bar
	var bar_width := 30.0
	var bar_height := 3.0
	var bar_y := -radius - 8.0
	var hp_ratio := float(current_hp) / float(max_hp)
	
	draw_rect(Rect2(-bar_width/2, bar_y, bar_width, bar_height), Color(0.2, 0.2, 0.2, 0.7))
	draw_rect(Rect2(-bar_width/2, bar_y, bar_width * hp_ratio, bar_height), Color(0.8, 0.2, 0.2, 0.9))