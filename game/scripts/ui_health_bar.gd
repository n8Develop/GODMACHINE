extends Control
class_name UIHealthBar

@onready var health_fill: ColorRect = $HealthFill
@onready var health_bg: ColorRect = $HealthBG
@onready var label: Label = $Label
@onready var mana_fill: ColorRect = $ManaFill
@onready var mana_bg: ColorRect = $ManaBG

var _player: Node2D = null
var _health_component: Node = null
var _mana_component: Node = null
var _enemy_counter: Control = null
var _enemy_label: Label = null
var _boss_bar: Control = null
var _boss_fill: ColorRect = null
var _boss_label: Label = null
var _current_boss: Node2D = null

func _ready() -> void:
	_create_mana_bar()
	_create_enemy_counter()
	_create_boss_bar()

func _process(_delta: float) -> void:
	if not _player:
		_player = get_tree().get_first_node_in_group("player")
		if _player:
			_health_component = _player.get_node_or_null("HealthComponent")
			_mana_component = _player.get_node_or_null("ManaComponent")
			
			if _health_component and _health_component.has_signal("health_changed"):
				_health_component.health_changed.connect(_on_health_changed)
			if _health_component and _health_component.has_signal("max_health_changed"):
				_health_component.max_health_changed.connect(_on_max_health_changed)
		return
	
	if _health_component:
		_update_display()
	if _mana_component:
		_update_mana_display()
	
	_update_enemy_counter()
	
	# Boss bar check
	if not _current_boss or not is_instance_valid(_current_boss):
		var bosses := get_tree().get_nodes_in_group("enemies")
		_current_boss = null
		for enemy in bosses:
			if enemy.has_meta("is_boss") and enemy.get_meta("is_boss"):
				_current_boss = enemy
				var boss_health := enemy.get_node_or_null("HealthComponent")
				if boss_health and boss_health.has_signal("health_changed"):
					if not boss_health.health_changed.is_connected(_on_boss_health_changed):
						boss_health.health_changed.connect(_on_boss_health_changed)
				if boss_health and boss_health.has_signal("died"):
					if not boss_health.died.is_connected(_on_boss_died):
						boss_health.died.connect(_on_boss_died)
				break
		
		if _boss_bar:
			_boss_bar.visible = (_current_boss != null)

func _create_enemy_counter() -> void:
	_enemy_counter = Control.new()
	_enemy_counter.position = Vector2(420, 20)
	_enemy_counter.size = Vector2(200, 40)
	add_child(_enemy_counter)
	
	var icon := ColorRect.new()
	icon.size = Vector2(24, 24)
	icon.position = Vector2(0, 8)
	icon.color = Color(0.9, 0.2, 0.2, 1.0)
	_enemy_counter.add_child(icon)
	
	var skull1 := ColorRect.new()
	skull1.size = Vector2(8, 6)
	skull1.position = Vector2(8, 9)
	skull1.color = Color(0.2, 0.2, 0.2, 1.0)
	icon.add_child(skull1)
	
	var skull2 := ColorRect.new()
	skull2.size = Vector2(8, 6)
	skull2.position = Vector2(8, 17)
	skull2.color = Color(0.2, 0.2, 0.2, 1.0)
	icon.add_child(skull2)
	
	_enemy_label = Label.new()
	_enemy_label.position = Vector2(32, 8)
	_enemy_label.add_theme_font_size_override(&"font_size", 20)
	_enemy_label.add_theme_color_override(&"font_color", Color(0.9, 0.2, 0.2, 1.0))
	_enemy_label.text = "0"
	_enemy_counter.add_child(_enemy_label)

