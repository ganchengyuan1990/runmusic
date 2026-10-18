extends Node
class_name InputRouter
## 键盘按住 / 触屏分区 → 左右跑、跳跃（按住与松开）、短滑铲、可选冲刺。
## 判定用按下的瞬间；变高跳看的是跳跃键是否还按着。
##
## 触屏与按住的鼠标（横屏）：
## - 最左一档：向左跑；左中：向右跑
## - 右上：按住跳；右下：滑铲

signal action_pressed(action: String, song_time: float)

@export var swipe_threshold_px: float = 48.0

var _points: Dictionary = {}
var _touch_axis: float = 0.0
var _touch_jump_held: bool = false
var _touch_jump_pressed: bool = false
var _touch_slide_pressed: bool = false
var _slide_touch_held: bool = false
var _touch_origin := Vector2.ZERO
var _swipe_fired: bool = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		action_pressed.emit("pause", GameClock.song_time_sec)
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_points[touch.index] = touch.position
			_touch_origin = touch.position
			_swipe_fired = false
		else:
			_points.erase(touch.index)
		_rebuild_touch()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_points[drag.index] = drag.position
		_consider_swipe(drag.position)
		_rebuild_touch()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse := event as InputEventMouseButton
		if mouse.pressed:
			_points[-1] = mouse.position
			_touch_origin = mouse.position
			_swipe_fired = false
		else:
			_points.erase(-1)
		_rebuild_touch()
	elif event is InputEventMouseMotion and _points.has(-1):
		_points[-1] = event.position
		_consider_swipe(event.position)
		_rebuild_touch()


func move_axis() -> float:
	if GameClock.is_soft_frozen():
		return 0.0
	var axis := Input.get_axis("move_left", "move_right") + _touch_axis
	return clampf(axis, -1.0, 1.0)


func jump_held() -> bool:
	if GameClock.is_soft_frozen():
		return false
	return Input.is_action_pressed("jump") or _touch_jump_held


func consume_jump_pressed() -> bool:
	var pressed := Input.is_action_just_pressed("jump") or _touch_jump_pressed
	_touch_jump_pressed = false
	if GameClock.is_soft_frozen():
		return false
	if pressed:
		action_pressed.emit("jump", GameClock.song_time_sec)
	return pressed


func consume_slide_pressed() -> bool:
	var pressed := Input.is_action_just_pressed("slide") or _touch_slide_pressed
	_touch_slide_pressed = false
	if GameClock.is_soft_frozen():
		return false
	if pressed:
		action_pressed.emit("slide", GameClock.song_time_sec)
	return pressed


func sprint_held() -> bool:
	if GameClock.is_soft_frozen():
		return false
	return Input.is_action_pressed("sprint")


func _consider_swipe(pos: Vector2) -> void:
	if _swipe_fired:
		return
	var delta := pos - _touch_origin
	if delta.length() < swipe_threshold_px:
		return
	if absf(delta.y) < absf(delta.x):
		return
	_swipe_fired = true
	if delta.y < 0.0:
		_touch_jump_pressed = true
		_touch_jump_held = true
	else:
		_touch_slide_pressed = true


func _rebuild_touch() -> void:
	var size := get_viewport().get_visible_rect().size
	if size.x <= 1.0 or size.y <= 1.0:
		size = Vector2(1280, 720)
	var left := false
	var right := false
	var jump := false
	var slide := false
	for pos in _points.values():
		var nx := float(pos.x) / size.x
		var ny := float(pos.y) / size.y
		if nx < 0.22:
			left = true
		elif nx < 0.48:
			right = true
		elif ny < 0.58:
			jump = true
		else:
			slide = true
	_touch_axis = 0.0
	if left:
		_touch_axis -= 1.0
	if right:
		_touch_axis += 1.0
	if jump and not _touch_jump_held:
		_touch_jump_pressed = true
	_touch_jump_held = jump
	if slide and not _slide_touch_held:
		_touch_slide_pressed = true
	_slide_touch_held = slide
