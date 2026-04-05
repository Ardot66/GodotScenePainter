@tool
extends Node2D

class_name ScenePainterOverlay

var toolbar: ScenePainterToolbar
var active: bool

var brush_last_color: Color
var brush: Image
var final_brush: Image

var drawing: bool
var erasing: bool
var dirty_images: Dictionary[Vector2i, bool]

var dragging_label: ScenePainterLabel
var drag_offset: Vector2

var image: ScenePainterImage
var last_state_image: ScenePainterImage

var sprite_parent: Node2D
var label_parent: Node2D

var labels: Array[ScenePainterLabel]

var sprites: Dictionary[Vector2i, Sprite2D]
var last_mouse_pos: Vector2

var modified: bool = false


func _draw() -> void:
	if erasing:
		var size: Vector2 = Vector2(toolbar.eraser_size, toolbar.eraser_size) * toolbar.pixel_scale
		var erase_rect: Rect2 = Rect2(get_local_mouse_position() - size / 2, size)
		var color: Color = Color.GRAY
		color.a = 0.5
		draw_rect(erase_rect, color, false)
		color.a = 0.1
		draw_rect(erase_rect, color)


func clear_unused_sprites() -> void:
	var to_trim: Array[Vector2i]
	for chunk: Vector2i in sprites.keys():
		if image.images.has(chunk):
			continue
		to_trim.push_back(chunk)
	for chunk: Vector2i in to_trim:
		var sprite: Sprite2D = sprites[chunk]
		sprite_parent.remove_child(sprite)
		sprite.queue_free()
		sprites.erase(chunk)


func update_textures() -> void:
	for chunk: Vector2i in dirty_images:
		var image: Image = image.get_image(chunk)
		if !sprites.has(chunk):
			var sprite = Sprite2D.new()
			sprite_parent.add_child(sprite)
			sprite.position = chunk * ScenePainterImage.CHUNK_SIZE
			sprite.centered = false
			sprite.texture = ImageTexture.create_from_image(image)
			sprites[chunk] = sprite
		else:
			sprites[chunk].texture.update(image)
	dirty_images.clear()


func set_brush_color(color: Color) -> void:
	brush_last_color = color
	var size: Vector2i = brush.get_size()
	for x: int in size.x:
		for y: int in size.y:
			var pixel: Vector2i = Vector2i(x, y)
			final_brush.set_pixelv(pixel, Color(color.r, color.b, color.g, brush.get_pixelv(pixel).a * color.a))


func draw(center: Vector2i, color: Color) -> void:
	var size: Vector2i = brush.get_size()
	if erasing:
		size = Vector2i(toolbar.eraser_size, toolbar.eraser_size)
	if color != brush_last_color:
		set_brush_color(color)

	var rect: Rect2i = Rect2i(center - size / 2, size)
	for chunk: Vector2i in image.get_covered_chunks(rect):
		if last_state_image.images.has(chunk):
			continue
		last_state_image.images[chunk] = image.get_image(chunk).duplicate()

	if erasing:
		image.fill_rect(rect, Color(0))
	else:
		image.blend_rect(final_brush, Rect2i(Vector2i.ZERO, size), rect.position)


func begin_stroke() -> void:
	drawing = true
	last_state_image = ScenePainterImage.new()


func override_chunks(override_image: ScenePainterImage) -> void:
	for chunk: Vector2i in override_image.images.keys():
		dirty_images[chunk] = true
		image.get_image(chunk).copy_from(override_image.images[chunk])
	update_textures()


func end_stroke() -> void:
	if !drawing:
		return
	drawing = false
	modified = true

	var diff_image: ScenePainterImage = ScenePainterImage.new()
	# Copy only changed chunks into the diff.
	for chunk: Vector2i in last_state_image.images.keys():
		diff_image.images[chunk] = image.images[chunk].duplicate()

	var undo_redo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Draw", 0, EditorInterface.get_edited_scene_root())
	undo_redo.add_do_method(self, &"override_chunks", diff_image)
	undo_redo.add_undo_method(self, &"override_chunks", last_state_image)

	# Don't want to execute, everything is already on the canvas.
	undo_redo.commit_action(false)


func get_overlapping_label(position: Vector2) -> ScenePainterLabel:
	# Iterating backwards so that the most recently added (and this highest in draw order) nodes
	# are selected first.
	for i: int in labels.size():
		var label: ScenePainterLabel = labels[-i - 1]
		if label.get_rect().has_point(position):
			return label
	return null


func on_should_destroy_label(label: ScenePainterLabel) -> void:
	labels.erase(label)
	label_parent.remove_child(label)
	label.queue_free()
	modified = true


func on_label_modified() -> void:
	modified = true


func create_label() -> ScenePainterLabel:
	var label: ScenePainterLabel = ScenePainterLabel.new()
	label.toolbar = toolbar
	label.should_destroy.connect(on_should_destroy_label)
	label.modified.connect(on_label_modified)
	label_parent.add_child(label)
	labels.push_back(label)
	return label


