extends RefCounted
class_name ChartDraft
## 打点中的谱面。导出字段对齐 ChartLoader schemaVersion 1（公园：low / high / pit / platform / buddy）。

const SCHEMA_VERSION := 1
const NOTE_TYPES: Array[String] = ["low", "high", "pit", "platform", "buddy"]
const LABELS := {
	"low": "矮丛",
	"high": "花门",
	"pit": "坑",
	"platform": "平台",
	"buddy": "布布",
	"jump": "矮丛",
	"slide": "花门",
	"block": "坑",
	"hold": "平台",
	"checkpoint": "检查点",
}
const DEFAULT_PIT_WIDTH := 128
const DEFAULT_PLATFORM_WIDTH := 200
const DEFAULT_PLATFORM_HEIGHT := 68
const UNDO_LIMIT := 80

var song_id := "custom_01"
var title := "未命名"
var artist := ""
var audio := ""
var bpm := 120.0
var offset_ms := 0
var duration_sec := 60.0
var approach_sec := 4.5
var px_per_sec := 280
var course := "romance_park"
var windows_ms := {"perfect": 160, "good": 380, "buddy": 400}

var notes: Array = []
## place / nudge 成功后，音符在 notes 里的下标。失败时为 -1。
var last_index := -1
var _undo: Array = []


static func label_of(ntype: String) -> String:
	return str(LABELS.get(ntype, ntype))


func checkpoint() -> void:
	_undo.append(notes.duplicate(true))
	if _undo.size() > UNDO_LIMIT:
		_undo.pop_front()


func can_undo() -> bool:
	return not _undo.is_empty()


func undo() -> bool:
	if _undo.is_empty():
		return false
	notes = _undo.pop_back()
	return true


## snap_step <= 0 时只把时刻收成毫秒。成功返回空字符串。
func place(t: float, ntype: String, snap_step: float = 0.0) -> String:
	var kind := ChartLoader.canonical_type(ntype)
	last_index = -1
	if kind not in NOTE_TYPES:
		return "未知音符：%s" % ntype
	var when := _clamp_t(_apply_snap(t, snap_step))
	if _taken(when, kind, -1):
		return "这一拍已经有%s" % label_of(kind)
	checkpoint()
	var note := {"t": when, "type": kind}
	if kind == "pit":
		note["width"] = DEFAULT_PIT_WIDTH
	elif kind == "platform":
		note["width"] = DEFAULT_PLATFORM_WIDTH
		note["height"] = DEFAULT_PLATFORM_HEIGHT
	notes.append(note)
	_sort()
	last_index = index_of(when, kind)
	return ""


func index_of(t: float, ntype: String) -> int:
	for i in notes.size():
		if str(notes[i].get("type", "")) != ntype:
			continue
		if absf(float(notes[i].get("t", 0.0)) - t) < 0.0005:
			return i
	return -1


func nearest_index(t: float, window: float) -> int:
	var best := -1
	var best_d := window
	for i in notes.size():
		var d := absf(float(notes[i].get("t", 0.0)) - t)
		if d <= best_d:
			best_d = d
			best = i
	return best


func delete_at(index: int) -> String:
	if index < 0 or index >= notes.size():
		return "没有选中音符"
	checkpoint()
	notes.remove_at(index)
	return ""


func delete_near(t: float, window: float) -> String:
	var index := nearest_index(t, window)
	if index < 0:
		return "播放头附近没有音符"
	return delete_at(index)


func cycle_type(index: int) -> String:
	if index < 0 or index >= notes.size():
		return "没有选中音符"
	var cur := str(notes[index].get("type", ""))
	var at := NOTE_TYPES.find(cur)
	var nxt: String = NOTE_TYPES[(at + 1) % NOTE_TYPES.size()] if at >= 0 else NOTE_TYPES[0]
	var when := float(notes[index].get("t", 0.0))
	if _taken(when, nxt, index):
		return "改类型会和已有音符重叠"
	checkpoint()
	var note: Dictionary = notes[index]
	note["type"] = nxt
	note.erase("width")
	note.erase("height")
	note.erase("duration")
	if nxt == "pit":
		note["width"] = DEFAULT_PIT_WIDTH
	elif nxt == "platform":
		note["width"] = DEFAULT_PLATFORM_WIDTH
		note["height"] = DEFAULT_PLATFORM_HEIGHT
	return ""


func nudge(index: int, delta: float) -> String:
	if index < 0 or index >= notes.size():
		return "没有选中音符"
	var note: Dictionary = notes[index]
	var when := _clamp_t(snappedf(float(note.get("t", 0.0)) + delta, 0.001))
	var kind := str(note.get("type", ""))
	if _taken(when, kind, index):
		return "会和已有音符重叠"
	checkpoint()
	note["t"] = when
	_sort()
	last_index = index_of(when, kind)
	return ""


func set_width(index: int, width: int) -> String:
	if index < 0 or index >= notes.size():
		return "没有选中音符"
	var kind := str(notes[index].get("type", ""))
	if kind != "pit" and kind != "platform":
		return "这个音符没有宽度"
	notes[index]["width"] = clampi(width, 48, 520)
	notes[index].erase("duration")
	return ""


func set_height(index: int, height: int) -> String:
	if index < 0 or index >= notes.size():
		return "没有选中音符"
	if str(notes[index].get("type", "")) != "platform":
		return "只有平台有高度"
	notes[index]["height"] = clampi(height, 36, 120)
	return ""


