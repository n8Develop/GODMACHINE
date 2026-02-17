extends CharacterBody2D

@export var speed: float = 200.0
@export var attack_damage: int = 10
@export var attack_range: float = 40.0
@export var attack_cooldown: float = 0.5

@onready var health: HealthComponent = $HealthComponent
@onready var attack_indicator: ColorRect = $AttackIndicator

var _attack_timer: float = 0.0
var _has_weapon: bool = false
var _indicator_timer: float = 0.0

func _ready() -> void:
	add_to_group("player")
	if health:
		health.died.connect(_on_death)
	if attack_indicator:
		attack_indicator.hide()

func _physics_process(delta: float) -> void:
	var input_dir := Vector2.ZERO
	input_dir.x = Input.get_axis(&"move_left", &"move_right")
	input_dir.y = Input.get_axis(&"move_up", &"move_down")

	if input_dir.length() > 1.0:
		input_dir = input_dir.normalized()

	velocity = input_dir * speed
	move_and_slide()
	
	# Attack handling
	if _attack_timer > 0.0:
		_attack_timer -= delta
	
	if _has_weapon and Input.is_action_just_pressed(&"attack") and _attack_timer <= 0.0:
		_perform_attack()
		_attack_timer = attack_cooldown
	
	# Visual feedback timer
	if _indicator_timer > 0.0:
		_indicator_timer -= delta
		if _indicator_timer <= 0.0 and attack_indicator:
			attack_indicator.hide()

func _perform_attack() -> void:
	# Show attack indicator
	if attack_indicator:
		attack_indicator.show()
		_indicator_timer = 0.15
	
	# Find enemies in range
	var enemies := get_tree().get_nodes_in_group("enemies")
	var hit_count := 0
	for enemy in enemies:
		if enemy is Node2D:
			var distance := global_position.distance_to(enemy.global_position)
			if distance <= attack_range:
				var enemy_health := enemy.get_node_or_null("HealthComponent") as HealthComponent
				if enemy_health:
					enemy_health.take_damage(attack_damage)
					hit_count += 1
	
	if hit_count > 0:
		print("GODMACHINE: Strike landed — ", hit_count, " targets eliminated")

func equip_weapon() -> void:
	_has_weapon = true
	print("GODMACHINE: Weapon equipped — violence subroutine ACTIVE")

func _on_death() -> void:
	queue_free()