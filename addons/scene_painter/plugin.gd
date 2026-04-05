@tool
extends EditorPlugin

const TOOLBAR_SCENE: PackedScene = preload("res://addons/scene_painter/toolbar.tscn")

var container: SubViewportContainer
var overlays: Dictionary[String, ScenePainterOverlay]
var open_overlay: ScenePainterOverlay
var toolbar: ScenePainterToolbar

var saving: bool = false


func _input(event: InputEvent) -> void:
	if open_overlay == null || !container.is_visible_in_tree():
		return

	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	if open_overlay.viewport_input(container.get_global_rect().has_point(mouse_pos), event):
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if open_overlay == null || !container.is_visible_in_tree():
		return

	open_overlay.viewport_process()


func get_paint_file_path(filepath: String) -> String:
	return filepath.substr("res://".length()).get_basename() + ".paint.tres"


func load_scene_data(filepath: String) -> ScenePainterSceneData:
	var dir: DirAccess = DirAccess.open(toolbar.data_folder)
	if dir == null:
		return null

	var subpath: String = get_paint_file_path(filepath)
	if !dir.file_exists(subpath):
		return null
	return ResourceLoader.load(toolbar.data_folder + "/" + subpath)


func init_scene_directory(filepath: String) -> void:
	var dir: DirAccess = DirAccess.open(toolbar.data_folder)

	var subpath: String = get_paint_file_path(filepath)
	var split_path: PackedStringArray = subpath.split("/")
	for i: int in split_path.size():
		if i == split_path.size() - 1:
			break

		if !dir.dir_exists(split_path[i]):
			dir.make_dir(split_path[i])

		dir.change_dir(split_path[i])


func save_scene_data(filepath: String, image: ScenePainterSceneData) -> void:
	saving = true
	var dir: DirAccess = DirAccess.open(toolbar.data_folder)
	if dir == null:
		printerr("Unable to save painting for the current scene, as the ScenePainter data directory \"", toolbar.data_folder, "\" does not exist.")
		return

	init_scene_directory(filepath)
	var path: String = toolbar.data_folder + "/" + get_paint_file_path(filepath)
	var exists = FileAccess.file_exists(path)
	ResourceSaver.save(image, path)
	if !exists:
		EditorInterface.get_resource_filesystem().scan()
	# Need set_deferred, otherwise the check in on_filesystem_changed will never activate.
	set_deferred(&"saving", false)


func trim_empty_directories(dir: DirAccess = null) -> void:
	if dir == null:
		dir = DirAccess.open(toolbar.data_folder)

	var cur_dir: String = dir.get_current_dir()
	var files: PackedStringArray = dir.get_files()
	var subdirs: PackedStringArray = dir.get_directories()
	for subdir: String in subdirs:
		dir.change_dir(subdir)
		trim_empty_directories(dir)

	subdirs = dir.get_directories()
	dir.change_dir("..")
	if cur_dir != toolbar.data_folder && subdirs.size() == 0 && files.size() == 0:
		dir.remove(cur_dir)


func reload_scene_data(root: Node) -> void:
	if open_overlay == null || open_overlay.modified:
		return

	var scene_data: ScenePainterSceneData = load_scene_data(root.scene_file_path)
	open_overlay.load(scene_data)


func on_scene_changed(root: Node) -> void:
	var overlay: ScenePainterOverlay = overlays.get(root.scene_file_path)
	if open_overlay != null:
		open_overlay.active = false
		open_overlay.update_visibility()

	if overlay == null:
		overlay = ScenePainterOverlay.new()
		overlay.toolbar = toolbar
		overlays[root.scene_file_path] = overlay
		EditorInterface.get_editor_viewport_2d().add_child(overlay)

		open_overlay = overlay
		reload_scene_data(root)
		toolbar.broadcast_configuration()

	overlay.active = true
	overlay.update_visibility()
	open_overlay = overlay


func on_scene_saved(filepath: String) -> void:
	var overlay: ScenePainterOverlay = overlays[filepath]
	if overlay.is_empty() || !overlay.modified:
		return
	save_scene_data(filepath, overlay.save())


func on_scene_closed(filepath: String) -> void:
	var overlay: ScenePainterOverlay = overlays[filepath]
	overlays.erase(filepath)
	overlay.get_parent().remove_child(overlay)
	overlay.queue_free()
	if overlay == open_overlay:
		open_overlay = null


func on_file_moved(old_file: String, new_file: String) -> void:
	if old_file.get_extension() == "tscn":
		var from_paint_path: String = toolbar.data_folder + "/" + get_paint_file_path(old_file)
		if FileAccess.file_exists(from_paint_path):
			var to_paint_path: String = toolbar.data_folder + "/" + get_paint_file_path(new_file)

			init_scene_directory(new_file)
			DirAccess.rename_absolute(from_paint_path, to_paint_path)
			trim_empty_directories()
			EditorInterface.get_resource_filesystem().scan()

	var overlay: ScenePainterOverlay = overlays.get(old_file)
	if overlay == null:
		return
	overlays[new_file] = overlays[old_file]
	overlays.erase(old_file)


func on_file_removed(file: String) -> void:
	if file.get_extension() == "tscn":
		var paint_path: String = toolbar.data_folder + "/" + get_paint_file_path(file)
		if FileAccess.file_exists(paint_path):
			DirAccess.remove_absolute(paint_path)
			trim_empty_directories()
			EditorInterface.get_resource_filesystem().scan()


func on_filesystem_changed() -> void:
	# This check prevents a reload from occurring every time the scene is saved.
	if !saving:
		reload_scene_data(EditorInterface.get_edited_scene_root())


func _get_window_layout(config: ConfigFile) -> void:
	toolbar.get_window_layout(config)


func _set_window_layout(config: ConfigFile) -> void:
	toolbar.set_window_layout(config)


func _enter_tree() -> void:
	scene_changed.connect(on_scene_changed)
	scene_saved.connect(on_scene_saved)
	scene_closed.connect(on_scene_closed)

	var filesystem: FileSystemDock = EditorInterface.get_file_system_dock()
	filesystem.files_moved.connect(on_file_moved)
	filesystem.file_removed.connect(on_file_removed)

	EditorInterface.get_resource_filesystem().filesystem_changed.connect(on_filesystem_changed)

	var viewport: Viewport = EditorInterface.get_editor_viewport_2d()
	container = viewport.get_parent()

	toolbar = TOOLBAR_SCENE.instantiate()
	add_control_to_container(CONTAINER_CANVAS_EDITOR_MENU, toolbar)
	# So this is a little cursed, but it correctly grabs the outer toolbar (not the highlighted one),
	# which is ideal for more permanent UI that should always be visible.
	var toolbar_parent: Node = toolbar.get_parent().get_parent().get_parent().get_child(0)
	remove_control_from_container(CONTAINER_CANVAS_EDITOR_MENU, toolbar)

	toolbar_parent.add_child(toolbar)
	toolbar_parent.move_child(toolbar, -1)
	toolbar.plugin_ready()

	var scene_root: Node = EditorInterface.get_edited_scene_root()
	if scene_root != null:
		on_scene_changed(scene_root)


func _exit_tree() -> void:
	toolbar.get_parent().remove_child(toolbar)
	toolbar.plugin_exit()

	for overlay: ScenePainterOverlay in overlays.values():
		overlay.get_parent().remove_child(overlay)
		overlay.queue_free()
