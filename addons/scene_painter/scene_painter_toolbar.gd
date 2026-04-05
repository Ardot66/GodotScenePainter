@tool
extends HBoxContainer

class_name ScenePainterToolbar

signal visibility_set()
signal configured()
signal mode_changed()

enum Mode {
	NONE,
	PAINT,
	TEXT,
}

@export var visibility_button: Button
@export var paint_button: Button
@export var edit_text_button: Button
@export var config_button: Button

@export var configuration_popup: ConfirmationDialog

@export var brush_size_range: Range
@export var eraser_size_range: Range
@export var brush_color_picker: ColorPickerButton
@export var canvas_color_picker: ColorPickerButton

var brush_size: int = 8
var eraser_size: int = 32
var brush_color: Color = Color.WHITE
var canvas_color: Color = Color.WHITE

var default_label_settings: LabelSettings
var default_max_line_width: float
var data_folder: String
var pixel_scale: float

var mode: Mode = Mode.NONE


func set_visibility(_visible: bool) -> void:
	visibility_set.emit()


func get_visible() -> bool:
	return visibility_button.button_pressed


func button_toggled(toggled_on: bool, mode: Mode) -> void:
	set_mode(mode if toggled_on else Mode.NONE)


func set_mode(mode: Mode) -> void:
	paint_button.set_pressed_no_signal(mode == Mode.PAINT)
	edit_text_button.set_pressed_no_signal(mode == Mode.TEXT)
	self.mode = mode
	mode_changed.emit()


func configure() -> void:
	configuration_popup.popup_centered()
	brush_size_range.value = brush_size
	eraser_size_range.value = eraser_size
	brush_color_picker.color = brush_color
	canvas_color_picker.color = canvas_color


func accept_configuration() -> void:
	brush_size = brush_size_range.value
	eraser_size = eraser_size_range.value
	brush_color = brush_color_picker.color
	canvas_color = canvas_color_picker.color
	configured.emit()


func broadcast_configuration() -> void:
	set_visibility(false)
	configured.emit()


func get_icon(icon: StringName) -> Texture2D:
	return EditorInterface.get_base_control().get_theme_icon(icon, &"EditorIcons")


func setting(setting: String) -> String:
	return "addons/scene_painter/" + setting


func init_setting(setting: String, value: Variant) -> Variant:
	var full_setting = setting(setting)
	if ProjectSettings.has_setting(full_setting):
		return ProjectSettings.get_setting(full_setting)
	ProjectSettings.set_setting(full_setting, value)
	ProjectSettings.set_initial_value(full_setting, value)
	return value


func on_settings_changed() -> void:
	default_max_line_width = init_setting("default_max_line_width", 600)
	default_label_settings.font_size = init_setting("default_font_size", 32)
	default_label_settings.font_color = init_setting("default_font_color", Color.WHITE)
	data_folder = init_setting("data_folder", "res://")
	ProjectSettings.add_property_info(
		{
			"name"= setting("data_folder"),
			"type"= TYPE_STRING,
			"hint"= PROPERTY_HINT_DIR,
		},
	)
	ProjectSettings.set_restart_if_changed(setting("data_folder"), true)
	pixel_scale = init_setting("paint_scale", 1.0)
	configured.emit()


# Can't use _ready, as that would trigger when editing the scene.
func plugin_ready() -> void:
	default_label_settings = LabelSettings.new()
	on_settings_changed()
	ProjectSettings.settings_changed.connect(on_settings_changed)

	paint_button.toggled.connect(button_toggled.bind(Mode.PAINT))
	edit_text_button.toggled.connect(button_toggled.bind(Mode.TEXT))

	visibility_button.icon = get_icon(&"GuiVisibilityVisible")
	paint_button.icon = get_icon(&"Paint")
	edit_text_button.icon = get_icon(&"MatchCase")
	config_button.icon = get_icon(&"GuiTabMenuHl")


func plugin_exit() -> void:
	ProjectSettings.settings_changed.disconnect(on_settings_changed)


func get_config(config: ConfigFile, prop: StringName) -> void:
	config.set_value("ScenePainter", prop, get(prop))


func get_window_layout(config: ConfigFile) -> void:
	get_config(config, &"brush_size")
	get_config(config, &"eraser_size")
	get_config(config, &"brush_color")
	get_config(config, &"canvas_color")


func set_config(config: ConfigFile, prop: StringName, default: Variant) -> void:
	set(prop, config.get_value("ScenePainter", prop, default))


func set_window_layout(config: ConfigFile) -> void:
	set_config(config, &"brush_size", 8)
	set_config(config, &"eraser_size", 32)
	set_config(config, &"brush_color", Color.WHITE)
	set_config(config, &"canvas_color", Color.WHITE)
	configured.emit()
