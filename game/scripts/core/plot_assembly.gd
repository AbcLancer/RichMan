extends RefCounted
class_name PlotAssembly
## Shared read-only construction preview. Server rechecks before any mutation.
static func plan(map: MapData, plots: Dictionary, owner: int, idx: int, kind: String) -> Dictionary:
	if not plots.has(idx) or int(plots[idx].owner) != owner:
		return {}
	var current: Dictionary = plots[idx]
	var level := int(current.level)
	var candidates: Array = []
	if level == 0:
		var sizes := {}
		for grade in Rules.house_grades(kind):
			var side := maxi(int(grade.w), int(grade.h))
			if not sizes.has(side):
				sizes[side] = true
				candidates.push_front(int(grade.level))
	else:
		candidates.append(level + 1)
	for target in candidates:
		if int(target) > Rules.house_max_level(kind):
			continue
		var grade := Rules.house_grade(kind, int(target))
		var side := maxi(int(grade.get("w", 1)), int(grade.get("h", 1)))
		# Existing merged estate retains its land when downgraded/rebuilt.
		side = maxi(side, int(current.get("footprint", 1)))
		var area := _area(map, plots, owner, idx, side)
		if not area.is_empty():
			area.merge({"level": int(target), "type": kind, "cost": Rules.house_upgrade_cost(kind, int(target)),
				"name": str(grade.get("name", "")), "footprint": side})
			return area
	return {}

static func _area(map: MapData, plots: Dictionary, owner: int, idx: int, side: int) -> Dictionary:
	if map.original_layout.is_empty():
		return {"anchor": idx, "members": [idx]} if side == 1 else {}
	var road: Dictionary = map.original_layout.roads[idx]
	var bid := int(road.block)
	if bid < 0:
		return {}
	var block: Dictionary = map.original_layout.blocks[bid]
	var w := int(block.width)
	var h := int(block.depth)
	var cell := int(road.cell)
	var old_members: Array = plots[idx].get("members", [idx])
	for row in range(maxi(0, cell / w - side + 1), mini(cell / w, h - side) + 1):
		for col in range(maxi(0, cell % w - side + 1), mini(cell % w, w - side) + 1):
			var members: Array = []
			var valid := true
			for other in map.original_layout.roads:
				if int(other.block) != bid:
					continue
				var c := int(other.cell)
				if c % w < col or c % w >= col + side or c / w < row or c / w >= row + side:
					continue
				var key := int(other.index)
				if not plots.has(key) or int(plots[key].owner) != owner:
					valid = false
					break
				if not old_members.has(key) and (int(plots[key].level) > 0 or plots[key].has("members")):
					valid = false
					break
				members.append(key)
			for old in old_members:
				if not members.has(int(old)):
					valid = false
			if valid and members.size() >= side:
				members.sort()
				return {"anchor": int(members[0]), "members": members, "block": bid, "cell": row * w + col}
	return {}
