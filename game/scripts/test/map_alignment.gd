extends SceneTree
## Independent original-file landmarks plus continuity across every road join.
func _initialize() -> void:
	var m := MapData.load_from("aiji")
	assert(m.tile_count() == 144)
	assert(m.original_layout["knots"].size() == 129)
	assert(m.original_layout["blocks"].size() == 20)
	var maximum := 0.0
	for i in range(m.tile_count()):
		maximum = maxf(maximum, m.route_position(i, 1, 0).distance_to(m.pos_of(i)))
		maximum = maxf(maximum, m.route_position(i, 1, 1).distance_to(m.pos_of(i+1)))
		maximum = maxf(maximum, m.route_position(i, -1, 1).distance_to(m.pos_of(i-1)))
		for f in [0.0, 0.25, 0.5, 0.75, 1.0]:
			assert(m.route_position(i, 1, f).is_finite())
			var uv := m.minimap_uv(i, 1, f)
			assert(uv.x > 0 and uv.x < 1 and uv.y > 0 and uv.y < 1)
		if m.is_plot(i):
			assert(m.plot_transform(i).origin.is_finite())
	# Original upper-left five consecutive plots must form one straight row.
	for i in range(4):
		var a := m.plot_transform(i).origin
		var b := m.plot_transform(i+1).origin
		assert(absf(a.z-b.z) < 0.001)
		assert(a.distance_to(b) > 3.5 and a.distance_to(b) < 3.8)
	assert(maximum < 0.02, "Bezier joins differ from original road positions")
	print("MAP ALIGNMENT PASS: 144 roads, 129 knots, 20 blocks; max join error = ", maximum)
	quit()
