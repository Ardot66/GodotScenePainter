@tool
extends Resource
class_name ScenePainterImage

signal chunk_updated(chunk: Vector2i)

const CHUNK_SIZE: Vector2i = Vector2(256, 256)
@export var images: Dictionary[Vector2i, Image]


func pixel_to_chunk(pixel: Vector2i) -> Vector2i:
	return floor(Vector2(pixel) / Vector2(CHUNK_SIZE))


func get_image(chunk: Vector2i) -> Image:
	var image: Image
	if !images.has(chunk):
		image = Image.create_empty(CHUNK_SIZE.x, CHUNK_SIZE.y, false, Image.FORMAT_RGBA8)
		images[chunk] = image
	else:
		image = images[chunk]
	return image


func trim_empty_chunks() -> void:
	var empty_chunks: Array[Vector2i]
	for chunk: Vector2i in images.keys():
		if images[chunk].is_invisible():
			empty_chunks.push_back(chunk)
	for chunk: Vector2i in empty_chunks:
		images.erase(chunk)


func get_covered_chunks(rect: Rect2i) -> Array[Vector2i]:
	var covered_chunks: Array[Vector2i]
	var chunk_rect: Rect2i
	chunk_rect.position = pixel_to_chunk(rect.position)
	chunk_rect.size = pixel_to_chunk(rect.position + rect.size) - chunk_rect.position + Vector2i.ONE
	for x: int in chunk_rect.size.x:
		for y: int in chunk_rect.size.y:
			covered_chunks.push_back(chunk_rect.position + Vector2i(x, y))
	return covered_chunks


func get_chunk_local_rect(chunk: Vector2i, global_rect: Rect2i) -> Rect2i:
	return Rect2i(global_rect.position - chunk * CHUNK_SIZE, global_rect.size)


func fill_rect(rect: Rect2i, color: Color) -> void:
	for chunk: Vector2i in get_covered_chunks(rect):
		get_image(chunk).fill_rect(get_chunk_local_rect(chunk, rect), color)
		chunk_updated.emit(chunk)


func blend_rect(image: Image, source_rect: Rect2i, dest_pos: Vector2i) -> void:
	for chunk: Vector2i in get_covered_chunks(Rect2i(dest_pos, source_rect.size)):
		get_image(chunk).blend_rect(image, source_rect, 
            get_chunk_local_rect(chunk, Rect2i(dest_pos, source_rect.size)).position
        )
		chunk_updated.emit(chunk)


func is_empty() -> bool:
	return images.size() == 0
