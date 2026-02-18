extends CharacterBody2D

@export var hop_force: float = 80.0
@export var hop_interval: float = 1.8
@export var detection_range: float = 200.0
@export var is_poisonous: bool = false
@export var poison_damage: int = 2
@export var poison_duration: float = 5.0
@export var contact_damage: int = 5

var _hop_timer: float = 0.0
var _target_pos: Vector2 = Vector2.ZERO
var _idle_timer: float = 0.0

func _ready() -> void:
	add_to_group("enemies")
	_hop_timer = randf_range(0.0, hop_interval)
	
	var health := get_node_or_null("HealthComponent") as HealthComponent
	if health:
		health.died.connect(_on_died)
	
	# Visual feedback for poison variant
	if is_poisonous:
		var sprite := get_node_or_null("ColorRect")
		if sprite:
			sprite.color = Color(0.4, 0.8, 0.2, 1.0)  # Sickly green

func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if not player:
		return
	
	var distance := global_position.distance_to(player.global_position)
	
	if distance <= detection_range:
		_target_pos = player.global_position
		_hop_timer += delta
		
		if _hop_timer >= hop_interval:
			_hop_timer = 0.0
			var dir := global_position.direction_to(_target_pos)
			velocity = dir * hop_force
	else:
		velocity = velocity.lerp(Vector2.ZERO, delta * 3.0)
	
	move_and_slide()
	
	# Contact damage check
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()
		if collider and collider.is_in_group("player"):
			_apply_contact_effects(collider)

func _apply_contact_effects(player: Node2D) -> void:
	# Apply damage
	var player_health := player.get_node_or_null("HealthComponent") as HealthComponent
	if player_health:
		player_health.take_damage(contact_damage)
	
	# Apply poison if this is a poison variant
	if is_poisonous:
		var status := player.get_node_or_null("StatusEffectComponent") as Node
		if status and status.has_method("apply_effect"):
			status.apply_effect("poisoned", poison_duration, poison_damage, 1.0)
			_spawn_poison_text(player.global_position)

func _spawn_poison_text(pos: Vector2) -> void:
	var label := Label.new()
	label.text = "POISONED"
	label.add_theme_color_override(&"font_color", Color(0.4, 1.0, 0.3, 1.0))
	label.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	label.add_theme_constant_override(&"outline_size", 2)
	label.add_theme_font_size_override(&"font_size", 16)
	label.position = pos + Vector2(-30, -40)
	label.z_index = 100
	get_parent().add_child(label)
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", pos.y - 70, 0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.8)
	tween.finished.connect(label.queue_free)

func _on_died() -> void:
	queue_free()