func _update_enemy_counter() -> void:
	if not _enemy_label:
		return
	
	var enemies := get_tree().get_nodes_in_group("enemies")
	var spawners := get_tree().get_nodes_in_group("spawners")
	
	var threat_count := enemies.size() + (spawners.size() * 2)
	_enemy_label.text = str(threat_count)
	
	if threat_count == 0:
		_enemy_label.add_theme_color_override(&"font_color", Color(0.3, 0.8, 0.3, 1.0))
	elif threat_count <= 3:
		_enemy_label.add_theme_color_override(&"font_color", Color(0.9, 0.9, 0.3, 1.0))
	elif threat_count <= 6:
		_enemy_label.add_theme_color_override(&"font_color", Color(1.0, 0.6, 0.2, 1.0))
	else:
		_enemy_label.add_theme_color_override(&"font_color", Color(1.0, 0.2, 0.2, 1.0))

func _create_mana_bar() -> void:
	if not mana_bg:
		mana_bg = ColorRect.new()
		mana_bg.position = Vector2(20, 65)
		mana_bg.size = Vector2(180, 12)
		mana_bg.color = Color(0.1, 0.1, 0.15, 0.8)
		add_child(mana_bg)
	
	if not mana_fill:
		mana_fill = ColorRect.new()
		mana_fill.position = Vector2(20, 65)
		mana_fill.size = Vector2(180, 12)
		mana_fill.color = Color(0.2, 0.4, 1.0, 1.0)
		add_child(mana_fill)

func _update_mana_display() -> void:
	if not _mana_component or not mana_fill or not is_instance_valid(mana_fill):
		return
	
	var mana_percent := float(_mana_component.current_mana) / float(_mana_component.max_mana)
	mana_fill.size.x = 180.0 * clamp(mana_percent, 0.0, 1.0)

func _create_boss_bar() -> void:
	_boss_bar = Control.new()
	_boss_bar.position = Vector2(170, 100)
	_boss_bar.size = Vector2(300, 40)
	_boss_bar.visible = false
	add_child(_boss_bar)
	
	_boss_label = Label.new()
	_boss_label.position = Vector2(0, 0)
	_boss_label.text = "BOSS"
	_boss_label.add_theme_font_size_override(&"font_size", 16)
	_boss_label.add_theme_color_override(&"font_color", Color(1.0, 0.3, 0.3, 1.0))
	_boss_bar.add_child(_boss_label)
	
	var boss_bg := ColorRect.new()
	boss_bg.position = Vector2(0, 24)
	boss_bg.size = Vector2(300, 12)
	boss_bg.color = Color(0.2, 0.1, 0.1, 0.9)
	_boss_bar.add_child(boss_bg)
	
	_boss_fill = ColorRect.new()
	_boss_fill.position = Vector2(0, 24)
	_boss_fill.size = Vector2(300, 12)
	_boss_fill.color = Color(1.0, 0.2, 0.2, 1.0)
	_boss_bar.add_child(_boss_fill)

func _on_health_changed(new_hp: int) -> void:
	_update_display()

func _on_max_health_changed(new_max: int) -> void:
	_update_display()

func _update_display() -> void:
	if not _health_component or not health_fill or not is_instance_valid(health_fill):
		return
	
	var hp_percent := float(_health_component.current_health) / float(_health_component.max_health)
	health_fill.size.x = 180.0 * clamp(hp_percent, 0.0, 1.0)
	
	if label and is_instance_valid(label):
		label.text = str(_health_component.current_health) + " / " + str(_health_component.max_health)

func _on_boss_health_changed(new_hp: int) -> void:
	if not _current_boss or not is_instance_valid(_current_boss):
		return
	
	var boss_health := _current_boss.get_node_or_null("HealthComponent")
	if not boss_health or not _boss_fill or not is_instance_valid(_boss_fill):
		return
	
	var hp_percent := float(boss_health.current_health) / float(boss_health.max_health)
	_boss_fill.size.x = 300.0 * clamp(hp_percent, 0.0, 1.0)

func _on_boss_died() -> void:
	if _boss_bar and is_instance_valid(_boss_bar):
		_boss_bar.visible = false
	_current_boss = null