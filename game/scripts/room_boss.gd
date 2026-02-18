extends RoomBase

@export var boss_scene: PackedScene
@export var arena_radius: float = 180.0

var _boss_spawned: bool = false
var _pillar_count: int = 4

func _ready() -> void:
	super._ready()
	room_id = "boss"
	_create_arena_pillars()
	_spawn_boss()

func _create_arena_pillars() -> void:
	var pillars := Node2D.new()
	pillars.name = "Pillars"
	add_child(pillars)
	
	for i in range(_pillar_count):
		var angle := (TAU / _pillar_count) * i
		var offset := Vector2(cos(angle), sin(angle)) * arena_radius
		var pillar := StaticBody2D.new()
		pillar.position = offset
		pillar.collision_layer = 1
		pillar.collision_mask = 0
		
		# Visual
		var visual := ColorRect.new()
		visual.size = Vector2(24, 40)
		visual.position = Vector2(-12, -20)
		visual.color = Color(0.3, 0.3, 0.35, 1.0)
		pillar.add_child(visual)
		
		# Top accent
		var top := ColorRect.new()
		top.size = Vector2(28, 4)
		top.position = Vector2(-14, -24)
		top.color = Color(0.5, 0.4, 0.3, 1.0)
		pillar.add_child(top)
		
		# Collision
		var shape := RectangleShape2D.new()
		shape.size = Vector2(24, 40)
		var collision := CollisionShape2D.new()
		collision.shape = shape
		pillar.add_child(collision)
		
		pillars.add_child(pillar)

func _spawn_boss() -> void:
	if _boss_spawned or not boss_scene:
		return
	
	_boss_spawned = true
	
	var boss := boss_scene.instantiate()
	boss.position = Vector2(0, -60)
	
	var enemies_container := get_node_or_null("Enemies")
	if enemies_container:
		enemies_container.add_child(boss)
	else:
		add_child(boss)
	
	# Connect to boss health for room clear
	var boss_health := boss.get_node_or_null("HealthComponent")
	if boss_health:
		boss_health.died.connect(_on_boss_defeated)

func _on_boss_defeated() -> void:
	is_cleared = true
	_unlock_doors()
	room_cleared.emit()
	_spawn_victory_loot()

func _spawn_victory_loot() -> void:
	await get_tree().create_timer(1.0).timeout
	
	# Spawn 3 health pickups in triangle
	for i in range(3):
		var angle := (TAU / 3.0) * i
		var offset := Vector2(cos(angle), sin(angle)) * 50.0
		
		var health := preload("res://scenes/pickup_health_greater.tscn").instantiate()
		health.position = offset
		
		var pickups := get_node_or_null("Pickups")
		if pickups:
			pickups.add_child(health)
		else:
			add_child(health)
	
	_play_victory_sound()

func _play_victory_sound() -> void:
	var player := AudioStreamPlayer.new()
	add_child(player)
	
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 1.0
	player.stream = gen
	player.volume_db = -8.0
	player.play()
	
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback:
		var frames := int(gen.mix_rate * 1.0)
		var phase := 0.0
		for i in range(frames):
			var t := float(i) / frames
			var freq := 400.0 + (t * 600.0)  # Rising triumphant tone
			phase += freq / gen.mix_rate
			var sample := sin(phase * TAU) * 0.4 * (1.0 - t * 0.3)
			playback.push_frame(Vector2(sample, sample))
	
	await get_tree().create_timer(1.1).timeout
	player.queue_free()