extends CharacterBody2D
class_name RunnerController
## 三车道跑者：变道 / 跳 / 滑。Phase 0：无音乐也可跑。

signal lane_changed(lane: int)
signal jumped
signal slid

const LANE_COUNT := 3
const LANE_X := [-120.0, 0.0, 120.0]  # 左 / 中 / 右；按美术再调

@export var lane_switch_speed: float = 12.0
@export var jump_duration: float = 0.35
@export var slide_duration: float = 0.4

var current_lane: int = 1
var _is_jumping: bool = false
var _is_sliding: bool = false
var _action_timer: float = 0.0
var _target_x: float = 0.0


func _ready() -> void:
	current_lane = 1
	_target_x = LANE_X[current_lane]
	position.x = _target_x


func _physics_process(delta: float) -> void:
	position.x = lerpf(position.x, _target_x, clampf(lane_switch_speed * delta, 0.0, 1.0))
	if _action_timer > 0.0:
		_action_timer -= delta
		if _action_timer <= 0.0:
			_is_jumping = false
			_is_sliding = false
			# TODO: 恢复碰撞体高度 / 动画


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
	_action_timer = jump_duration
	jumped.emit()
	# TODO: 播放跳跃动画 / 临时改碰撞


func try_slide() -> void:
	if _is_jumping or _is_sliding:
		return
	_is_sliding = true
	_action_timer = slide_duration
	slid.emit()
	# TODO: 播放下滑动画 / 临时改碰撞


func is_airborne() -> bool:
	return _is_jumping


func is_sliding_now() -> bool:
	return _is_sliding
