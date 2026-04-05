@tool
extends Resource
class_name ScenePainterLabelSettings

## The text that this label will display.
@export_multiline var text: String:
	set(value):
		text = value
		changed.emit()

@export var max_line_width: float = 300:
	set(value):
		max_line_width = value
		changed.emit()

## If set to a positive value, this will override the default font size for this label.
@export var custom_font_size: int = -1:
	set(value):
		custom_font_size = value
		changed.emit()

## If set to a value with an alpha greater than zero, this will override the default font color
## for this label.
@export var custom_font_color: Color = Color(0, 0, 0, 0):
	set(value):
		custom_font_color = value
		changed.emit()

@export var position: Vector2


func _validate_property(property: Dictionary) -> void:
	if property.name == "position":
		property.usage = PROPERTY_USAGE_STORAGE
