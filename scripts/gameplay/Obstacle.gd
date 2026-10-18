extends Area2D
class_name Obstacle
## 旧三轨滚动障碍。恋爱公园改由 ParkCourse 按谱面铺 StaticBody，本场景不再挂进 Game。

const Layout = preload("res://scripts/gameplay/TrackLayout.gd")
const Palette = preload("res://scripts/ui/ArtPalette.gd")

var note: Dictionary = {}
var note_index: int = -1
var hit_time: float = 0.0
var note_type: String = "jump"

@onready var _placeholder: Panel = $Placeholder
var _style: StyleBoxFlat


func _ready() -> void:
	_style = StyleBoxFlat.new()
	_style.bg_color = Palette.JUMP
	_style.border_color = Palette.OUTLINE
	_style.set_border_width_all(2)
	_style.set_corner_radius_all(12)
	_placeholder.add_theme_stylebox_override("panel", _style)


func setup_from_note(n: Dictionary, index: int) -> void:
	note = n
	note_index = index
	hit_time = float(n.get("t", 0.0))
	note_type = str(n.get("type", "jump"))
	position.y = Layout.GROUND_Y
	position.x = Layout.SPAWN_X
	visible = true
	_apply_visual()


func clear_note() -> void:
	note = {}
	note_index = -1
	hit_time = 0.0
	note_type = "jump"
	position = Vector2.ZERO


func _process(_delta: float) -> void:
	if not GameClock.is_playing:
		return
	var approach := float(ChartLoader.chart.get("approachSec", 1.5))
	var song_t := GameClock.song_time_sec
	# t-approach → 画面右侧；t → 左侧判定线；之后继续向左出画，由 Spawner 回收。
	var u := 1.0
	if approach > 0.0:
		u = clampf((song_t - (hit_time - approach)) / approach, 0.0, 1.6)
	position.y = Layout.GROUND_Y
	position.x = lerpf(Layout.SPAWN_X, Layout.HIT_X, u)


func _apply_visual() -> void:
	if _placeholder == null or _style == null:
		return
	var radius := 12
	match note_type:
		"slide":
			# 贴着赛道上沿的横条，滑过去。
			_set_rect(-60.0, -70.0, 60.0, -26.0)
			_style.bg_color = Palette.SLIDE
		"hold":
			_set_rect(-100.0, -18.0, 100.0, 14.0)
			_style.bg_color = Palette.HOLD
			radius = 16
		_:
			# 贴着赛道下沿的矮块，跳过去。
			_set_rect(-50.0, 22.0, 50.0, 70.0)
			_style.bg_color = Palette.JUMP
	_style.set_corner_radius_all(radius)


func _set_rect(left: float, top: float, right: float, bottom: float) -> void:
	_placeholder.offset_left = left
	_placeholder.offset_top = top
	_placeholder.offset_right = right
	_placeholder.offset_bottom = bottom
