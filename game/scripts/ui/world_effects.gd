extends Node3D
class_name WorldEffects
## Presentation of authoritative snapshots/events, for every player on every peer.
const PET_CAST_SECONDS := 1.4
const MAX_TRANSIENTS := 96
var board
var index: Dictionary = {}
var pets: Dictionary = {}
var shields: Dictionary = {}
var casts: Dictionary = {}
var transients: Array[Dictionary] = []
var clock := 0.0
var world_scale := 1.0
var _textures: Dictionary = {}

func setup(view) -> void:
	board = view
	world_scale = float(board.map.original_layout.get("world_scale", .036)) / .036
	name = "WorldEffects"
	var path := "res://assets/original/effects/index.json"
	if FileAccess.file_exists(path): index = JSON.parse_string(FileAccess.get_file_as_string(path))

func texture(path: String) -> Texture2D:
	if not _textures.has(path): _textures[path] = VisualQuality.texture(path, true)
	return _textures[path]

func sprite(path: String, size: float, additive := false) -> Sprite3D:
	var result := Sprite3D.new()
	result.texture = texture(path)
	result.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	result.shaded = false
	result.transparent = true
	result.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	result.pixel_size = size * world_scale / maxf(result.texture.get_width() if result.texture != null else 64, 1)
	if additive:
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		material.no_depth_test = false
		material.albedo_texture = result.texture
		material.vertex_color_use_as_albedo = true
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		result.material_override = material
	return result

func sync(snapshot: Dictionary) -> void:
	var wanted: Dictionary = {}
	var live: Dictionary = {}
	var players: Dictionary = snapshot.get("players", {})
	for player_key in players:
		var pid := int(player_key)
		var player: Dictionary = players[player_key]
		if not bool(player.get("alive", false)): continue
		if maxf(float(player.get("effects", {}).get("hospital_until", 0.0)),
			float(player.get("effects", {}).get("hotel_until", 0.0))) > float(snapshot.get("t", 0.0)): continue
		live[pid] = true
		var owned: Array = player.get("pets", [])
		var active := str(player.get("pet_active", ""))
		var active_slot := -1
		if active != "none":
			for slot in range(owned.size()):
				var entry: Dictionary = owned[slot]
				if str(entry.get("uid", entry.get("id", ""))) == active or str(entry.get("id", "")) == active:
					active_slot = slot
					break
			if active_slot < 0 and not owned.is_empty(): active_slot = 0
		for slot in range(owned.size()):
			var pet: Dictionary = owned[slot]
			if slot != active_slot: continue
			var pet_id := str(pet.get("id", ""))
			if not index.get("pets", {}).has(pet_id): continue
			var key := "%d:%s" % [pid, pet_id]
			wanted[key] = true
			if not pets.has(key):
				var art := sprite(str(index.pets[pet_id].fly[0]), 1.35)
				art.name = ("Pet_" + key).validate_node_name()
				add_child(art)
				var position: Variant = board.player_pos(pid)
				art.global_position = position + Vector3(0, 2.0, 0) * world_scale if position is Vector3 else Vector3.ZERO
				pets[key] = {"node": art, "pid": pid, "pet": pet_id, "slot": 0, "count": 1, "active": true}
			pets[key].slot = 0
			pets[key].count = 1
			pets[key].active = true
			var elapsed := float(snapshot.get("t", 0.0)) - float(pet.get("skill_at", -100.0))
			if elapsed >= 0 and elapsed < PET_CAST_SECONDS:
				casts[key] = maxf(float(casts.get(key, 0.0)), clock + PET_CAST_SECONDS - elapsed)
		var immune := float(player.get("effects", {}).get("invincible_until", 0.0)) > float(snapshot.get("t", 0.0)) and float(player.get("effects", {}).get("invisible_until", 0.0)) <= float(snapshot.get("t", 0.0))
		if immune and not shields.has(pid):
			var shield := native_effect("wudi", true)
			if shield != null:
				shield.name = "Invincible_%d" % pid
				shields[pid] = shield
		elif not immune and shields.has(pid):
			(shields[pid] as Node3D).queue_free()
			shields.erase(pid)
	for key in pets.keys():
		if not wanted.has(key):
			(pets[key].node as Node3D).queue_free()
			pets.erase(key)
			casts.erase(key)
	for pid in shields.keys():
		if not live.has(pid):
			(shields[pid] as Node3D).queue_free()
			shields.erase(pid)

