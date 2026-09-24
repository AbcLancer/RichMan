extends Node
## Rules —— 玩法数值单例（autoload）
##
## 数据来源：F:\游戏\Rich6\config\Initvar_r.txt（原版即时制参数）
## 经 tools/ 提取为 res://data/rules/realtime.json
##
## 原则：所有硬编码数值都必须能追溯到原版配置，不得凭感觉写。

const RULES_PATH := "res://data/rules/realtime.json"

var data: Dictionary = {}

func _ready() -> void:
	_load()

func _load() -> void:
	var f := FileAccess.open(RULES_PATH, FileAccess.READ)
	if f == null:
		push_error("Rules: 无法读取 %s" % RULES_PATH)
		return
	var txt := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Rules: JSON 解析失败")
		return
	data = parsed
	print("[Rules] 已载入 %d 张卡牌定义" % (data.get("cards", []) as Array).size())

func get_val(path: String, default_value = null):
	## 按 "economy.auction.wait_seconds" 形式的路径取值
	var cur = data
	for part in path.split("."):
		if typeof(cur) != TYPE_DICTIONARY or not cur.has(part):
			return default_value
		cur = cur[part]
	return cur

func seconds_per_day() -> float:
	return float(get_val("time.seconds_per_day", 24.0))

func cards() -> Array:
	return data.get("cards", [])

func card_by_id(id: String) -> Dictionary:
	for c in cards():
		if c.get("id", "") == id:
			return c
	return {}
