extends Node
func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var map := MapData.load_from("aiji")
	var sim := Sim.new()
	sim.setup(map, 123)
	var p := sim.add_player(1, "三联地验证")
	sim.add_player(2, "对手")
	for i in [0, 1, 2]:
		sim.plots[i] = {"owner": 1, "level": 0, "type": ""}
	var plan := sim.construction_plan(1, 1, "industry")
	assert(int(plan.level) == 7 and int(plan.footprint) == 3)
	assert(plan.members == [0, 1, 2] and int(plan.cell) == 0)
	p.last_plot = 1
	p.last_plot_kind = "upgrade"
	var money := int(p.money)
	p.money = 0
	assert(not sim.act_upgrade(1, "industry"))
	assert(sim.plots[1].type == "" and not sim.plots[1].has("members"))
	p.money = money
	assert(sim.act_upgrade(1, "industry"))
	assert(int(p.money) == money - 6000)
	assert(sim.unique_plot_keys() == [0])
	assert(not sim.act_upgrade(1, "industry"), "One arrival, one construction")
	# Restore exactly as clients do: deep duplicated dictionaries lose aliases.
	var remote := Sim.new()
	remote.setup(map, 1)
	remote.apply_dict(sim.to_dict())
	assert(remote.force_upgrade(1, 2, true))
	assert(int(remote.plots[0].level) == 8 and int(remote.plots[1].level) == 8)
	remote._damage_area(1, 1, 0, 2)
	assert(int(remote.plots[0].level) == 7, "Area damage once per building")
	remote.plots[1].owner = 2
	assert(int(remote.plots[2].owner) == 2, "Transfer whole estate")
	# Cannot take a neighbour's land or merge another existing building.
	var blocked := Sim.new()
	blocked.setup(map, 4)
	blocked.add_player(1, "甲")
	blocked.add_player(2, "乙")
	blocked.plots[0] = {"owner": 1, "level": 3, "type": "industry"}
	blocked.plots[1] = {"owner": 2, "level": 0, "type": ""}
	assert(blocked.construction_plan(1, 0).is_empty())
	assert(not blocked.force_upgrade(1, 0, true), "Cards cannot bypass ownership")
	blocked.plots[1].owner = 1
	assert(int(blocked.construction_plan(1, 0).footprint) == 2)
	blocked.plots[1].level = 1
	assert(blocked.construction_plan(1, 0).is_empty())
	# Original marker and merged building rendering, using production BoardView.
	var world := Node3D.new()
	add_child(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.current = true
	var board := BoardView.new()
	world.add_child(board)
	board.build(map)
	for i in [3, 4, 5, 6, 7, 8, 13, 14, 15, 16, 18, 19]:
		var id := sim.players.size() + 1
		var player := sim.add_player(id, "标志%d" % id)
		player.role = id - 2
		sim.plots[i] = {"owner": id, "level": 0, "type": ""}
	board.sync(sim.to_dict())
	board.set_process(false)
	assert(board._level_nodes.size() == 1, "Merged estate renders one building")
	assert(not board._plot_nodes.has(1) and not board._plot_nodes.has(2))
	assert(board._plot_nodes[3].get_node("OwnerMarker").visible)
	var center: Vector3 = board._level_nodes[0].position
	camera.position = center + Vector3(9, 14, 19)
	camera.look_at(center + Vector3(0, 1, 0))
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	var path := "D:/Projects/RichMan/docs/screenshots/scene-recovery/merged-industry.png"
	get_viewport().get_texture().get_image().save_png(path)
	print("PLOT ASSEMBLY PASS: 3 plots -> industry level 7; cost/ownership/atomicity/replication/damage/render/markers")
	get_tree().quit()
