@tool
extends RefCounted
class_name VisualQuality
## Optional enhancement overlay. Asset definitions and manual map transforms stay original.
static var enabled := true
static var _manifest: Dictionary = {}
static var _loaded := false
static var _textures: Dictionary = {}

static func manifest() -> Dictionary:
	if not _loaded:
		_loaded = true
		var path := "res://assets/enhanced/manifest.json"
		if FileAccess.file_exists(path):
			var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if data is Dictionary:
				_manifest = data
	return _manifest

static func mesh_path(source: String) -> String:
	if not enabled:
		return source
	var path := str(manifest().get("meshes", {}).get(source, source))
	return path if FileAccess.file_exists(path) else source

static func texture(source: String, logical_size := false) -> Texture2D:
	if source.is_empty():
		return null
	var key := source + str(enabled) + str(logical_size)
	if _textures.has(key):
		return _textures[key]
	var replacement := str(manifest().get("textures", {}).get(source, "")) if enabled else ""
	var result: Texture2D
	if not replacement.is_empty() and ResourceLoader.exists(replacement):
		result = load(replacement) as Texture2D
		if logical_size and result != null:
			var dimensions: Array = manifest().get("texture_sizes", {}).get(source, [])
			if dimensions.size() == 2:
				var image := result.get_image()
				if image.is_compressed():
					image.decompress()
				var ui_texture := ImageTexture.create_from_image(image)
				# Full HD pixels, original logical dimensions: sprite-sheet regions,
				# nine-patch margins and button layout all retain their coordinates.
				ui_texture.set_size_override(Vector2i(int(dimensions[0]), int(dimensions[1])))
				result = ui_texture
	elif ResourceLoader.exists(source):
		result = load(source) as Texture2D
	_textures[key] = result
	return result
