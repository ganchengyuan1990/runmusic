extends Node
class_name InputRouter
## 键盘 / 触屏 → 统一 Action（带 stamped 时间）。
## Judge 应用「按下瞬间的 song_time」，避免抬起才判定。

signal action_pressed(action: String, song_time: float)

@export var runner_path: NodePath
@export var judge_path: NodePath

var _runner: RunnerController
var _judge: Judge


func _ready() -> void:
	if runner_path:
		_runner = get_node_or_null(runner_path) as RunnerController
	if judge_path:
		_judge = get_node_or_null(judge_path) as Judge


func _unhandled_input(event: InputEvent) -> void:
	# 采样按下瞬间的歌曲时间
	var stamped := GameClock.song_time_sec
	if event.is_action_pressed("lane_left"):
		_emit_and_route("lane_left", stamped)
		if _runner:
			_runner.move_lane(-1)
	elif event.is_action_pressed("lane_right"):
		_emit_and_route("lane_right", stamped)
		if _runner:
			_runner.move_lane(1)
	elif event.is_action_pressed("jump"):
		_emit_and_route("jump", stamped)
		if _runner:
			_runner.try_jump()
		if _judge and _runner:
			_judge.try_judge("jump", _runner.current_lane, stamped)
	elif event.is_action_pressed("slide"):
		_emit_and_route("slide", stamped)
		if _runner:
			_runner.try_slide()
		if _judge and _runner:
			_judge.try_judge("slide", _runner.current_lane, stamped)
	elif event.is_action_pressed("pause"):
		_emit_and_route("pause", stamped)
		# TODO: 暂停菜单


func _emit_and_route(action: String, song_time: float) -> void:
	action_pressed.emit(action, song_time)


## TODO(Phase 0): 触屏分区 — 左半变道、右半跳/滑或边缘手势
func handle_touch(_event: InputEventScreenTouch) -> void:
	pass
