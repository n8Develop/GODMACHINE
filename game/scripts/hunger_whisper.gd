extends Node
class_name HungerWhisper

## The dungeon whispers when the mortal starves — subtle text warnings that grow more desperate

@export var whisper_interval: float = 15.0  # How often to check/whisper
@export var hunger_threshold: float = 30.0  # Seconds without healing triggers hunger

var _time_since_heal: float = 0.0
var _whisper_timer: float = 0.0
var _last_whisper_level: int = 0

const WHISPERS := [
	"You feel weak.",
	"Hunger gnaws.",
	"Your vision blurs.",
	"Flesh demands sustenance.",
	"The void beckons."
]

func _ready() -> void:
	var main := get_tree().current_scene
	if main:
		var memory := main.get_node_or_null("DungeonMemory")
		if memory:
			memory.memory_updated.connect(_on_memory_updated)

func _process(delta: float) -> void:
	_time_since_heal += delta
	_whisper_timer += delta
	
	if _whisper_timer >= whisper_interval:
		_whisper_timer = 0.0
		_check_hunger()

func _check_hunger() -> void:
	if _time_since_heal < hunger_threshold:
		_last_whisper_level = 0
		return
	
	var hunger_level := int((_time_since_heal - hunger_threshold) / 20.0)
	hunger_level = clamp(hunger_level, 0, WHISPERS.size() - 1)
	
	if hunger_level > _last_whisper_level:
		_spawn_whisper(WHISPERS[hunger_level])
		_last_whisper_level = hunger_level

func _spawn_whisper(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override(&"font_color", Color(0.6, 0.3, 0.3, 1.0))
	label.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	label.add_theme_constant_override(&"outline_size", 2)
	label.add_theme_font_size_override(&"font_size", 16)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(220, 360)
	label.z_index = 100
	get_tree().current_scene.add_child(label)
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", 340.0, 2.0)
	tween.tween_property(label, "modulate:a", 0.0, 2.0)
	tween.finished.connect(label.queue_free)

func _on_memory_updated(key: String, _value: Variant) -> void:
	if key == "healing":
		_time_since_heal = 0.0
		_last_whisper_level = 0