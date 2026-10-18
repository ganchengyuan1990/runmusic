extends Node
class_name ObstacleSpawner
## 每帧读 GameClock.song_time，激活 t <= song_time + approach 的障碍，过线后归还对象池。

@export var pool_path: NodePath
@export var approach_sec_override: float = -1.0  # <0 则用谱面 approachSec
## 过判定线后再留多久（秒）才回收，让占位色块走出画面。
@export var recycle_after_sec: float = 0.45

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
	var song_t := GameClock.song_time_sec
	_spawn_due(song_t)
	_recycle_passed(song_t)


func _spawn_due(song_t: float) -> void:
	var approach := approach_sec_override
	if approach < 0.0:
		approach = float(ChartLoader.chart.get("approachSec", 1.5))
	var notes := ChartLoader.notes
	while _note_cursor < notes.size():
		var n: Dictionary = notes[_note_cursor]
		var t := float(n.get("t", 0.0))
		if t > song_t + approach:
			break
		# 布布由 BuddyCatch 接，不进障碍池，避免和挡块叠在同一拍。
		if str(n.get("type", "")) == "buddy":
			_note_cursor += 1
			continue
		if _spawned_ids.has(_note_cursor):
			_note_cursor += 1
			continue
		var obs := _pool.acquire()
		if obs == null:
			break
		if obs.has_method("setup_from_note"):
			obs.call("setup_from_note", n, _note_cursor)
		_spawned_ids[_note_cursor] = true
		_note_cursor += 1


func _recycle_passed(song_t: float) -> void:
	for node in _pool.get_active().duplicate():
		var obs := node as Obstacle
		if obs == null:
			continue
		if song_t > obs.hit_time + recycle_after_sec:
			_pool.release(obs)
