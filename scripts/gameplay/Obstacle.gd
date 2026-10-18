extends Area2D
class_name Obstacle
## 池化障碍实例模板。由 ObstacleSpawner.setup_from_note 配置。

const LANE_X := [-120.0, 0.0, 120.0]
const SPAWN_Y := -400.0
const HIT_Y := 0.0

var note: Dictionary = {}
var note_index: int = -1
var hit_time: float = 0.0
var note_type: String = "block"
var lane: int = 1

@onready var _placeholder: ColorRect = $Placeholder


func setup_from_note(n: Dictionary, index: int) -> void:
	note = n
	note_index = index
	hit_time = float(n.get("t", 0.0))
	note_type = str(n.get("type", "block"))
	lane = clampi(int(n.get("lane", 1)), 0, 2)
	position.x = LANE_X[lane]
	position.y = SPAWN_Y
	visible = true
	_apply_visual()


func clear_note() -> void:
	note = {}
	note_index = -1
	hit_time = 0.0
	note_type = "block"
	position = Vector2.ZERO


func _process(_delta: float) -> void:
	if not GameClock.is_playing:
		return
	var approach := float(ChartLoader.chart.get("approachSec", 1.5))
	var song_t := GameClock.song_time_sec
	# t-approach → y=-400；t → y=0（判定线）；之后继续往下走出画面，由 Spawner 回收。
	var u := 1.0
	if approach > 0.0:
		u = clampf((song_t - (hit_time - approach)) / approach, 0.0, 1.6)
	position.y = lerpf(SPAWN_Y, HIT_Y, u)


func _apply_visual() -> void:
	if _placeholder == null:
		return
	match note_type:
		"jump":
			_placeholder.offset_left = -18.0
			_placeholder.offset_right = 18.0
			_placeholder.offset_top = -56.0
			_placeholder.offset_bottom = 8.0
			_placeholder.color = Color(0.25, 0.9, 0.45, 1)
		"slide":
			_placeholder.offset_left = -28.0
			_placeholder.offset_right = 28.0
			_placeholder.offset_top = -6.0
			_placeholder.offset_bottom = 18.0
			_placeholder.color = Color(0.95, 0.78, 0.2, 1)
		"hold":
			_placeholder.offset_left = -18.0
			_placeholder.offset_right = 18.0
			_placeholder.offset_top = -48.0
			_placeholder.offset_bottom = 28.0
			_placeholder.color = Color(0.7, 0.45, 0.95, 1)
		_:
			_placeholder.offset_left = -24.0
			_placeholder.offset_right = 24.0
			_placeholder.offset_top = -24.0
			_placeholder.offset_bottom = 24.0
			_placeholder.color = Color(0.9, 0.25, 0.3, 1)