func native_effect(kind: String, persistent := false) -> Node3D:
	var parts: Array = index.get("effects", {}).get(kind, [])
	if parts.is_empty(): return null
	var root := Node3D.new()
	add_child(root)
	root.scale = Vector3.ONE * world_scale
	root.set_meta("opacity", .4 if kind in ["feidan_exp", "hedan"] else .55)
	if kind in ["gaijian", "chaichu"]: root.scale *= .08
	var duration := 0.0
	for definition in parts:
		var mesh := OriginalMesh.new()
		root.add_child(mesh)
		mesh.setup(definition)
		for material in mesh._materials:
			if material is ShaderMaterial: material.set_shader_parameter("effect_opacity", float(root.get_meta("opacity")))
		# Mesh data was pivot-centered for GPU animation. Restore source offsets.
		mesh.position = mesh._pivot
		var bounds := mesh.custom_aabb.size
		# The source explosion includes an enormous screen-flash plane; bound its
		# scene footprint while retaining the recovered animation and texture.
		if not persistent and maxf(bounds.x, bounds.z) > 50:
			var factor: float = board._tile_spacing * 3.0 / world_scale / maxf(bounds.x, bounds.z)
			mesh.scale *= factor
			mesh.position *= factor
		mesh.animation_loop = persistent
		duration = maxf(duration, mesh.animation_duration())
	if not persistent: track(root, "mesh", maxf(duration, 0.5))
	return root

func track(node: Node3D, kind: String, duration: float, extra: Dictionary = {}) -> void:
	if transients.size() >= MAX_TRANSIENTS:
		var old: Dictionary = transients.pop_front()
		if is_instance_valid(old.node): old.node.queue_free()
	var record := {"node": node, "kind": kind, "age": 0.0, "duration": duration}
	record.merge(extra)
	transients.append(record)

func floating_text(pid: int, text: String, color: Color) -> void:
	var origin: Variant = board.player_pos(pid)
	if not origin is Vector3: return
	var label := Label3D.new()
	label.text = text
	label.font_size = 56
	label.outline_size = 10
	label.pixel_size = 0.007 * world_scale
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = color
	label.no_depth_test = true
	add_child(label)
	label.global_position = origin + Vector3(0, 3.4, 0) * world_scale
	track(label, "text", 1.5, {"origin": label.global_position})

func explosion(origin: Vector3, large := false) -> void:
	var effect := native_effect("hedan" if large else "feidan_exp")
	if effect != null: effect.global_position = origin + Vector3(0, 0.4, 0) * world_scale
	var smoke_path := str(index.get("textures", {}).get("smoke", ""))
	if smoke_path.is_empty(): return
	for i in range(5):
		var smoke := sprite(smoke_path, 8.0, true)
		smoke.hframes = 4
		smoke.vframes = 4
		add_child(smoke)
		smoke.global_position = origin + Vector3(cos(i * 2.4) * 0.6, 0.8, sin(i * 2.4) * 0.6) * world_scale
		track(smoke, "smoke", 1.8 + i * .12, {"origin": smoke.global_position, "delay": i * .05})

static func rent_coin_count(amount: int) -> int:
	# Visual tiers, capped to protect rendering during simultaneous payments.
	return clampi(int(ceil(sqrt(maxi(amount, 0) / 250.0))), 1, 24) if amount > 0 else 0


