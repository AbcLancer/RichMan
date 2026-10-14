extends RefCounted
class_name EffectsReview
var app
var output := "res://../docs/screenshots/effects-review"

func run(root) -> void:
	app = root
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	app._port_edit.text = "0"
	app._frontend.start_requested.emit({"map": "aiji", "role": 5, "players": 4, "money": 300000, "credit": 50})
	Net.set_process(false)
	Net.sim.running = false
	Net.sim.time = Sim.ENTRY_SECONDS + .1 # Exercise effects after landing, rather than during entry.
	var ids: Array = Net.sim.player_ids()
	var catalog: Array = Net.sim.pet_catalog()
	for i in range(catalog.size()):
		Net.sim.add_pet(Net.sim.players[ids[i % ids.size()]], str(catalog[i].id))
	for i in range(ids.size()):
		Net.sim.players[ids[i]].tile = i
	Net.sim.players[1].effects.invincible_until = 10.0
	Net.sim.estate_index = 11.0 # 顶栏必须显示 1.1，而非 11。
	app._on_state(Net.sim.to_dict())
	app._loading.hide()
	await app.get_tree().process_frame
	var effects: WorldEffects = app._board._effects
	assert(effects.pets.size() == 4, "Only the active pet of each player must be visible")
	assert(effects.shields.size() == 1)
	assert(app._hud_price_index._text == "1.1")
	var first: OriginalMesh = app._board._player_nodes[1].get_node("OriginalActor")
	for role in range(1, 13):
		var actor := OriginalMesh.new()
		app.add_child(actor)
		actor.setup(JSON.parse_string(FileAccess.get_file_as_string("res://assets/original/actors/role%d.json" % role)))
		assert(actor._clips.has("run") and actor._clips.has("sad"))
		actor.play("run")
		assert(actor._clip == "run")
		actor.queue_free()
	await shot("followers-and-shield", .4)
	var before: Vector3 = (effects.pets["1:qiongshen"].node as Node3D).global_position
	Net.sim.players[1].moving = 4
	Net.sim.players[1].progress = .7
	app._on_state(Net.sim.to_dict())
	assert(first._clip == "run")
	assert(first._blend_elapsed < first._blend_duration)
	await shot("running-followers", .3)
	assert((effects.pets["1:qiongshen"].node as Node3D).global_position.distance_to(before) > .05)
	app._on_game_event("pay_rent", {"pid": 1, "to": ids[1], "amount": 12345, "idx": 0})
	assert(first._clip == "sad")
	assert(effects.transients.size() >= 9)
	await shot("pay-rent", .35)
	app._on_game_event("road_bomb", {"pid": 1, "idx": 0})
	await shot("explosion", .3)
	app._on_game_event("clear_road", {"pid": 1, "from_idx": 0,
		"path": [1, 2, 3, 4, 5, 6, 7], "removed": 2})
	var bulldozers := effects.transients.filter(func(t): return str(t.kind) == "bulldozer")
	assert(bulldozers.size() == 1, "Clear card must launch the original bulldozer model")
	await shot("clear-bulldozer", 1.0)
	assert(not effects.index.effects.gaijian[0].additive, "Original upgrade effect uses alpha blending")
	app._on_game_event("upgrade", {"pid": 1, "idx": 0})
	app._on_game_event("pet_skill", {"pid": 1, "pet": "qiongshen"})
	assert(effects.casts.has("1:qiongshen"))
	await shot("pet-cast", .75)
	var pet: Dictionary = Net.sim.players[1].pets[0]
	pet.skill_at = Net.sim.time
	var observer := WorldEffects.new()
	app._board.add_child(observer)
	observer.setup(app._board)
	observer.sync(Net.sim.to_dict())
	assert(observer.pets.size() == 4 and observer.casts.has("1:qiongshen"), "Snapshot must recover remote casting phase")
	observer.queue_free()
	Net.sim.time = 11.0
	Net.sim.players[1].effects.invincible_until = 10.0
	Net.sim.players[ids[1]].pets.clear()
	app._on_state(Net.sim.to_dict())
	assert(effects.shields.is_empty() and effects.pets.size() == 3)
	await app.get_tree().create_timer(4.0).timeout
	assert(effects.transients.is_empty(), "Transient effects must be released")
	assert(first._clip == "run", "Reaction must return to locomotion")
	# Backlog is capped even if many events arrive together.
	for i in range(120): effects.floating_text(1, str(i), Color.WHITE)
	assert(effects.transients.size() == WorldEffects.MAX_TRANSIENTS)
	print("WORLD EFFECTS PASS: 4 active pets, remote cast recovery, native shield/explosion, cash transfer, cleanup, 12 normalized actor clips and reaction return")
	app.get_tree().quit()

func shot(name: String, delay: float) -> void:
	await app.get_tree().create_timer(delay).timeout
	await RenderingServer.frame_post_draw
	assert(app.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(output + "/" + name + ".png")) == OK)
