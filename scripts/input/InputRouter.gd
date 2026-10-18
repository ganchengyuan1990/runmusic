extends Node
class_name InputRouter
## 键盘 / 触屏 → 统一 Action（带 stamped 时间）。
## Judge 应用「按下瞬间的 song_time」，避免抬起才判定。
##
## 触屏（Phase 0）：
## - 点击左 1/3：向左变道；右 1/3：向右变道
## - 中间上半：跳；中间下半：滑
## - 滑动：横向变道，上滑跳，下滑滑
## 桌面鼠标左键单击走同一套分区，便于没有触摸屏时试手感。

signal action_pressed(action: String, song_time: float)

@export var runner_path: NodePath
@export var judge_path: NodePath
@export var swipe_threshold_px: float = 48.0

var _runner: RunnerController
var _judge: Judge
var _touch_origin := Vector2.ZERO
var _touch_index := -1
var _touch_tracking := false
var _swipe_fired := false
## 触屏会再合成鼠标事件；这段时间内忽略鼠标，避免一次触摸触发两次。
var _ignore_mouse_until_msec: int = 0


func _ready() -> void:
	if runner_path:
		_runner = get_node_or_null(runner_path) as RunnerController
	if judge_path:
		_judge = get_node_or_null(judge_path) as Judge


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		handle_touch(event)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		handle_touch(event)
		get_viewport().set_input_as_handled()
		return
	if not (event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return
	var stamped := GameClock.song_time_sec
	if event.is_action_pressed("lane_left"):
		_route_lane(-1, stamped)
	elif event.is_action_pressed("lane_right"):
		_route_lane(1, stamped)
	elif event.is_action_pressed("jump"):
		_route_jump(stamped)
	elif event.is_action_pressed("slide"):
		_route_slide(stamped)
	elif event.is_action_pressed("pause"):
		_emit_and_route("pause", stamped)
		# TODO: 暂停菜单


## ScreenTouch / ScreenDrag / 鼠标左键。点按分区；拖过阈值算一次滑动。
func handle_touch(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		_ignore_mouse_until_msec = Time.get_ticks_msec() + 400
		if touch.pressed:
			_begin_pointer(touch.position, touch.index)
		elif _touch_tracking and touch.index == _touch_index:
			_end_pointer(touch.position)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_ignore_mouse_until_msec = Time.get_ticks_msec() + 400
		if _touch_tracking and drag.index == _touch_index:
			_consider_swipe(drag.position)
	elif event is InputEventMouseButton:
		if Time.get_ticks_msec() < _ignore_mouse_until_msec:
			return
		var mouse := event as InputEventMouseButton
		if mouse.pressed:
			_begin_pointer(mouse.position, -1)
			# 鼠标单击立即按分区触发，不等待释放，方便桌面试触屏。
			_end_pointer(mouse.position)


func _begin_pointer(pos: Vector2, index: int) -> void:
	_touch_origin = pos
	_touch_index = index
	_touch_tracking = true
	_swipe_fired = false


func _end_pointer(pos: Vector2) -> void:
	if not _swipe_fired:
		_consider_swipe(pos)
	if not _swipe_fired:
		_route_tap(pos)
	_touch_tracking = false
	_touch_index = -1


func _consider_swipe(pos: Vector2) -> void:
	if _swipe_fired:
		return
	var delta := pos - _touch_origin
	if delta.length() < swipe_threshold_px:
		return
	_swipe_fired = true
	var stamped := GameClock.song_time_sec
	if absf(delta.x) >= absf(delta.y):
		if delta.x < 0.0:
			_route_lane(-1, stamped)
		else:
			_route_lane(1, stamped)
	elif delta.y < 0.0:
		_route_jump(stamped)
	else:
		_route_slide(stamped)


func _route_tap(pos: Vector2) -> void:
	var size := get_viewport().get_visible_rect().size
	if size.x <= 1.0 or size.y <= 1.0:
		size = Vector2(1280, 720)
	var stamped := GameClock.song_time_sec
	if pos.x < size.x / 3.0:
		_route_lane(-1, stamped)
	elif pos.x > size.x * 2.0 / 3.0:
		_route_lane(1, stamped)
	elif pos.y < size.y * 0.5:
		_route_jump(stamped)
	else:
		_route_slide(stamped)


func _route_lane(delta_lane: int, stamped: float) -> void:
	var action := "lane_left" if delta_lane < 0 else "lane_right"
	_emit_and_route(action, stamped)
	if _runner:
		_runner.move_lane(delta_lane)


func _route_jump(stamped: float) -> void:
	_emit_and_route("jump", stamped)
	if _runner:
		_runner.try_jump()
	if _judge and _runner:
		_judge.try_judge("jump", _runner.current_lane, stamped)


func _route_slide(stamped: float) -> void:
	_emit_and_route("slide", stamped)
	if _runner:
		_runner.try_slide()
	if _judge and _runner:
		_judge.try_judge("slide", _runner.current_lane, stamped)


func _emit_and_route(action: String, song_time: float) -> void:
	action_pressed.emit(action, song_time)
