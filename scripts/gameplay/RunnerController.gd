extends CharacterBody2D
class_name RunnerController
## 一二（白熊猫）。变道改 Y（上/下轨），跳是相对本轨的上弧。
## 跑步 / 跳 / 滑切 AnimatedSprite2D 的同名动画。X 固定在判定线。

signal lane_changed(lane: int)
signal jumped
signal slid

const Layout = preload("res://scripts/gameplay/TrackLayout.gd")
const LANE_COUNT := 3

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
var _action_fresh: bool = false

@onready var _sprite: AnimatedSprite2D = $Visual/Sprite


func _ready() -> void:
	current_lane = 1
	_target_y = Layout.LANE_Y[current_lane]
	_shown_y = _target_y
	position.x = Layout.RUNNER_X
	position.y = _shown_y
	_play_pose("idle")


func _physics_process(delta: float) -> void:
	var blend := clampf(lane_switch_speed * delta, 0.0, 1.0)
	_shown_y = lerpf(_shown_y, _target_y, blend)
	# 无头探针里单帧 delta 可能超过整段跳跃。刚按下的那一帧最多只消耗
	# 四分之一时长，保证跳/滑的姿势至少能画出来。
	var step := delta
	if _action_fresh:
		step = minf(delta, maxf(_action_duration, 0.0001) * 0.25)
		_action_fresh = false
	if _is_jumping:
		_tick_jump(step)
	elif _is_sliding:
		_tick_slide(step)
	else:
		_hop = 0.0
	position.x = Layout.RUNNER_X
	position.y = _shown_y + _hop
	_update_pose()


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
	if _action_timer <= 0.0:
		_finish_action()


func _update_pose() -> void:
	if _is_jumping:
		_play_pose("jump")
	elif _is_sliding:
		_play_pose("slide")
	elif GameClock.is_soft_frozen() or not GameClock.is_playing:
		_play_pose("idle")
	else:
		_play_pose("run")


func _play_pose(anim: String) -> void:
	if _sprite == null or _sprite.animation == anim:
		return
	_sprite.play(anim)


func _finish_action() -> void:
	_is_jumping = false
	_is_sliding = false
	_action_timer = 0.0
	_hop = 0.0


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
	_action_fresh = true
	_update_pose()
	jumped.emit()


func try_slide() -> void:
	if _is_jumping or _is_sliding:
		return
	_is_sliding = true
	_action_duration = slide_duration
	_action_timer = slide_duration
	_hop = 0.0
	_action_fresh = true
	_update_pose()
	slid.emit()


func is_airborne() -> bool:
	return _is_jumping


func is_sliding_now() -> bool:
	return _is_sliding
