extends CharacterBody2D

@export var hop_force: float = 80.0
@export var hop_interval: float = 1.8
@export var detection_range: float = 200.0

var _hop_timer: float = 0.0
var _player: Node2D = null

func _ready() -> void:
	add_to_group("enemies")
	_hop_timer = randf_range(0.0, hop_interval)

func _physics_process(delta: float) -> void:
	if not _player:
		_player = get_tree().get_first_node_in_group("player")
		if not _player:
			return
	
	var distance := global_position.distance_to(_player.global_position)
	if distance > detection_range:
		return
	
	_hop_timer += delta
	if _hop_timer >= hop_interval:
		_hop_timer = 0.0
		var dir := global_position.direction_to(_player.global_position)
		velocity = dir * hop_force
	
	move_and_slide()