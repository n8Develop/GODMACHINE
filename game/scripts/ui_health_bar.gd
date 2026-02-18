extends Control
class_name UIHealthBar

@onready var health_fill: ColorRect = $HealthFill
@onready var health_label: Label = $HealthLabel
@onready var mana_fill: ColorRect = null
@onready var mana_label: Label = null
@onready var enemy_counter: Label = null
@onready var boss_bar_container: Control = null
@onready var boss_fill: ColorRect = null
@onready var boss_label: Label = null

var _current_health: int = 100
var _max_health: int = 100

func _ready() -> void:
	_create_enemy_counter()
	_create_mana_bar()
	_create_boss_bar()
	
	# Wait one frame for player to exist
	await get_tree().process_frame
	
	var player := get_tree().get_first_node_in_group("player")
	if player:
		var health_comp := player.get_node_or_null("HealthComponent")
		if health_comp:
			health_comp.health_changed.connect(_on_health_changed)
			health_comp.max_health_changed.connect(_on_max_health_changed)
			_current_health = health_comp.current_health
			_max_health = health_comp.max_health
			_update_display()
		
		var status_comp := player.get_node_or_null("StatusEffectComponent")
		if status_comp:
			status_comp.died.connect(func(): get_tree().call_group("ui", "_on_player_died"))

func _process(_delta: float) -> void:
	_update_enemy_counter()
	_update_mana_display()

func _create_enemy_counter() -> void:
	enemy_counter = Label.new()
	enemy_counter.position = Vector2(200, 0)
	enemy_counter.size = Vector2(120, 40)
	enemy_counter.add_theme_font_size_override(&"font_size", 16)
	enemy_counter.add_theme_color_override(&"font_color", Color(1.0, 0.3, 0.3, 1.0))
	enemy_counter.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	enemy_counter.add_theme_constant_override(&"outline_size", 2)
	enemy_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	enemy_counter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(enemy_counter)
	
	# Add skull icon
	var skull := ColorRect.new()
	skull.size = Vector2(24, 24)
	skull.position = Vector2(200, 8)
	skull.color = Color(0.9, 0.2, 0.2, 1.0)
	skull.z_index = -1
	add_child(skull)
	
	# Add "THREAT" label above counter
	var threat_label := Label.new()
	threat_label.text = "THREAT"
	threat_label.position = Vector2(230, -8)
	threat_label.add_theme_font_size_override(&"font_size", 10)
	threat_label.add_theme_color_override(&"font_color", Color(0.7, 0.7, 0.7, 1.0))
	threat_label.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	threat_label.add_theme_constant_override(&"outline_size", 1)
	add_child(threat_label)

func _update_enemy_counter() -> void:
	if not enemy_counter:
		return
	
	var enemies := get_tree().get_nodes_in_group("enemies")
	var spawners := get_tree().get_nodes_in_group("spawners")
	var total_threat := enemies.size() + (spawners.size() * 2)  # Spawners count as 2x threat
	
	var color := Color(1.0, 0.3, 0.3, 1.0)
	if total_threat >= 8:
		color = Color(1.0, 0.1, 0.1, 1.0)  # Critical red
	elif total_threat >= 5:
		color = Color(1.0, 0.5, 0.1, 1.0)  # Warning orange
	elif total_threat <= 0:
		color = Color(0.3, 1.0, 0.3, 1.0)  # Safe green
	
	enemy_counter.add_theme_color_override(&"font_color", color)
	
	if spawners.size() > 0:
		enemy_counter.text = "  %d (%d spawners)" % [enemies.size(), spawners.size()]
	else:
		enemy_counter.text = "  %d" % enemies.size()

func _create_mana_bar() -> void:
	mana_fill = ColorRect.new()
	mana_fill.position = Vector2(0, 44)
	mana_fill.size = Vector2(180, 12)
	mana_fill.color = Color(0.2, 0.4, 1.0, 1.0)
	add_child(mana_fill)
	
	var mana_bg := ColorRect.new()
	mana_bg.position = Vector2(0, 44)
	mana_bg.size = Vector2(180, 12)
	mana_bg.color = Color(0.1, 0.1, 0.15, 1.0)
	mana_bg.z_index = -1
	add_child(mana_bg)
	
	mana_label = Label.new()
	mana_label.position = Vector2(0, 40)
	mana_label.size = Vector2(180, 20)
	mana_label.add_theme_font_size_override(&"font_size", 10)
	mana_label.add_theme_color_override(&"font_color", Color(0.8, 0.9, 1.0, 1.0))
	mana_label.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	mana_label.add_theme_constant_override(&"outline_size", 1)
	mana_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mana_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(mana_label)

func _update_mana_display() -> void:
	if not mana_fill or not mana_label:
		return
	
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	var mana_comp := player.get_node_or_null("ManaComponent")
	if mana_comp:
		var percent := float(mana_comp.current_mana) / float(mana_comp.max_mana)
		mana_fill.size.x = 180.0 * percent
		mana_label.text = "MANA %d / %d" % [mana_comp.current_mana, mana_comp.max_mana]

func _create_boss_bar() -> void:
	boss_bar_container = Control.new()
	boss_bar_container.position = Vector2(120, 440)
	boss_bar_container.size = Vector2(400, 30)
	boss_bar_container.visible = false
	add_child(boss_bar_container)
	
	var bg := ColorRect.new()
	bg.size = Vector2(400, 24)
	bg.color = Color(0.15, 0.0, 0.0, 0.9)
	boss_bar_container.add_child(bg)
	
	boss_fill = ColorRect.new()
	boss_fill.size = Vector2(400, 24)
	boss_fill.color = Color(1.0, 0.1, 0.1, 1.0)
	boss_bar_container.add_child(boss_fill)
	
	boss_label = Label.new()
	boss_label.size = Vector2(400, 24)
	boss_label.add_theme_font_size_override(&"font_size", 14)
	boss_label.add_theme_color_override(&"font_color", Color(1.0, 1.0, 1.0, 1.0))
	boss_label.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	boss_label.add_theme_constant_override(&"outline_size", 2)
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	boss_bar_container.add_child(boss_label)

func _on_health_changed(new_hp: int) -> void:
	_current_health = new_hp
	_update_display()

func _on_max_health_changed(new_max: int) -> void:
	_max_health = new_max
	_update_display()

func _update_display() -> void:
	var percent := float(_current_health) / float(_max_health)
	health_fill.size.x = 180.0 * percent
	health_label.text = "%d / %d HP" % [_current_health, _max_health]

func _on_boss_health_changed(new_hp: int) -> void:
	if not boss_bar_container or not boss_fill or not boss_label:
		return
	
	boss_bar_container.visible = true
	var bosses := get_tree().get_nodes_in_group("boss")
	if bosses.size() == 0:
		return
	
	var boss: Node2D = bosses[0]
	var health_comp := boss.get_node_or_null("HealthComponent")
	if health_comp:
		var percent := float(health_comp.current_health) / float(health_comp.max_health)
		boss_fill.size.x = 400.0 * percent
		boss_label.text = "BOSS: %d / %d" % [health_comp.current_health, health_comp.max_health]

func _on_boss_died() -> void:
	if boss_bar_container:
		boss_bar_container.visible = false