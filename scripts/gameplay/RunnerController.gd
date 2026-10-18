extends CharacterBody2D
class_name RunnerController
## 一二（白熊猫）。变道改 Y（上/下轨），跳是相对本轨的上弧，滑铲把身体压矮。
## X 固定在判定线，不跟着障碍走。正式跑步帧还没做，这里只摆占位。

signal lane_changed(lane: int)
signal jumped
signal slid

const Layout = preload("res://scripts/gameplay/TrackLayout.gd")
const LANE_COUNT := 3
const SLIDE_HEIGHT_RATIO := 0.45
const VISUAL_FOOT := 48.0

@export var lane_switch_speed: float = 12.0
@export var jump_duration: float = 0.35
@export var slide_duration: float = 0.4
@export var jump_height: float = 48.0

var current_lane: int = 1
var _is_jumping: bool = false
var _is_sliding: bool = false
var _action_timer: float = 0.0
var _action_duration: float = 0.0
var _target_y: float = 0.0
var _shown_y: float = 0.0
var _hop: float = 0.0

@onready var _visual: Node2D = $Visual


func _ready() -> void:
	current_lane = 1
	_target_y = Layout.LANE_Y[current_lane]
	_shown_y = _target_y
	position.x = Layout.RUNNER_X
	position.y = _shown_y
	_reset_visual()


func _physics_process(delta: float) -> void:
	var blend := clampf(lane_switch_speed * delta, 0.0, 1.0)
	_shown_y = lerpf(_shown_y, _target_y, blend)
	if _is_jumping:
		_tick_jump(delta)
	elif _is_sliding:
		_tick_slide(delta)
	else:
		_hop = 0.0
	position.x = Layout.RUNNER_X
	position.y = _shown_y + _hop


func _tick_jump(delta: float) -> void:
	_action_timer = maxf(_action_timer - delta, 0.0)
	var duration := maxf(_action_duration, 0.0001)
	var elapsed := clampf(1.0 - (_action_timer / duration), 0.0, 1.0)
	var arc := sin(elapsed * PI)
	_hop = -jump_height * arc
	if _action_timer <= 0.0:
		_finish_action()


func _tick_slide(delta: float) -> void:
	_action_timer = maxf(_action_timer - delta, 0.0)
	_apply_slide_pose()
	if _action_timer <= 0.0:
		_finish_action()


func _apply_slide_pose() -> void:
	_visual.scale = Vector2(1.05, SLIDE_HEIGHT_RATIO)
	_visual.position.y = (1.0 - SLIDE_HEIGHT_RATIO) * VISUAL_FOOT


func _reset_visual() -> void:
	_visual.scale = Vector2.ONE
	_visual.position = Vector2.ZERO


func _finish_action() -> void:
	_is_jumping = false
	_is_sliding = false
	_action_timer = 0.0
	_hop = 0.0
	_reset_visual()


func move_lane(delta_lane: int) -> void:
	var next := clampi(current_lane + delta_lane, 0, LANE_COUNT - 1)
	if next == current_lane:
		return
	current_lane = next
	_target_y = Layout.LANE_Y[current_lane]
	lane_changed.emit(current_lane)


func try_jump() -> void:
	if _is_jumping or _is_sliding:
		return
	_is_jumping = true
	_action_duration = jump_duration
	_action_timer = jump_duration
	jumped.emit()


func try_slide() -> void:
	if _is_jumping or _is_sliding:
		return
	_is_sliding = true
	_action_duration = slide_duration
	_action_timer = slide_duration
	_hop = 0.0
	_apply_slide_pose()
	slid.emit()


func is_airborne() -> bool:
	return _is_jumping


func is_sliding_now() -> bool:
	return _is_sliding
