@tool
extends Label
class_name ScenePainterLabel

signal should_destroy(label: ScenePainterLabel)
signal modified()
var toolbar: ScenePainterToolbar
var settings: ScenePainterLabelSettings
var editing: bool


func _draw() -> void:
	if toolbar.mode == toolbar.Mode.TEXT:
		var rect: Rect2 = get_rect() * get_transform()
		var color: Color = Color.ORANGE
		color.a = 0.1
		draw_rect(rect, color)
		if editing:
			var line_scale: float = 1 / get_viewport().global_canvas_transform.get_scale().x
			color.a = 0.5
			draw_rect(rect, color, false, 2 * line_scale)
		else:
			color.a = 0.2
			draw_rect(rect, color, false)


func on_edited_object_changed() -> void:
	editing = false
	if text.length() == 0:
		should_destroy.emit(self)
	queue_redraw()


func edit() -> void:
	if editing:
		return

	var inspector: EditorInspector = EditorInterface.get_inspector()
	inspector.edit(settings)
	inspector.edited_object_changed.connect(on_edited_object_changed, CONNECT_ONE_SHOT)
	editing = true
	queue_redraw()


func get_painter_label_settings() -> LabelSettings:
	if label_settings == null:
		label_settings = LabelSettings.new()
	return label_settings


func on_settings_changed() -> void:
	text = settings.text

	# This handles deletion during undo-redo.
	if text.length() == 0 && !editing:
		should_destroy.emit(self)

	size.x = settings.max_line_width
	if settings.custom_font_size > 0:
		get_painter_label_settings().font_size = settings.custom_font_size
	elif label_settings != toolbar.default_label_settings:
		label_settings.font_size = toolbar.default_label_settings.font_size
	if settings.custom_font_color.a != 0:
		get_painter_label_settings().font_color = settings.custom_font_color
	elif label_settings != toolbar.default_label_settings:
		label_settings.font_color = toolbar.default_label_settings.font_color
	modified.emit()
	queue_redraw()


func plugin_process() -> void:
	if editing:
		queue_redraw()


func set_settings(settings: ScenePainterLabelSettings) -> void:
	self.settings = settings
	settings.changed.connect(on_settings_changed)
	on_settings_changed()


func _ready() -> void:
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	label_settings = toolbar.default_label_settings
	# Setting editing as a workaround to prevent this label from immediately destroying itself.
	editing = true
	var new_settings: ScenePainterLabelSettings = ScenePainterLabelSettings.new()
	new_settings.max_line_width = toolbar.default_max_line_width
	set_settings(new_settings)
	editing = false
