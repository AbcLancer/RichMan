@tool
extends RefCounted
class_name VisualQuality
## Optional enhancement overlay. Asset definitions and manual map transforms stay original.
static var enabled := true
static var remade := OS.get_cmdline_user_args().has("--remade-assets")
static var _manifest: Dictionary = {}
static var _loaded := false
static var _textures: Dictionary = {}
static var _texture_costs: Dictionary = {}
static var _cache_bytes := 0
const CACHE_BUDGET := 256 * 1024 * 1024
static var _material_rules: Dictionary = {}

static func use_profile(profile: String) -> void:
	enabled = profile != "original"
	remade = profile == "remade"
	_loaded = false
	_manifest = {}

static func manifest() -> Dictionary:
	if not _loaded:
		_loaded = true
		var path := "res://assets/remade/manifest.json" if remade else "res://assets/enhanced/manifest.json"
		if FileAccess.file_exists(path):
			var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if data is Dictionary:
				_manifest = data
	return _manifest

static func alpha_mode(source: String) -> String:
	if _material_rules.is_empty():
		var path := "res://data/render/materials.json"
		if FileAccess.file_exists(path):
			_material_rules = JSON.parse_string(FileAccess.get_file_as_string(path))
	return str(_material_rules.get(source, {}).get("mode", "cutout"))

static func mesh_path(source: String) -> String:
	if not enabled:
		return source
	var path := str(manifest().get("meshes", {}).get(source, source))
	var source_hash := str(manifest().get("mesh_hashes", {}).get(source, ""))
	if not source_hash.is_empty() and FileAccess.file_exists(source) and FileAccess.get_md5(source) != source_hash:
		return source
	return path if FileAccess.file_exists(path) else source

static func texture(source: String, logical_size := false) -> Texture2D:
	if source.is_empty():
		return null
	var key := source + str(enabled) + str(remade) + str(logical_size)
	if _textures.has(key):
		var cached: Texture2D = _textures[key]
		_textures.erase(key)
		_textures[key] = cached
		return cached
	var replacement := str(manifest().get("textures", {}).get(source, "")) if enabled else ""
	# Manual edits to an original PNG take priority over an outdated enhancement.
	var source_hash := str(manifest().get("source_hashes", {}).get(source, ""))
	if not replacement.is_empty() and not source_hash.is_empty() and FileAccess.file_exists(source):
		if FileAccess.get_md5(source) != source_hash:
			replacement = ""
	var result: Texture2D
	var physical_size := Vector2.ZERO
	if not replacement.is_empty() and ResourceLoader.exists(replacement):
		result = load(replacement) as Texture2D
		if result != null:
			physical_size = result.get_size()
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
		if result != null:
			physical_size = result.get_size()
	if result != null and not logical_size and enabled:
		var image := result.get_image()
		if image != null and not image.has_mipmaps():
			if image.is_compressed():
				image.decompress()
			image.generate_mipmaps()
			result = ImageTexture.create_from_image(image)
	_textures[key] = result
	var cost := int(physical_size.x * physical_size.y * 4.0 * (1.34 if result != null and result.has_mipmaps() else 1.0))
	_texture_costs[key] = cost
	_cache_bytes += cost
	# Old maps can release their textures. Active materials still hold their own refs.
	while _cache_bytes > CACHE_BUDGET and _textures.size() > 1:
		var oldest: String = str(_textures.keys()[0])
		_cache_bytes -= int(_texture_costs[oldest])
		_texture_costs.erase(oldest)
		_textures.erase(oldest)
	return result