func on_event(kind: String, data: Dictionary) -> void:
	var pid := int(data.get("pid", -1))
	var origin: Variant = board.player_pos(pid)
	match kind:
		"clear_road":
			var points: Array[Vector3] = []
			var start_point: Variant = board.tile_pos_of(int(data.get("from_idx", -1)))
			if start_point is Vector3: points.append(start_point)
			for road_idx in data.get("path", []):
				var road_point: Variant = board.tile_pos_of(int(road_idx))
				if road_point is Vector3: points.append(road_point)
			if points.size() >= 2:
				var bulldozer: Node3D = board._make_road_node(int(data.get("from_idx", -1)), "bulldozer")
				bulldozer.reparent(self, true)
				bulldozer.global_position = points[0] + Vector3.UP * .12
				track(bulldozer, "bulldozer", float(points.size() - 1) / 2.0,
					{"points": points})
		"platform":
			if board.map.name == "aiji":
				var start: Variant = board.tile_pos_of(int(data.get("idx", -1)))
				var finish: Variant = board.tile_pos_of(int(data.get("to", -1)))
				var carpet_tex := texture("res://assets/decals/rug.png")
				if start is Vector3 and finish is Vector3 and carpet_tex != null:
					var carpet := MeshInstance3D.new()
					carpet.name = "FlyingCarpet"
					var plane := PlaneMesh.new()
					plane.size = Vector2.ONE * board._rug_size()
					carpet.mesh = plane
					var carpet_mat := StandardMaterial3D.new()
					carpet_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
					carpet_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					carpet_mat.albedo_texture = carpet_tex
					carpet.material_override = carpet_mat
					add_child(carpet)
					carpet.global_position = start + Vector3.UP * .12
					var character := board._player_nodes.get(pid) as Node3D
					var actor := character.get_node_or_null("OriginalActor") as OriginalMesh if character != null else null
					track(carpet, "teleport", 1.0, {"pid": pid, "origin": start,
						"destination": finish, "heading": actor.rotation.y if actor != null else 0.0})
		"missile_launch":
			var destination: Variant = board.tile_pos_of(int(data.get("idx", -1)))
			if origin is Vector3 and destination is Vector3:
				var projectile := MeshInstance3D.new()
				var mesh := CapsuleMesh.new()
				mesh.radius = .16 * world_scale
				mesh.height = .8 * world_scale
				projectile.mesh = mesh
				var material := StandardMaterial3D.new()
				material.albedo_color = Color(1, .85, .25)
				material.emission_enabled = true
				material.emission = Color(1, .45, .05)
				projectile.material_override = material
				add_child(projectile)
				projectile.global_position = origin + Vector3.UP * 2.0 * world_scale
				track(projectile, "missile", float(data.get("seconds", 1)),
					{"origin": projectile.global_position, "destination": destination})
		"card_status_applied":
			floating_text(pid, "%s附身 · %d 步" % [Rules.card_name(str(data.get("card", ""))).trim_suffix("卡"), int(data.get("steps", 30))], Color(1, .55, 1))
			if origin is Vector3: sparkle(origin + Vector3.UP * 2.0 * world_scale)
		"card_damage":
			floating_text(pid, "体力 −%d" % int(data.get("damage", 0)), Color(1, .35, .3))
		"hospital":
			if data.has("seconds"): floating_text(pid, "住院 %d 秒" % int(data["seconds"]), Color(1, .7, .7))
		"pay_rent":
			var members: Array = data.get("joint_members", [])
			if members.size() > 1: board.flash_joint_rent(members)
			var amount := int(data.get("amount", 0))
			floating_text(pid, "−$%d" % amount, Color(1, .4, .3))
			var to := int(data.get("to", -1))
			floating_text(to, "+$%d" % amount, Color(.45, 1, .45))
			var destination: Variant = board.plot_pos_of(int(data.get("idx", -1)))
			if origin is Vector3 and destination is Vector3 and amount > 0 and index.get("textures", {}).has("coin"):
				var count := rent_coin_count(amount)
				for i in range(count):
					var coin := sprite(str(index.textures.coin), .48)
					add_child(coin)
					coin.global_position = origin + Vector3(0, 1.5, 0) * world_scale
					var delay := i * .045
					track(coin, "coin", delay + .72, {"from": pid, "to": to,
						"origin": coin.global_position, "destination": destination + Vector3.UP * .6 * world_scale,
						"delay": delay, "flight": .72, "arc": (1.8 + (i % 3) * .12) * world_scale})

		"mine", "road_bomb", "blast":
			var hit: Variant = board.tile_pos_of(int(data.get("idx", data.get("tile", -1))))
			if hit is Vector3: explosion(hit, str(data.get("card", "")) == "nuke")
			elif origin is Vector3: explosion(origin)
		"pet_skill":
			var key := "%d:%s" % [pid, str(data.get("pet", ""))]
			casts[key] = clock + PET_CAST_SECONDS
			if origin is Vector3:
				var effect := native_effect("pk_pet")
				if effect != null:
					effect.scale *= .10
					effect.set_meta("follow_pet", key)
					effect.global_position = (pets[key].node as Node3D).global_position if pets.has(key) else origin + Vector3(0, 2, 0) * world_scale
		"get_pet", "pet_levelup", "road_crystal":
			if origin is Vector3: sparkle(origin + Vector3(0, 2, 0) * world_scale)
		"upgrade", "rebuild":
			var place: Variant = board.plot_pos_of(int(data.get("idx", -1)))
			if place is Vector3:
				var effect := native_effect("gaijian")
				if effect != null: effect.global_position = place
		"downgrade":
			var place: Variant = board.plot_pos_of(int(data.get("idx", -1)))
			if place is Vector3:
				var effect := native_effect("chaichu")
				if effect != null: effect.global_position = place
		"win_money", "road_chest":
			floating_text(pid, "+$%d" % int(data.get("amount", data.get("gain", 0))), Color(.45, 1, .45))

func sparkle(origin: Vector3) -> void:
	var path := str(index.get("textures", {}).get("spark", ""))
	if path.is_empty(): return
	for i in range(8):
		var star := sprite(path, .4, true)
		add_child(star)
		var angle := float(i) / 8 * TAU
		track(star, "spark", .8, {"origin": origin, "direction": Vector3(cos(angle), .5, sin(angle))})