## Returns true if the event was consumed.
func viewport_input(contained: bool, event: InputEvent) -> bool:
	var pressed: bool = event.is_pressed()
	if toolbar.mode == toolbar.Mode.PAINT && visible:
		if event is InputEventMouseButton:
			var button: InputEventMouseButton = event
			if button.button_index == MOUSE_BUTTON_LEFT:
				if contained && pressed:
					begin_stroke()
				else:
					end_stroke()
				return contained
			if button.button_index == MOUSE_BUTTON_RIGHT:
				erasing = contained && pressed
				if contained && pressed:
					begin_stroke()
				else:
					end_stroke()
				queue_redraw()
				return contained
		if event is InputEventMouseMotion && erasing:
			queue_redraw()
	elif toolbar.mode == toolbar.Mode.TEXT && visible:
		if event is InputEventMouseButton:
			var button: InputEventMouseButton = event
			if button.button_index == MOUSE_BUTTON_LEFT:
				if contained && pressed:
					var mouse_pos: Vector2 = get_viewport().get_mouse_position()
					var overlapping: ScenePainterLabel = get_overlapping_label(mouse_pos)

					if overlapping == null:
						overlapping = create_label()
						overlapping.position = mouse_pos

					dragging_label = overlapping
					drag_offset = mouse_pos - overlapping.position

					overlapping.edit()
					modified = true
					return true
				if !pressed && dragging_label != null:
					dragging_label = null
		elif event is InputEventKey:
			var key: InputEventKey = event
			if key.keycode == KEY_DELETE:
				for label: Label in labels:
					if label.editing:
						on_should_destroy_label(label)

	return false


func viewport_process() -> void:
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()

	for label: ScenePainterLabel in labels:
		label.plugin_process()
	if drawing:
		var offset: Vector2 = mouse_pos - last_mouse_pos
		var normalized_offset: Vector2 = offset.normalized()
		var offset_len: int = max(offset.length() / toolbar.pixel_scale, 1)

		for i: int in offset_len:
			var pixel_pos: Vector2i = floor((last_mouse_pos + normalized_offset * toolbar.pixel_scale * i) / toolbar.pixel_scale)
			draw(pixel_pos, toolbar.brush_color)

		update_textures()
	elif dragging_label != null:
		dragging_label.position = mouse_pos - drag_offset
	last_mouse_pos = mouse_pos


func initialize_brush(brush_size: int) -> void:
	var size: Vector2i = Vector2i(brush_size, brush_size)
	brush = Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)

	var center: Vector2i = size / 2
	for x: int in size.x:
		for y: int in size.y:
			var pixel: Vector2i = Vector2i(x, y)
			brush.set_pixelv(pixel, Color(1, 1, 1, 1 - pixel.distance_to(center) / (float(size.x) * 0.5)))

	final_brush = Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	set_brush_color(Color.WHITE)


func update_visibility() -> void:
	visible = toolbar.get_visible() && active


func on_visibility_set(visible: bool) -> void:
	self.visible = visible


func on_configured() -> void:
	update_paint_scale()
	initialize_brush(toolbar.brush_size)
	modulate = toolbar.canvas_color


func on_chunk_updated(chunk: Vector2i) -> void:
	dirty_images[chunk] = true


func save() -> ScenePainterSceneData:
	# The overlay is now synced with the filesystem, so it is considered unmodified.
	modified = false

	image.trim_empty_chunks()
	clear_unused_sprites()

	var data: ScenePainterSceneData = ScenePainterSceneData.new()
	data.set_image(image)
	for label: ScenePainterLabel in labels:
		if label.text.length() == 0:
			continue
		var settings: ScenePainterLabelSettings = label.settings.duplicate()
		settings.position = label.position
		data.labels.push_back(settings)

	return data


func load(data: ScenePainterSceneData) -> void:
	if image != null:
		image.chunk_updated.disconnect(on_chunk_updated)

	dirty_images.clear()
	for label: ScenePainterLabel in labels:
		label_parent.remove_child(label)
		label.queue_free()
	labels.clear()

	if data != null:
		image = data.get_image()
		for settings: ScenePainterLabelSettings in data.labels:
			var label: ScenePainterLabel = create_label()
			label.position = settings.position
			label.set_settings(settings)

		# Update all chunks to handle loading from a file.
		for chunk: Vector2i in image.images.keys():
			dirty_images[chunk] = true
		update_textures()
	else:
		image = ScenePainterImage.new()

	clear_unused_sprites()
	image.chunk_updated.connect(on_chunk_updated)
	modified = false


func is_empty() -> bool:
	var empty: bool = true
	empty = empty && image.is_empty()
	for label: ScenePainterLabel in labels:
		empty = empty && label.text.length() == 0
	return empty


func on_mode_changed() -> void:
	for label: ScenePainterLabel in labels:
		label.queue_redraw()


func update_paint_scale() -> void:
	sprite_parent.scale = Vector2.ONE * toolbar.pixel_scale


func _ready() -> void:
	toolbar.visibility_set.connect(update_visibility)
	toolbar.configured.connect(on_configured)
	toolbar.mode_changed.connect(on_mode_changed)

	image = ScenePainterImage.new()
	image.chunk_updated.connect(on_chunk_updated)

	z_index = 2048

	# Using these to organize the layering of sprites and labels without using more z-indices.
	sprite_parent = Node2D.new()
	add_child(sprite_parent)
	label_parent = Node2D.new()
	add_child(label_parent)

	update_paint_scale()