func to_dictionary() -> Dictionary:
	var exported: Array = []
	for n in notes:
		exported.append(_export_note(n))
	return {
		"schemaVersion": SCHEMA_VERSION,
		"songId": song_id,
		"title": title,
		"artist": artist,
		"audio": audio,
		"bpm": int(round(bpm)) if absf(bpm - round(bpm)) < 0.001 else bpm,
		"offsetMs": int(round(offset_ms)),
		"durationSec": snappedf(duration_sec, 0.001),
		"approachSec": approach_sec,
		"pxPerSec": int(px_per_sec),
		"course": course,
		"windowsMs": windows_ms.duplicate(true),
		"notes": exported,
	}


func to_json() -> String:
	return JSON.stringify(to_dictionary(), "\t", false)


## 校验通过才写入。失败时返回 ChartLoader 的错误文本。
func save_to(path: String) -> String:
	var data := to_dictionary()
	if not ChartLoader.validate_chart(data):
		return "\n".join(ChartLoader.get_last_errors())
	var dir := path.get_base_dir()
	if not dir.is_empty():
		DirAccess.make_dir_recursive_absolute(dir)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return "无法写入 %s" % path
	file.store_string(to_json() + "\n")
	file.close()
	return ""


static func from_dictionary(data: Dictionary) -> ChartDraft:
	var draft := ChartDraft.new()
	draft.song_id = str(data.get("songId", draft.song_id))
	draft.title = str(data.get("title", draft.title))
	draft.artist = str(data.get("artist", ""))
	draft.audio = str(data.get("audio", ""))
	draft.bpm = maxf(float(data.get("bpm", draft.bpm)), 1.0)
	draft.offset_ms = int(data.get("offsetMs", 0))
	draft.duration_sec = maxf(float(data.get("durationSec", draft.duration_sec)), 0.1)
	draft.approach_sec = float(data.get("approachSec", draft.approach_sec))
	draft.px_per_sec = int(data.get("pxPerSec", draft.px_per_sec))
	draft.course = str(data.get("course", draft.course))
	var windows = data.get("windowsMs", {})
	if typeof(windows) == TYPE_DICTIONARY:
		draft.windows_ms = (windows as Dictionary).duplicate(true)
	var raw: Array = data.get("notes", [])
	var seen := {}
	for item in raw:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var note := _normalize_note(item)
		var key := "%.3f|%s" % [float(note["t"]), str(note["type"])]
		if seen.has(key):
			continue
		seen[key] = true
		draft.notes.append(note)
	draft._sort()
	return draft


static func load_path(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "找不到谱面：%s" % path}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "无法打开：%s" % path}
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(data) != TYPE_DICTIONARY:
		return {"ok": false, "error": "谱面不是 JSON 对象"}
	if not ChartLoader.validate_chart(data):
		return {"ok": false, "error": "\n".join(ChartLoader.get_last_errors())}
	return {"ok": true, "error": "", "draft": from_dictionary(data)}


func _export_note(n: Dictionary) -> Dictionary:
	var out := {
		"t": snappedf(float(n.get("t", 0.0)), 0.001),
		"type": str(n.get("type", "")),
	}
	if n.has("width"):
		out["width"] = int(round(float(n.get("width", 0.0))))
	if n.has("height"):
		out["height"] = int(round(float(n.get("height", 0.0))))
	if n.has("duration") and not n.has("width"):
		out["duration"] = snappedf(float(n.get("duration", 0.0)), 0.001)
	if n.has("lane"):
		var lane := int(n.get("lane", -1))
		if lane >= 0 and lane <= 2:
			out["lane"] = lane
	return out


static func _normalize_note(n: Dictionary) -> Dictionary:
	var note := {
		"t": snappedf(float(n.get("t", 0.0)), 0.001),
		"type": ChartLoader.canonical_type(str(n.get("type", ""))),
	}
	if n.has("width"):
		note["width"] = int(round(float(n.get("width", 0.0))))
	if n.has("height"):
		note["height"] = int(round(float(n.get("height", 0.0))))
	if n.has("duration") and not note.has("width"):
		note["duration"] = float(n.get("duration", 0.0))
	if n.has("lane"):
		note["lane"] = int(n.get("lane", 0))
	var kind := str(note["type"])
	if kind == "pit" and not note.has("width"):
		note["width"] = DEFAULT_PIT_WIDTH
	if kind == "platform" and not note.has("width") and not note.has("duration"):
		note["width"] = DEFAULT_PLATFORM_WIDTH
		note["height"] = DEFAULT_PLATFORM_HEIGHT
	return note


func _apply_snap(t: float, step: float) -> float:
	var raw := snappedf(t, 0.001)
	if step <= 0.001:
		return raw
	var snapped := snappedf(round(raw / step) * step, 0.001)
	return snapped


func _clamp_t(t: float) -> float:
	return clampf(t, 0.0, maxf(duration_sec, 0.0))


func _taken(t: float, kind: String, ignore: int) -> bool:
	for i in notes.size():
		if i == ignore:
			continue
		if str(notes[i].get("type", "")) != kind:
			continue
		if absf(float(notes[i].get("t", 0.0)) - t) < 0.0005:
			return true
	return false


func _sort() -> void:
	notes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("t", 0.0)) < float(b.get("t", 0.0))
	)
