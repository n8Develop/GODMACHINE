extends Control
class_name UIHealthBar

@onready var health_fill: ColorRect = $HealthBar/Fill
@onready var health_label: Label = $HealthBar/Label
@onready var mana_bar: Control = null
@onready var mana_fill: ColorRect = null
@onready var boss_bar: Control = null
@onready var boss_fill: ColorRect = null
@onready var boss_label: Label = null
@onready var enemy_counter: Label = null

var _current_health: int = 100
var _max_health: int = 100

func _ready() -> void:
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
	
	_create_mana_bar()
	_create_boss_bar()
	_create_enemy_counter()

func _process(_delta: float) -> void:
	_update_mana_display()
	_update_enemy_counter()

func _create_enemy_counter() -> void:
	enemy_counter = Label.new()
	enemy_counter.add_theme_font_size_override(&"font_size", 14)
	enemy_counter.add_theme_color_override(&"font_color", Color(1.0, 0.4, 0.4, 1.0))
	enemy_counter.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	enemy_counter.add_theme_constant_override(&"outline_size", 2)
	enemy_counter.position = Vector2(0, 75)
	enemy_counter.size = Vector2(180, 20)
	add_child(enemy_counter)

func _update_enemy_counter() -> void:
	if not enemy_counter:
		return
	
	var enemies := get_tree().get_nodes_in_group("enemies")
	var spawners := get_tree().get_nodes_in_group("spawners")
	
	var total_count := enemies.size() + spawners.size()
	
	if total_count > 0:
		enemy_counter.text = "HOSTILES: %d" % total_count
		enemy_counter.show()
	else:
		enemy_counter.hide()

func _create_mana_bar() -> void:
	mana_bar = Control.new()
	mana_bar.position = Vector2(0, 45)
	mana_bar.size = Vector2(180, 20)
	add_child(mana_bar)
	
	var bg := ColorRect.new()
	bg.size = Vector2(180, 20)
	bg.color = Color(0.1, 0.1, 0.15, 0.8)
	mana_bar.add_child(bg)
	
	mana_fill = ColorRect.new()
	mana_fill.size = Vector2(180, 20)
	mana_fill.color = Color(0.2, 0.5, 1.0, 1.0)
	mana_bar.add_child(mana_fill)
	
	var label := Label.new()
	label.text = "MANA"
	label.add_theme_font_size_override(&"font_size", 12)
	label.add_theme_color_override(&"font_color", Color(1.0, 1.0, 1.0, 1.0))
	label.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	label.add_theme_constant_override(&"outline_size", 2)
	label.position = Vector2(5, 2)
	mana_bar.add_child(label)

func _update_mana_display() -> void:
	if not mana_fill:
		return
	
	var player := get_tree().get_first_node_in_group("player")
	if player:
		var mana_comp := player.get_node_or_null("ManaComponent")
		if mana_comp:
			var ratio := float(mana_comp.current_mana) / float(mana_comp.max_mana)
			mana_fill.size.x = 180.0 * ratio

func _create_boss_bar() -> void:
	boss_bar = Control.new()
	boss_bar.position = Vector2(220, 20)
	boss_bar.size = Vector2(200, 30)
	boss_bar.hide()
	add_child(boss_bar)
	
	var bg := ColorRect.new()
	bg.size = Vector2(200, 30)
	bg.color = Color(0.15, 0.0, 0.0, 0.9)
	boss_bar.add_child(bg)
	
	boss_fill = ColorRect.new()
	boss_fill.size = Vector2(200, 30)
	boss_fill.color = Color(0.9, 0.1, 0.1, 1.0)
	boss_bar.add_child(boss_fill)
	
	boss_label = Label.new()
	boss_label.text = "BOSS"
	boss_label.add_theme_font_size_override(&"font_size", 16)
	boss_label.add_theme_color_override(&"font_color", Color(1.0, 0.9, 0.2, 1.0))
	boss_label.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	boss_label.add_theme_constant_override(&"outline_size", 3)
	boss_label.position = Vector2(5, 5)
	boss_bar.add_child(boss_label)
	
	var boss := get_tree().get_first_node_in_group("boss")
	if boss:
		var boss_health := boss.get_node_or_null("HealthComponent")
		if boss_health:
			boss_health.health_changed.connect(_on_boss_health_changed)
			boss_health.died.connect(_on_boss_died)
			boss_bar.show()

func _on_health_changed(new_hp: int) -> void:
	_current_health = new_hp
	_update_display()

func _on_max_health_changed(new_max: int) -> void:
	_max_health = new_max
	_update_display()

func _update_display() -> void:
	if not health_fill or not health_label:
		return
	
	var ratio := float(_current_health) / float(_max_health)
	health_fill.size.x = 180.0 * ratio
	health_label.text = "%d / %d" % [_current_health, _max_health]

func _on_boss_health_changed(new_hp: int) -> void:
	if not boss_fill or not boss_bar:
		return
	
	var boss := get_tree().get_first_node_in_group("boss")
	if boss:
		var boss_health := boss.get_node_or_null("HealthComponent")
		if boss_health:
			var ratio := float(new_hp) / float(boss_health.max_health)
			boss_fill.size.x = 200.0 * ratio

func _on_boss_died() -> void:
	if boss_bar:
		boss_bar.hide()