extends Node
## 布布：Approach → CatchWindow → Kiss → Resume。
## 时间落在放宽的窗里就接住，不看车道。亲亲时歌曲时钟停住，点一下可以跳过。

signal caught
signal brushed

const Layout = preload("res://scripts/gameplay/TrackLayout.gd")
const BUDDY_APPROACH := preload("res://assets/characters/bubu_approach.png")
const BUDDY_IDLE := preload("res://assets/characters/bubu_idle.png")
const KISS_SEC := 0.6
const DEFAULT_WINDOW_MS := 250.0
const SIDE_BY_SIDE := 110.0
const KISS_SCALE := 1.4

@export var runner_path: NodePath
@export var buddy_path: NodePath
@export var hud_path: NodePath

var _runner: RunnerController
var _buddy: Node2D
var _hud: GameHUD
var _cursor: int = 0
var _resolved: Dictionary = {}
var _kissing: bool = false
var _kiss_left: float = 0.0
var _window_ms: float = DEFAULT_WINDOW_MS
var _kiss_y: float = 0.0


func _ready() -> void:
	if runner_path:
		_runner = get_node_or_null(runner_path) as RunnerController
	if buddy_path:
		_buddy = get_node_or_null(buddy_path) as Node2D
	if hud_path:
		_hud = get_node_or_null(hud_path) as GameHUD
	_window_ms = _window_from_chart()
	if _buddy:
		_buddy.visible = false


func reset_for_chart() -> void:
	_cursor = 0
	_resolved.clear()
	_kissing = false
	_kiss_left = 0.0
	_window_ms = _window_from_chart()
	_set_runner_scale(1.0)
	if _buddy:
		_buddy.visible = false
		_buddy.scale = Vector2.ONE
	if _hud:
		_hud.show_kiss(false)


func _process(delta: float) -> void:
	if _kissing:
		_kiss_left = maxf(_kiss_left - delta, 0.0)
		_present_kiss()
		if _kiss_left <= 0.0:
			_end_kiss()
		return
	if not GameClock.is_playing:
		return
	_tick_approach()


func _input(event: InputEvent) -> void:
	if not _kissing:
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed or key.echo:
			return
	elif event is InputEventMouseButton:
		if not (event as InputEventMouseButton).pressed:
			return
	elif event is InputEventScreenTouch:
		if not (event as InputEventScreenTouch).pressed:
			return
	else:
		return
	_kiss_left = 0.0
	get_viewport().set_input_as_handled()


func _tick_approach() -> void:
	var notes := ChartLoader.notes
	while _cursor < notes.size():
		var n: Dictionary = notes[_cursor]
		if str(n.get("type", "")) != "buddy" or _resolved.has(_cursor):
			_cursor += 1
			continue
		break
	if _buddy == null or _cursor >= notes.size():
		if _buddy:
			_buddy.visible = false
		return
	var note: Dictionary = notes[_cursor]
	var hit := float(note.get("t", 0.0))
	var approach := float(ChartLoader.chart.get("approachSec", 1.5))
	var song_t := GameClock.song_time_sec
	if song_t < hit - approach:
		_buddy.visible = false
		return
	var u := 1.0
	if approach > 0.0:
		u = clampf((song_t - (hit - approach)) / approach, 0.0, 1.6)
	_buddy.visible = true
	_buddy.scale = Vector2.ONE
	_set_buddy_texture(BUDDY_APPROACH)
	_buddy.position = Vector2(lerpf(Layout.SPAWN_X, Layout.HIT_X, u), Layout.LANE_Y)
	var window := _window_ms / 1000.0
	if song_t >= hit - window and song_t <= hit + window:
		_begin_kiss()
		return
	if song_t > hit + window:
		_resolved[_cursor] = true
		_cursor += 1
		brushed.emit()
		if _hud:
			_hud.flash_judge("brush")


func _begin_kiss() -> void:
	_resolved[_cursor] = true
	_kissing = true
	_kiss_left = KISS_SEC
	_kiss_y = Layout.LANE_Y
	GameClock.soft_freeze()
	caught.emit()
	if _hud:
		_hud.show_kiss(true)
	_present_kiss()


func _present_kiss() -> void:
	if _buddy:
		_buddy.visible = true
		_set_buddy_texture(BUDDY_IDLE)
		_buddy.position = Vector2(Layout.RUNNER_X + SIDE_BY_SIDE, _kiss_y)
		_buddy.scale = Vector2(KISS_SCALE, KISS_SCALE)
	_set_runner_scale(KISS_SCALE)


func _end_kiss() -> void:
	_kissing = false
	_kiss_left = 0.0
	_set_runner_scale(1.0)
	if _buddy:
		_buddy.visible = false
		_buddy.scale = Vector2.ONE
		_set_buddy_texture(BUDDY_APPROACH)
	if _hud:
		_hud.show_kiss(false)
	if GameClock.is_soft_frozen():
		GameClock.soft_resume()
	_cursor += 1


func _set_buddy_texture(texture: Texture2D) -> void:
	if _buddy == null:
		return
	var sprite := _buddy.get_node_or_null("Sprite") as Sprite2D
	if sprite and sprite.texture != texture:
		sprite.texture = texture


func _set_runner_scale(amount: float) -> void:
	if _runner == null:
		return
	var visual := _runner.get_node_or_null("Visual") as Node2D
	if visual:
		visual.scale = Vector2(amount, amount)


func _window_from_chart() -> float:
	var windows: Dictionary = ChartLoader.chart.get("windowsMs", {})
	if windows.has("buddy"):
		return float(windows["buddy"])
	return DEFAULT_WINDOW_MS
