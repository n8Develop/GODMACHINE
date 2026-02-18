extends ColorRect
class_name RoomAmbientTint

## Ambient color overlay that defines room identity
## Attached to rooms as a semi-transparent fullscreen child

const ROOM_TINTS := {
	"corridor": Color(0.15, 0.2, 0.35, 0.12),      # Dim blue — claustrophobic
	"arena": Color(0.4, 0.15, 0.15, 0.18),         # Dark red — threatening
	"treasure": Color(0.5, 0.4, 0.1, 0.15),        # Gold — promising
	"boss": Color(0.25, 0.1, 0.35, 0.22),          # Deep purple — authority
	"start": Color(0.2, 0.25, 0.2, 0.08),          # Soft green — sanctuary
	"unknown": Color(0.1, 0.1, 0.12, 0.1)          # Neutral gray
}

@export var room_type: String = "unknown"
@export var pulse_intensity: float = 0.03
@export var pulse_speed: float = 0.8

var _base_alpha: float = 0.1
var _time: float = 0.0

func _ready() -> void:
	# Fullscreen overlay
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = -10
	
	# Detect room type from parent name if not set
	if room_type == "unknown":
		var parent_name := get_parent().name.to_lower()
		for key in ROOM_TINTS.keys():
			if parent_name.contains(key):
				room_type = key
				break
	
	# Set base color
	var base_tint := ROOM_TINTS.get(room_type, ROOM_TINTS["unknown"])
	color = base_tint
	_base_alpha = base_tint.a

func _process(delta: float) -> void:
	_time += delta * pulse_speed
	
	# Subtle pulsing — breathing atmosphere
	var pulse := sin(_time) * pulse_intensity
	var new_color := color
	new_color.a = _base_alpha + pulse
	color = new_color