func _process(delta: float) -> void:
	if not is_instance_valid(board) or not board.is_visible_in_tree(): return
	clock += delta
	for key in pets:
		var record: Dictionary = pets[key]
		var art := record.node as Sprite3D
		var origin: Variant = board.player_pos(int(record.pid))
		if not origin is Vector3: continue
		var casting := float(casts.get(key, 0.0)) > clock
		var phase := clock * 1.15 + int(record.slot) * TAU / maxf(int(record.count), 1)
		var offset := Vector3(cos(phase) * 1.45, 2.0 + sin(clock * 3 + int(record.slot)) * .18, sin(phase) * 1.45)
		if casting: offset.y += .65
		offset *= world_scale
		var target: Vector3 = origin + offset
		art.global_position = target if art.global_position.distance_to(target) > 12 else art.global_position.lerp(target, 1 - exp(-delta * 7))
		var frames: Array = index.pets[record.pet]["cast" if casting else "fly"]
		var frame := mini(3, int((PET_CAST_SECONDS - (float(casts.get(key, 0.0)) - clock)) / PET_CAST_SECONDS * 4)) if casting else int(clock * 9) % 4
		art.texture = texture(str(frames[maxi(frame, 0)]))
		art.scale = Vector3.ONE * (1.12 if record.active else 1.0)
	for pid in shields:
		var origin: Variant = board.player_pos(int(pid))
		if origin is Vector3: (shields[pid] as Node3D).global_position = origin + Vector3(0, 1.4, 0) * world_scale
	for i in range(transients.size() - 1, -1, -1):
		var record: Dictionary = transients[i]
		record.age += delta
		var node := record.node as Node3D
		if not is_instance_valid(node) or float(record.age) >= float(record.duration):
			if is_instance_valid(node): node.queue_free()
			transients.remove_at(i)
			continue
		var progress := clampf(float(record.age) / float(record.duration), 0, 1)
		match record.kind:
			"bulldozer":
				var path_points: Array = record.points
				var segment := minf(progress * (path_points.size() - 1), path_points.size() - 1.001)
				var segment_index := int(floor(segment))
				var from_point: Vector3 = path_points[segment_index]
				var to_point: Vector3 = path_points[segment_index + 1]
				node.global_position = from_point.lerp(to_point, segment - segment_index) + Vector3.UP * .12
				var heading := to_point - from_point
				node.rotation.y = atan2(heading.x, heading.z)
			"teleport":
				var smooth := progress * progress * (3.0 - 2.0 * progress)
				var path: Vector3 = (record.origin as Vector3).lerp(record.destination, smooth)
				node.global_position = path + Vector3.UP * (.12 + sin(progress * PI) * .32)
				var character := board._player_nodes.get(int(record.pid)) as Node3D
				if character != null:
					character.global_position = path + Vector3.UP * sin(progress * PI) * .32
					var actor := character.get_node_or_null("OriginalActor") as OriginalMesh
					if actor != null: actor.rotation.y = float(record.get("heading", 0.0)) + TAU * progress
			"missile":
				var destination: Vector3 = record.destination
				node.global_position = (record.origin as Vector3).lerp(destination, progress) + Vector3.UP * sin(progress * PI) * 4.0 * world_scale
			"mesh":
				var follow := str(node.get_meta("follow_pet", ""))
				if pets.has(follow): node.global_position = (pets[follow].node as Node3D).global_position
				for child in node.get_children():
					if child is OriginalMesh:
						for material in child._materials:
							if material is ShaderMaterial: material.set_shader_parameter("effect_opacity", float(node.get_meta("opacity", .45)) * minf(1, (1 - progress) * 4))
			"coin":
				var phase := clampf((float(record.age) - float(record.delay)) / float(record.flight), 0, 1)
				node.visible = float(record.age) >= float(record.delay)
				node.global_position = (record.origin as Vector3).lerp(record.destination, phase) + Vector3.UP * 4.0 * phase * (1.0 - phase) * float(record.arc)

			"text":
				node.global_position = record.origin + Vector3(0, progress * 1.2, 0) * world_scale
				(node as Label3D).modulate.a = minf(1, (1 - progress) * 3)
			"smoke":
				(node as Sprite3D).frame = mini(15, int(progress * 16))
				node.global_position = record.origin + Vector3(0, progress * 2, 0) * world_scale
				node.scale = Vector3.ONE * (1 + progress * .5)
				(node as Sprite3D).modulate.a = minf(1, (1 - progress) * 3)
			"spark":
				node.global_position = record.origin + record.direction * progress * 1.8 * world_scale
				(node as Sprite3D).modulate.a = 1 - progress
	for key in casts.keys():
		if float(casts[key]) < clock - 2: casts.erase(key)
