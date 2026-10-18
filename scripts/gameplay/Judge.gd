extends Node
class_name Judge
## 轻同步：身体越过谱面障碍时按歌曲时间给 Perfect / Good / 躲开。
## 没踩在节拍上仍算躲开，不扣命。掉坑由 GameRoot 另计。

signal judged(result: String, note: Dictionary, delta_ms: float)

var perfect_ms: float = 50.0
var good_ms: float = 100.0
var _judged_indices: Dictionary = {}


func reset() -> void:
	_judged_indices.clear()
	_apply_windows_from_chart()


func _apply_windows_from_chart() -> void:
	var w: Dictionary = ChartLoader.chart.get("windowsMs", {})
	if w.has("perfect"):
		perfect_ms = float(w["perfect"])
	if w.has("good"):
		good_ms = float(w["good"])


func unresolved_count() -> int:
	var pending := 0
	for i in ChartLoader.notes.size():
		if _judged_indices.has(i):
			continue
		var ntype := ChartLoader.canonical_type(str(ChartLoader.notes[i].get("type", "")))
		if ntype == "buddy" or ntype == "checkpoint":
			continue
		pending += 1
	return pending


## 玩家在 song_time 越过这颗音符。窗内 Perfect/Good，窗外躲开。
func submit_clear(note_index: int, song_time: float) -> void:
	if note_index < 0 or note_index >= ChartLoader.notes.size():
		return
	if _judged_indices.has(note_index):
		return
	var note: Dictionary = ChartLoader.notes[note_index]
	var ntype := ChartLoader.canonical_type(str(note.get("type", "")))
	if ntype == "buddy" or ntype == "checkpoint":
		return
	_judged_indices[note_index] = true
	var dt_ms := absf(song_time - float(note.get("t", 0.0))) * 1000.0
	var label := "dodge"
	if dt_ms <= perfect_ms:
		label = "perfect"
	elif dt_ms <= good_ms:
		label = "good"
	judged.emit(label, note, dt_ms)
