extends Area2D
class_name Obstacle
## 池化障碍实例模板。由 ObstacleSpawner.setup_from_note 配置。

const LANE_X := [-120.0, 0.0, 120.0]

var note: Dictionary = {}
var note_index: int = -1
var hit_time: float = 0.0
var note_type: String = "block"


func setup_from_note(n: Dictionary, index: int) -> void:
	note = n
	note_index = index
	hit_time = float(n.get("t", 0.0))
	note_type = str(n.get("type", "block"))
	var lane := clampi(int(n.get("lane", 1)), 0, 2)
	position.x = LANE_X[lane]
	# TODO: 按 approach 从远端插值到判定线；换皮肤按 type
	position.y = -400.0
	visible = true


func _process(_delta: float) -> void:
	if not GameClock.is_playing:
		return
	var approach := float(ChartLoader.chart.get("approachSec", 1.5))
	var song_t := GameClock.song_time_sec
	# 简单线性：t-approach → y=-400；t → y=0（判定线）
	var u := 1.0
	if approach > 0.0:
		u = clampf((song_t - (hit_time - approach)) / approach, 0.0, 1.5)
	position.y = lerpf(-400.0, 0.0, u)
	# TODO: 过 miss 窗后通知 pool.release(self)
