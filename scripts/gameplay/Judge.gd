extends Node
class_name Judge
## 输入时找最近未判定 note；|song_time - note.t| 落在窗内则命中。
## 起步窗：Perfect ±50ms，Good ±100ms（可被谱面 windowsMs 覆盖）。

signal judged(result: String, note: Dictionary, delta_ms: float)
# result: "perfect" | "good" | "miss"

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


## action: "jump" | "slide" | "lane" 等；lane 为当前车道。
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
		# MVP：block 用变道躲开，不在此「点按」判定；jump/slide/hold 对动作
		var ntype := str(n.get("type", ""))
		if ntype == "block":
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
		# 无匹配：可能是空挥；Miss 留给超时自动 Miss
		return Grade.MISS
	_judged_indices[best_i] = true
	var note: Dictionary = notes[best_i]
	var grade: Grade
	var label: String
	if best_abs <= perfect_ms:
		grade = Grade.PERFECT
		label = "perfect"
	elif best_abs <= good_ms:
		grade = Grade.GOOD
		label = "good"
	else:
		grade = Grade.MISS
		label = "miss"
	judged.emit(label, note, best_abs if grade != Grade.MISS else best_abs)
	return grade


## TODO(Phase 1): 每帧扫描超时未点的 jump/slide → 自动 Miss；block 与玩家车道重叠 → Miss/扣盾
func process_auto_misses(song_time: float) -> void:
	pass
