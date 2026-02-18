extends Control
class_name UIMemoryJournal

var _journal_button: ColorRect
var _journal_panel: Panel
var _memory_list: VBoxContainer
var _is_open: bool = false
var _player_ref: Node2D = null

func _ready() -> void:
	# Create journal button (bottom-left corner)
	_journal_button = ColorRect.new()
	_journal_button.size = Vector2(48, 48)
	_journal_button.position = Vector2(20, 420)
	_journal_button.color = Color(0.6, 0.5, 0.9, 0.7)
	_journal_button.z_index = 100
	add_child(_journal_button)
	
	var button_label := Label.new()
	button_label.text = "J"
	button_label.add_theme_font_size_override(&"font_size", 24)
	button_label.add_theme_color_override(&"font_color", Color(1, 1, 1, 1))
	button_label.position = Vector2(14, 8)
	_journal_button.add_child(button_label)
	
	# Create journal panel (hidden by default)
	_journal_panel = Panel.new()
	_journal_panel.size = Vector2(400, 350)
	_journal_panel.position = Vector2(120, 65)
	_journal_panel.visible = false
	_journal_panel.z_index = 101
	add_child(_journal_panel)
	
	var title := Label.new()
	title.text = "ECHOES COLLECTED"
	title.add_theme_font_size_override(&"font_size", 16)
	title.add_theme_color_override(&"font_color", Color(0.6, 0.5, 0.9, 1))
	title.position = Vector2(10, 10)
	_journal_panel.add_child(title)
	
	var scroll := ScrollContainer.new()
	scroll.size = Vector2(380, 300)
	scroll.position = Vector2(10, 40)
	_journal_panel.add_child(scroll)
	
	_memory_list = VBoxContainer.new()
	_memory_list.size = Vector2(360, 0)
	scroll.add_child(_memory_list)
	
	# Find player
	await get_tree().process_frame
	_player_ref = get_tree().get_first_node_in_group("player")

func _process(_delta: float) -> void:
	# Pulse button
	if _journal_button:
		var pulse := sin(Time.get_ticks_msec() * 0.003) * 0.5 + 0.5
		_journal_button.modulate.a = 0.7 + (pulse * 0.3)
	
	# Toggle journal with J key
	if Input.is_action_just_pressed(&"ui_cancel"):
		_toggle_journal()

func _toggle_journal() -> void:
	_is_open = not _is_open
	if _journal_panel:
		_journal_panel.visible = _is_open
	
	if _is_open:
		_refresh_memory_list()

func _refresh_memory_list() -> void:
	if not _memory_list or not _player_ref or not is_instance_valid(_player_ref):
		return
	
	# Clear existing entries
	for child in _memory_list.get_children():
		child.queue_free()
	
	# Get collected memories
	var memories: Array = _player_ref.get_meta("collected_memories", [])
	
	if memories.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No echoes yet... explore the dungeon."
		empty_label.add_theme_font_size_override(&"font_size", 11)
		empty_label.add_theme_color_override(&"font_color", Color(0.7, 0.7, 0.7, 1))
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		empty_label.custom_minimum_size = Vector2(340, 0)
		_memory_list.add_child(empty_label)
	else:
		for memory_text in memories:
			var entry := Label.new()
			entry.text = "• " + memory_text
			entry.add_theme_font_size_override(&"font_size", 11)
			entry.add_theme_color_override(&"font_color", Color(0.9, 0.9, 0.9, 1))
			entry.autowrap_mode = TextServer.AUTOWRAP_WORD
			entry.custom_minimum_size = Vector2(340, 0)
			_memory_list.add_child(entry)
			
			# Spacing
			var spacer := Control.new()
			spacer.custom_minimum_size = Vector2(0, 8)
			_memory_list.add_child(spacer)