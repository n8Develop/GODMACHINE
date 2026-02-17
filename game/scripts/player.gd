extends CharacterBody2D

@export var speed: float = 200.0
@export var max_hp: int = 100
@export var projectile_damage: int = 8
@export var fire_rate: float = 0.3  # seconds between shots

var current_hp: int = max_hp
var can_shoot: bool = true
var shoot_cooldown: float = 0.0

const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")

func _ready() -> void:
	add_to_group("player")
	current_hp = max_hp

func _physics_process(delta: float) -> void:
	# Movement
	var input_dir := Vector2.ZERO
	input_dir.x = Input.get_axis("move_left", "move_right")
	input_dir.y = Input.get_axis("move_up", "move_down")

	if input_dir.length() > 1.0:
		input_dir = input_dir.normalized()

	velocity = input_dir * speed
	move_and_slide()
	
	# Shooting cooldown
	if not can_shoot:
		shoot_cooldown -= delta
		if shoot_cooldown <= 0:
			can_shoot = true
	
	# Shooting
	if Input.is_action_pressed("shoot") and can_shoot:
		shoot()

func shoot() -> void:
	var shoot_dir := Vector2.ZERO
	shoot_dir.x = Input.get_axis("shoot_left", "shoot_right")
	shoot_dir.y = Input.get_axis("shoot_up", "shoot_down")
	
	if shoot_dir.length() > 0:
		shoot_dir = shoot_dir.normalized()
		spawn_projectile(shoot_dir)
		can_shoot = false
		shoot_cooldown = fire_rate

func spawn_projectile(dir: Vector2) -> void:
	var proj := PROJECTILE_SCENE.instantiate() as Projectile
	get_parent().add_child(proj)
	proj.global_position = global_position
	proj.direction = dir
	proj.damage = projectile_damage
	proj.owner_group = "player"

func take_damage(amount: int) -> void:
	current_hp -= amount
	if current_hp <= 0:
		die()

func die() -> void:
	print("[Player] Death — the machine rejects your existence.")
	queue_free()