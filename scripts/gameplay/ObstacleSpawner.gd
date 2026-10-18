extends Node
class_name ObstacleSpawner
## 每帧读 GameClock.song_time，激活 t <= song_time + approach_sec 的障碍。

@export var pool_path: NodePath
@export var approach_sec_override: float = -1.0  # <0 则用谱面 approachSec

var _pool: ObstaclePool
var _note_cursor: int = 0
var _spawned_ids: Dictionary = {}  # index -> true


func _ready() -> void:
	if pool_path:
		_pool = get_node_or_null(pool_path) as ObstaclePool


func reset_for_chart() -> void:
	_note_cursor = 0
	_spawned_ids.clear()
	if _pool:
		_pool.release_all()


func _process(_delta: float) -> void:
	if ChartLoader.notes.is_empty() or not GameClock.is_playing:
		return
	if _pool == null:
		return
	var approach := approach_sec_override
	if approach < 0.0:
		approach = float(ChartLoader.chart.get("approachSec", 1.5))
	var song_t := GameClock.song_time_sec
	var notes := ChartLoader.notes
	while _note_cursor < notes.size():
		var n: Dictionary = notes[_note_cursor]
		var t := float(n.get("t", 0.0))
		if t > song_t + approach:
			break
		if not _spawned_ids.has(_note_cursor):
			var obs := _pool.acquire()
			if obs and obs.has_method("setup_from_note"):
				obs.call("setup_from_note", n, _note_cursor)
			_spawned_ids[_note_cursor] = true
		_note_cursor += 1
	# TODO: 回收 t + miss_window 已过的障碍
