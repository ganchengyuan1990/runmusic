extends Node
## 加载 / 校验 JSON 谱面；提供按时间查询的音符队列。

const ALLOWED_TYPES := ["jump", "slide", "block", "hold", "buddy", "low", "high", "pit", "platform", "checkpoint"]
const SCHEMA_VERSION := 1


## 公园关卡把旧音符名收成同一套：矮丛 / 花门 / 坑 / 平台 / 布布。
func canonical_type(ntype: String) -> String:
	match ntype:
		"jump", "low":
			return "low"
		"slide", "high":
			return "high"
		"block", "pit":
			return "pit"
		"hold", "platform":
			return "platform"
		_:
			return ntype

## 当前已加载谱面（Dictionary）；未加载时为空。
var chart: Dictionary = {}
## 按 t 升序的音符数组（校验后副本）。
var notes: Array = []
var _load_errors: PackedStringArray = PackedStringArray()


func get_last_errors() -> PackedStringArray:
	return _load_errors


## 从 res:// 或绝对路径加载 JSON。成功返回 true。
func load_chart(path: String) -> bool:
	_load_errors = PackedStringArray()
	chart = {}
	notes = []
	if not FileAccess.file_exists(path):
		_fail("file not found: %s" % path)
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		_fail("cannot open: %s" % path)
		return false
	var text := f.get_as_text()
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		_fail("root must be object")
		return false
	if not validate_chart(data):
		return false
	chart = data
	notes = (data.get("notes", []) as Array).duplicate(true)
	notes.sort_custom(func(a, b): return float(a.get("t", 0.0)) < float(b.get("t", 0.0)))
	return true


func validate_chart(data: Dictionary) -> bool:
	_load_errors = PackedStringArray()
	var ok := true
	var ver := int(data.get("schemaVersion", -1))
	if ver != SCHEMA_VERSION:
		_fail("schemaVersion must be %d (got %s)" % [SCHEMA_VERSION, ver])
		ok = false
	for key in ["songId", "title", "audio", "bpm", "durationSec", "notes"]:
		if not data.has(key):
			_fail("missing field: %s" % key)
			ok = false
	var note_list: Array = data.get("notes", [])
	if typeof(note_list) != TYPE_ARRAY:
		_fail("notes must be array")
		return false
	var duration := float(data.get("durationSec", 0.0))
	var seen: Dictionary = {}
	var prev_t := -INF
	for i in note_list.size():
		var n = note_list[i]
		if typeof(n) != TYPE_DICTIONARY:
			_fail("notes[%d] must be object" % i)
			ok = false
			continue
		var t := float(n.get("t", -1.0))
		var ntype := str(n.get("type", ""))
		var kind := canonical_type(ntype)
		if t < 0.0:
			_fail("notes[%d].t invalid" % i)
			ok = false
		if t >= duration + 1.0:
			_fail("notes[%d].t >= durationSec+1" % i)
			ok = false
		if n.has("lane"):
			var lane := int(n.get("lane", -1))
			if lane < 0 or lane > 2:
				_fail("notes[%d].lane must be 0..2" % i)
				ok = false
		if ntype not in ALLOWED_TYPES:
			_fail("notes[%d].type unknown: %s" % [i, ntype])
			ok = false
		if t < prev_t - 0.0001:
			_fail("notes not ascending by t at index %d" % i)
			ok = false
		prev_t = t
		var key := "%.6f|%s" % [t, kind]
		if seen.has(key):
			_fail("duplicate note at t=%s type=%s" % [t, kind])
			ok = false
		seen[key] = true
		if kind == "platform" and not n.has("duration") and not n.has("width"):
			_fail("notes[%d] platform missing width or duration" % i)
			ok = false
		if n.has("width") and float(n.get("width", 0.0)) <= 0.0:
			_fail("notes[%d].width must be > 0" % i)
			ok = false
		if n.has("height") and float(n.get("height", 0.0)) <= 0.0:
			_fail("notes[%d].height must be > 0" % i)
			ok = false
	return ok


## 返回 song_time 之后即将到达的音符（只读视图；Phase 1 可改为游标）。
func peek_upcoming(song_time: float, look_ahead: float) -> Array:
	var out: Array = []
	for n in notes:
		var t := float(n.get("t", 0.0))
		if t < song_time:
			continue
		if t > song_time + look_ahead:
			break
		out.append(n)
	return out


func _fail(msg: String) -> void:
	_load_errors.append(msg)
	push_warning("ChartLoader: %s" % msg)
