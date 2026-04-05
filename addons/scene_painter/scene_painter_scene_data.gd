@tool
extends Resource
class_name ScenePainterSceneData

@export var images: Dictionary[Vector2i, PackedByteArray]
@export var labels: Array[ScenePainterLabelSettings]


func set_image(image: ScenePainterImage) -> void:
	for chunk: Vector2i in image.images.keys():
		images[chunk] = image.images[chunk].save_png_to_buffer()


func get_image() -> ScenePainterImage:
	var image: ScenePainterImage = ScenePainterImage.new()
	for chunk: Vector2i in images.keys():
		var chunk_image: Image = Image.create_empty(ScenePainterImage.CHUNK_SIZE.x, ScenePainterImage.CHUNK_SIZE.y, false, Image.FORMAT_RGBA8)
		chunk_image.load_png_from_buffer(images[chunk])
		image.images[chunk] = chunk_image
	return image
