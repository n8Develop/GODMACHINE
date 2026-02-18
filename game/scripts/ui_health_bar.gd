extends Control
class_name UIHealthBar

@onready var _fill: ColorRect = $Fill
@onready var _label: Label = $Label

var _current_hp: int = 100
var _max_hp: int = 100

# Boss health bar elements
var _boss_bar_container: Control = null
var _boss_fill: ColorRect = null
var _boss_label: Label = null
var _boss_target: Node = null

# Mana bar elements (added inline)
var _mana_bg: ColorRect = null
var _mana_fill: ColorRect = null
var _mana_label: Label = null

func _ready() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		var health := player.get_node_or_null("HealthComponent")
		if health:
			health.health_changed.connect(_on_health_changed)
			health.max_health_changed.connect(_on_max_health_changed)
			_current_hp = health.current_health
			_max_hp = health.max_health
			_update_display()
	
	# Create boss health bar (hidden by default)
	_create_boss_bar()
	
	# Create mana bar below health bar
	_create_mana_bar()

func _process(_delta: float) -> void:
	# Check for boss enemy
	var bosses := get_tree().get_nodes_in_group("boss")
	if bosses.size() > 0:
		var boss := bosses[0]
		if boss != _boss_target:
			_boss_target = boss
			var boss_health := boss.get_node_or_null("HealthComponent")
			if boss_health and not boss_health.health_changed.is_connected(_on_boss_health_changed):
				boss_health.health_changed.connect(_on_boss_health_changed)
				boss_health.died.connect(_on_boss_died)
				_on_boss_health_changed(boss_health.current_health)
		if _boss_bar_container:
			_boss_bar_container.show()
	else:
		if _boss_bar_container:
			_boss_bar_container.hide()
		_boss_target = null
	
	# Update mana bar
	_update_mana_display()

func _create_mana_bar() -> void:
	# Background
	_mana_bg = ColorRect.new()
	_mana_bg.position = Vector2(0, 35)
	_mana_bg.size = Vector2(180, 20)
	_mana_bg.color = Color(0.1, 0.1, 0.15, 1.0)
	add_child(_mana_bg)
	
	# Fill
	_mana_fill = ColorRect.new()
	_mana_fill.position = Vector2(10, 40)
	_mana_fill.size = Vector2(160, 10)
	_mana_fill.color = Color(0.2, 0.4, 1.0, 1.0)
	add_child(_mana_fill)
	
	# Label
	_mana_label = Label.new()
	_mana_label.position = Vector2(10, 37)
	_mana_label.size = Vector2(160, 16)
	_mana_label.add_theme_color_override(&"font_color", Color(0.8, 0.9, 1.0, 1.0))
	_mana_label.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 1))
	_mana_label.add_theme_constant_override(&"outline_size", 1)
	_mana_label.add_theme_font_size_override(&"font_size", 12)
	_mana_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mana_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_mana_label.text = "MP: 100/100"
	add_child(_mana_label)

func _update_mana_display() -> void:
	if not _mana_fill or not _mana_label:
		return
	
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	var mana := player.get_node_or_null("ManaComponent")
	if not mana:
		_mana_bg.hide()
		_mana_fill.hide()
		_mana_label.hide()
		return
	
	_mana_bg.show()
	_mana_fill.show()
	_mana_label.show()
	
	var ratio := float(mana.current_mana) / float(mana.max_mana) if mana.max_mana > 0 else 0.0
	_mana_fill.size.x = 160 * ratio
	_mana_label.text = "MP: %d/%d" % [mana.current_mana, mana.max_mana]

func _create_boss_bar() -> void:
	_boss_bar_container = Control.new()
	_boss_bar_container.position = Vector2(320 - 150, 50)  # Center top
	_boss_bar_container.size = Vector2(300, 40)
	_boss_bar_container.hide()
	add_child(_boss_bar_container)
	
	# Background
	var bg := ColorRect.new()
	bg.size = Vector2(300, 30)
	bg.color = Color(0.15, 0.15, 0.2, 0.9)
	_boss_bar_container.add_child(bg)
	
	# Fill
	_boss_fill = ColorRect.new()
	_boss_fill.size = Vector2(300, 30)
	_boss_fill.color = Color(0.9, 0.2, 0.2, 1.0)
	_boss_bar_container.add_child(_boss_fill)
	
	# Label
	_boss_label = Label.new()
	_boss_label.position = Vector2(10, 5)
	_boss_label.add_theme_color_override(&"font_color", Color(1, 1, 1, 1))
	_boss_label.add_theme_font_size_override(&"font_size", 16)
	_boss_label.text = "BOSS: 100/100"
	_boss_bar_container.add_child(_boss_label)

func _on_health_changed(new_hp: int) -> void:
	_current_hp = new_hp
	_update_display()

func _on_max_health_changed(new_max: int) -> void:
	_max_hp = new_max
	_update_display()

func _update_display() -> void:
	if not _fill or not _label:
		return
	
	var ratio := float(_current_hp) / float(_max_hp) if _max_hp > 0 else 0.0
	_fill.size.x = 180 * ratio
	_label.text = "HP: %d/%d" % [_current_hp, _max_hp]

func _on_boss_health_changed(new_hp: int) -> void:
	if not _boss_target or not _boss_fill or not _boss_label:
		return
	
	var boss_health := _boss_target.get_node_or_null("HealthComponent")
	if not boss_health:
		return
	
	var ratio := float(new_hp) / float(boss_health.max_health) if boss_health.max_health > 0 else 0.0
	_boss_fill.size.x = 300 * ratio
	_boss_label.text = "BOSS: %d/%d" % [new_hp, boss_health.max_health]

func _on_boss_died() -> void:
	if _boss_bar_container:
		_boss_bar_container.hide()
	_boss_target = null