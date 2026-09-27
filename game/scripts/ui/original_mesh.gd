@tool
extends MeshInstance3D
class_name OriginalMesh
## Original R6SM/CVD/MD2 vertices and UVs. Animation is visual only.
var _frames: Array[PackedVector3Array] = []
var _uv := PackedVector2Array()
var _indices: Array[PackedInt32Array] = []
var _materials: Array[Material] = []
var _times: Array = []
var _clips: Dictionary = {}
var _clip := ""
var _clock := 0.0
var _last_frame := -1
var _speed := 1.0
var _pivot := Vector3.ZERO
var _position_texture: ImageTexture
var _normal_texture: ImageTexture
var _normals: Array[PackedVector3Array] = []
@export_file("*.json") var definition_path := ""

func _validate_property(property: Dictionary) -> void:
	# Editor saves transforms/definition only, never megabytes of generated meshes.
	if property.name in ["mesh", "custom_aabb", "material_override"]:
		property.usage = int(property.usage) & ~PROPERTY_USAGE_STORAGE

func _ready() -> void:
	if not definition_path.is_empty():
		setup(JSON.parse_string(FileAccess.get_file_as_string(definition_path)))

func setup(info: Dictionary) -> void:
	_frames.clear()
	_normals.clear()
	_indices.clear()
	_materials.clear()
	_clock = 0.0
	_last_frame = -1
	_speed = float(info.get("speed", 1.0))
	var pivot_data: Array = info.get("pivot", [0, 0, 0])
	_pivot = Vector3(pivot_data[0], pivot_data[1], pivot_data[2])
	set_meta("source", info.mesh)
	set_meta("original_name", info.get("name", ""))
	var file := FileAccess.open(VisualQuality.mesh_path(str(info.mesh)), FileAccess.READ)
	if file == null:
		push_error("Missing original mesh: " + str(info.mesh))
		return
	var format := file.get_buffer(4).get_string_from_ascii()
	assert(format in ["R6V1", "R6V2"])
	var nf := file.get_32()
	var nv := file.get_32()
	var ns := file.get_32()
	_uv = file.get_buffer(nv * 8).to_vector2_array()
	for i in range(nf):
		_frames.append(file.get_buffer(nv * 12).to_vector3_array())
	if format == "R6V2":
		var normal_bytes := file.get_buffer(nf * nv * 12)
		for i in range(nf):
			_normals.append(normal_bytes.slice(i * nv * 12, (i + 1) * nv * 12).to_vector3_array())
		_normal_texture = ImageTexture.create_from_image(Image.create_from_data(nv, nf, false, Image.FORMAT_RGBF, normal_bytes))
	if nf > 1:
		var bytes := PackedByteArray()
		var bounds := AABB(_frames[0][0], Vector3.ZERO)
		for frame in _frames:
			bytes.append_array(frame.to_byte_array())
			for v in frame:
				bounds = bounds.expand(v)
		custom_aabb = AABB(bounds.position - _pivot, bounds.size)
		_position_texture = ImageTexture.create_from_image(Image.create_from_data(nv, nf, false, Image.FORMAT_RGBF, bytes))
	for i in range(ns):
		_indices.append(file.get_buffer(file.get_32() * 4).to_int32_array())
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = 0.3
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		var path := str(info.surfaces[i].texture)
		if not path.is_empty():
			mat.albedo_texture = VisualQuality.texture(path)
		if nf > 1:
			var animated := ShaderMaterial.new()
			animated.shader = preload("res://scripts/ui/original_animation.gdshader")
			animated.set_shader_parameter("position_frames", _position_texture)
			animated.set_shader_parameter("pivot", _pivot)
			animated.set_shader_parameter("has_normals", not _normals.is_empty())
			if not _normals.is_empty():
				animated.set_shader_parameter("normal_frames", _normal_texture)
			animated.set_shader_parameter("has_skin", mat.albedo_texture != null)
			if mat.albedo_texture != null:
				animated.set_shader_parameter("skin", mat.albedo_texture)
			_materials.append(animated)
		else:
			_materials.append(mat)
	_times = info.get("times", [0])
	_clips = info.get("clips", {})
	_draw_frame(0)
	set_process(nf > 1)

func play(clip: String) -> void:
	if _clip != clip and _clips.has(clip):
		_clip = clip
		_clock = 0.0

func _process(delta: float) -> void:
	if _frames.size() < 2:
		return
	_clock += delta * _speed
	var a := 0
	var b := 0
	var weight := 0.0
	if _clips.has(_clip):
		var sequence: Array = _clips[_clip]
		var phase := fmod(_clock * 12.0, float(sequence.size()))
		var index := int(phase)
		a = int(sequence[index])
		b = int(sequence[(index + 1) % sequence.size()])
		weight = phase - index
	else:
		var t := fmod(_clock, maxf(float(_times.back()), 0.01))
		# Binary search avoids scanning every source key on every rendered frame.
		var lo := 0
		var hi := _times.size() - 1
		while lo + 1 < hi:
			var mid := (lo + hi) / 2
			if float(_times[mid]) <= t:
				lo = mid
			else:
				hi = mid
		a = lo
		b = hi
		weight = clampf((t - float(_times[a])) / maxf(float(_times[b]) - float(_times[a]), 0.00001), 0, 1)
	for material in _materials:
		var animated := material as ShaderMaterial
		animated.set_shader_parameter("frame_a", a)
		animated.set_shader_parameter("frame_b", b)
		animated.set_shader_parameter("frame_mix", weight)


func _draw_frame(frame: int) -> void:
	if frame == _last_frame or _frames.is_empty():
		return
	_last_frame = frame
	var result := ArrayMesh.new()
	for i in range(_indices.size()):
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		var vertices := _frames[frame].duplicate()
		for j in range(vertices.size()):
			vertices[j] -= _pivot
		arrays[Mesh.ARRAY_VERTEX] = vertices
		if not _normals.is_empty():
			arrays[Mesh.ARRAY_NORMAL] = _normals[frame]
		arrays[Mesh.ARRAY_TEX_UV] = _uv
		arrays[Mesh.ARRAY_INDEX] = _indices[i]
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		result.surface_set_material(i, _materials[i])
	mesh = result

static func load_scene(parent: Node3D, map_name: String) -> bool:
	var editable := "res://scenes/maps/%s.tscn" % map_name
	if ResourceLoader.exists(editable):
		var packed := load(editable) as PackedScene
		parent.add_child(packed.instantiate())
		return true
	var path := "res://assets/original/scenes/%s/scene.json" % map_name
	if not FileAccess.file_exists(path):
		return false
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var root := Node3D.new()
	root.name = "OriginalScene"
	parent.add_child(root)
	for info in data.meshes + data.animations:
		var instance := OriginalMesh.new()
		root.add_child(instance)
		instance.setup(info)
		instance.name = str(info.get("name", "Mesh" )).validate_node_name()
		instance.position = instance._pivot
	return true
