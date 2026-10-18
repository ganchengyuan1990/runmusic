extends Node
class_name Judge
## 输入时找最近未判定 note；|song_time - note.t| 落在窗内则命中。
## 起步窗：Perfect ±50ms，Good ±100ms（可被谱面 windowsMs 覆盖）。
## 超时的 jump/slide/hold 自动 Miss；block 在 t 时刻与玩家同车道则 Miss，否则算躲开。

signal judged(result: String, note: Dictionary, delta_ms: float)
# result: "perfect" | "good" | "miss" | "dodge"

enum Grade { PERFECT, GOOD, MISS }

var perfect_ms: float = 50.0
var good_ms: float = 100.0
var _judged_indices: Dictionary = {}  # note index -> true


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
		if str(ChartLoader.notes[i].get("type", "")) == "buddy":
			continue
		pending += 1
	return pending


## action: "jump" | "slide"；lane 为当前车道。空挥不发 judged，留给超时自动 Miss。
func try_judge(action: String, lane: int, song_time: float) -> Grade:
	var best_i := -1
	var best_abs := INF
	var notes := ChartLoader.notes
	for i in notes.size():
		if _judged_indices.has(i):
			continue
		var n: Dictionary = notes[i]
		if int(n.get("lane", -1)) != lane:
			continue
		var ntype := str(n.get("type", ""))
		if ntype == "block" or ntype == "buddy":
			continue
		if action == "jump" and ntype not in ["jump", "hold"]:
			continue
		if action == "slide" and ntype != "slide":
			continue
		var dt_ms := absf(song_time - float(n.get("t", 0.0))) * 1000.0
		if dt_ms < best_abs:
			best_abs = dt_ms
			best_i = i
	if best_i < 0 or best_abs > good_ms:
		return Grade.MISS
	_judged_indices[best_i] = true
	var note: Dictionary = notes[best_i]
	var grade: Grade
	var label: String
	if best_abs <= perfect_ms:
		grade = Grade.PERFECT
		label = "perfect"
	else:
		grade = Grade.GOOD
		label = "good"
	judged.emit(label, note, best_abs)
	return grade


## 每帧调用。jump/slide/hold 过 Good 窗自动 Miss；block 在 note.t 与玩家车道重叠则 Miss。
func process_auto_misses(song_time: float, runner_lane: int) -> void:
	var miss_after := good_ms / 1000.0
	var notes := ChartLoader.notes
	for i in notes.size():
		if _judged_indices.has(i):
			continue
		var n: Dictionary = notes[i]
		var t := float(n.get("t", 0.0))
		if song_time < t:
			continue
		var ntype := str(n.get("type", ""))
		if ntype == "buddy":
			continue
		if ntype == "block":
			_judged_indices[i] = true
			var delta_ms := (song_time - t) * 1000.0
			if int(n.get("lane", -1)) == runner_lane:
				judged.emit("miss", n, delta_ms)
			else:
				judged.emit("dodge", n, delta_ms)
			continue
		if song_time < t + miss_after:
			continue
		_judged_indices[i] = true
		judged.emit("miss", n, (song_time - t) * 1000.0)
