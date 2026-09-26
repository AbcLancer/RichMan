extends Node
## Track-only animation, GPU interpolation, mesh reuse and editable-scene persistence.
func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var packed := load("res://scenes/maps/china.tscn") as PackedScene
	var scene := packed.instantiate() as Node3D
	add_child(scene)
	var dragon := scene.get_node("Animations/longdeng") as Node3D
	assert(dragon.get_child_count() == 10)
	for item in scene.find_children("*", "MeshInstance3D", true, false):
		item.set_process(false)
	var max_motion := 0.0
	for item in dragon.get_children():
		var actor := item as OriginalMesh
		assert(actor._frames.size() >= 101)
		var original_mesh := actor.mesh
		for i in range(actor._frames[0].size()):
			max_motion = maxf(max_motion, actor._frames[0][i].distance_to(actor._frames[50][i]))
		actor._process(1.0 / 60.0)
		var material := actor.mesh.surface_get_material(0) as ShaderMaterial
		var blend := float(material.get_shader_parameter("frame_mix"))
		assert(blend > 0.0 and blend < 1.0)
		assert(actor.mesh == original_mesh, "Must not rebuild mesh per frame")
	assert(max_motion > 1.0, "Track-only dragon must change position")
	var player := OriginalMesh.new()
	add_child(player)
	player.setup(JSON.parse_string(FileAccess.get_file_as_string("res://assets/original/actors/role1.json")))
	player.play("run")
	player._process(1.0 / 60.0)
	var player_mat := player.mesh.surface_get_material(0) as ShaderMaterial
	assert(absf(float(player_mat.get_shader_parameter("frame_mix")) - 0.2) < 0.0001)
	# Save a hand-moved scene to a temporary user file; source scene remains untouched.
	dragon.position += Vector3(2, 3, 4)
	var expected := dragon.position
	var edited := PackedScene.new()
	assert(edited.pack(scene) == OK)
	var target := "user://manual_scene_roundtrip.tscn"
	assert(ResourceSaver.save(edited, target) == OK)
	var text := FileAccess.get_file_as_string(target)
	assert(not text.contains("sub_resource"), "Generated GPU data must not be serialized")
	var restored := (load(target) as PackedScene).instantiate()
	assert(restored.get_node("Animations/longdeng").position.is_equal_approx(expected))
	restored.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(target))
	print("ANIMATION PASS: 10 dragon parts; displacement=", max_motion, "; GPU subframe interpolation; stable mesh; editable scene roundtrip")
	get_tree().quit()

