extends MeshInstance3D
class_name OriginalMesh
## Original R6SM/CVD/MD2 vertices and UVs. Animation is visual only.
var _frames: Array[PackedVector3Array] = []
var _uv := PackedVector2Array()
var _indices: Array[PackedInt32Array] = []
var _materials: Array[StandardMaterial3D] = []
var _times: Array = []
var _clips: Dictionary = {}
var _clip := ""
var _clock := 0.0
var _last_frame := -1
var _tick := 0.0

func setup(info: Dictionary) -> void:
	set_meta("source", info.mesh)
	var file := FileAccess.open(str(info.mesh), FileAccess.READ)
	if file == null:
		push_error("Missing original mesh: " + str(info.mesh))
		return
	assert(file.get_buffer(4).get_string_from_ascii() == "R6V1")
	var nf := file.get_32()
	var nv := file.get_32()
	var ns := file.get_32()
	_uv = file.get_buffer(nv * 8).to_vector2_array()
	for i in range(nf):
		_frames.append(file.get_buffer(nv * 12).to_vector3_array())
	for i in range(ns):
		_indices.append(file.get_buffer(file.get_32() * 4).to_int32_array())
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = 0.3
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		var path := str(info.surfaces[i].texture)
		if not path.is_empty():
			mat.albedo_texture = load(path)
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
	_clock += delta
	_tick += delta
	if _tick < 1.0 / 24.0:
		return
	_tick = 0.0
	var frame := 0
	if _clips.has(_clip):
		var sequence: Array = _clips[_clip]
		frame = int(sequence[int(_clock * 12.0) % sequence.size()])
	else:
		var t := fmod(_clock, maxf(float(_times.back()), 0.01))
		for i in range(_times.size()):
			if float(_times[i]) <= t:
				frame = i
	_draw_frame(frame)

func _draw_frame(frame: int) -> void:
	if frame == _last_frame or _frames.is_empty():
		return
	_last_frame = frame
	var result := ArrayMesh.new()
	for i in range(_indices.size()):
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = _frames[frame]
		arrays[Mesh.ARRAY_TEX_UV] = _uv
		arrays[Mesh.ARRAY_INDEX] = _indices[i]
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		result.surface_set_material(i, _materials[i])
	mesh = result

static func load_scene(parent: Node3D, map_name: String) -> bool:
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
	return true
