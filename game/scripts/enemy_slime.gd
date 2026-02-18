extends CharacterBody2D

@export var hop_force: float = 80.0
@export var hop_interval: float = 1.8
@export var detection_range: float = 200.0
@export var is_poisonous: bool = false
@export var poison_damage: int = 2
@export var poison_duration: float = 5.0
@export var contact_damage: int = 5

@onready var health: HealthComponent = $HealthComponent

var _hop_timer: float = 0.0
var _contact_area: Area2D

func _ready() -> void:
	add_to_group("enemies")
	if health:
		health.died.connect(_on_died)
	
	_contact_area = Area2D.new()
	_contact_area.collision_layer = 0
	_contact_area.collision_mask = 2
	add_child(_contact_area)
	
	var shape := CircleShape2D.new()
	shape.radius = 20.0
	var collision := CollisionShape2D.new()
	collision.shape = shape
	_contact_area.add_child(collision)
	
	_contact_area.body_entered.connect(_apply_contact_effects)

func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	
	_hop_timer += delta
	if _hop_timer >= hop_interval:
		_hop_timer = 0.0
		
		if player:
			var distance := global_position.distance_to(player.global_position)
			if distance <= detection_range:
				var direction := global_position.direction_to(player.global_position)
				velocity = direction * hop_force
			else:
				var random_angle := randf() * TAU
				velocity = Vector2(cos(random_angle), sin(random_angle)) * (hop_force * 0.5)
		else:
			var random_angle := randf() * TAU
			velocity = Vector2(cos(random_angle), sin(random_angle)) * (hop_force * 0.5)
	
	velocity.y += 300.0 * delta
	move_and_slide()
	velocity.x *= 0.95
	velocity.y *= 0.95

func _apply_contact_effects(player: Node2D) -> void:
	if not player.is_in_group("player"):
		return
	
	var player_health := player.get_node_or_null("HealthComponent") as HealthComponent
	if not player_health:
		return
	
	player_health.take_damage(contact_damage)
	
	if is_poisonous:
		var status := player.get_node_or_null("StatusEffectComponent") as StatusEffectComponent
		if status:
			status.apply_effect("poison", poison_duration, poison_damage, 1.0)
			_spawn_poison_text(player.global_position)

func _spawn_poison_text(pos: Vector2) -> void:
	var label := Label.new()
	label.text = "POISON"
	label.add_theme_color_override(&"font_color", Color(0.3, 0.9, 0.2, 1.0))
	label.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	label.add_theme_constant_override(&"outline_size", 2)
	label.add_theme_font_size_override(&"font_size", 14)
	label.position = pos + Vector2(-20, -30)
	label.z_index = 100
	get_tree().current_scene.add_child(label)
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", pos.y - 50, 0.6)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.finished.connect(label.queue_free)

func _on_died() -> void:
	# Spawn death particles
	var particle_count := 6
	var particle_color := Color(0.2, 0.8, 0.1, 1.0) if not is_poisonous else Color(0.3, 0.9, 0.2, 1.0)
	
	for i in range(particle_count):
		var particle := ColorRect.new()
		particle.size = Vector2(8, 8)
		particle.position = global_position + Vector2(-4, -4)
		particle.color = particle_color
		particle.z_index = 50
		get_tree().current_scene.add_child(particle)
		
		var angle := (TAU / particle_count) * i
		var speed := randf_range(40.0, 80.0)
		var velocity := Vector2(cos(angle), sin(angle)) * speed
		
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "position", global_position + velocity * 0.4, 0.7)
		tween.tween_property(particle, "modulate:a", 0.0, 0.7)
		tween.finished.connect(particle.queue_free)
	
	queue_free()