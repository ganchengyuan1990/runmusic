extends CharacterBody2D
class_name RunnerController
## 三车道跑者：变道 / 跳 / 滑。Phase 0：无音乐也可跑。

signal lane_changed(lane: int)
signal jumped
signal slid

const LANE_COUNT := 3
const LANE_X := [-120.0, 0.0, 120.0]  # 左 / 中 / 右；按美术再调
const SLIDE_HEIGHT_RATIO := 0.4
const SLIDE_DROP := 16.0

@export var lane_switch_speed: float = 12.0
@export var jump_duration: float = 0.35
@export var slide_duration: float = 0.4
@export var jump_height: float = 90.0

var current_lane: int = 1
var _is_jumping: bool = false
var _is_sliding: bool = false
var _action_timer: float = 0.0
var _action_duration: float = 0.0
var _target_x: float = 0.0
var _ground_y: float = 0.0
var _rest_offset_top: float = 0.0
var _rest_offset_bottom: float = 0.0
var _rest_color: Color = Color(0.2, 0.75, 0.95, 1)

@onready var _placeholder: ColorRect = $Placeholder


func _ready() -> void:
	current_lane = 1
	_target_x = LANE_X[current_lane]
	position.x = _target_x
	_ground_y = position.y
	_rest_offset_top = _placeholder.offset_top
	_rest_offset_bottom = _placeholder.offset_bottom
	_rest_color = _placeholder.color


func _physics_process(delta: float) -> void:
	position.x = lerpf(position.x, _target_x, clampf(lane_switch_speed * delta, 0.0, 1.0))
	if _is_jumping:
		_tick_jump(delta)
	elif _is_sliding:
		_tick_slide(delta)


func _tick_jump(delta: float) -> void:
	_action_timer = maxf(_action_timer - delta, 0.0)
	var duration := maxf(_action_duration, 0.0001)
	var elapsed := clampf(1.0 - (_action_timer / duration), 0.0, 1.0)
	var arc := sin(elapsed * PI)
	position.y = _ground_y - jump_height * arc
	# Slight brighten at the apex so the hop reads without art.
	_placeholder.color = _rest_color.lerp(Color(0.75, 0.95, 1.0, 1.0), arc * 0.65)
	if _action_timer <= 0.0:
		_finish_action()


func _tick_slide(delta: float) -> void:
	_action_timer = maxf(_action_timer - delta, 0.0)
	_apply_slide_pose()
	if _action_timer <= 0.0:
		_finish_action()


func _apply_slide_pose() -> void:
	var rest_height := _rest_offset_bottom - _rest_offset_top
	var height := rest_height * SLIDE_HEIGHT_RATIO
	_placeholder.offset_bottom = _rest_offset_bottom + SLIDE_DROP
	_placeholder.offset_top = _placeholder.offset_bottom - height
	_placeholder.color = _rest_color


func _finish_action() -> void:
	_is_jumping = false
	_is_sliding = false
	_action_timer = 0.0
	position.y = _ground_y
	_placeholder.offset_top = _rest_offset_top
	_placeholder.offset_bottom = _rest_offset_bottom
	_placeholder.color = _rest_color


func move_lane(delta_lane: int) -> void:
	var next := clampi(current_lane + delta_lane, 0, LANE_COUNT - 1)
	if next == current_lane:
		return
	current_lane = next
	_target_x = LANE_X[current_lane]
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
	position.y = _ground_y
	_apply_slide_pose()
	slid.emit()


func is_airborne() -> bool:
	return _is_jumping


func is_sliding_now() -> bool:
	return _is_sliding
