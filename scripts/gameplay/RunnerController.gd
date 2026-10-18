extends CharacterBody2D
class_name RunnerController
## 一二。重力、左右跑、按住跳得更高、短滑铲。相机挂在身上跟着走。
## 亲亲 soft_freeze 时丢掉移动和重力，避免停在坑边时掉下去。

signal jumped
signal slid
signal pit_fallen
signal respawned

const Layout = preload("res://scripts/gameplay/TrackLayout.gd")

@export var input_path: NodePath

var facing: int = 1

var _router: InputRouter
var _shape: CollisionShape2D
var _sprite: AnimatedSprite2D
var _sliding: bool = false
var _slide_left: float = 0.0
var _coyote: float = 0.0
var _jump_buf: float = 0.0
var _cut_armed: bool = false
var _fallen: bool = false
var _invuln: float = 0.0
var _use_force: bool = false
var _force_axis: float = 0.0
var _force_jump_held: bool = false
var _force_jump_pressed: bool = false
var _force_slide: bool = false
var _force_sprint: bool = false

@onready var _visual: Node2D = $Visual


func _ready() -> void:
	_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D
	_sprite = get_node_or_null("Visual/Sprite") as AnimatedSprite2D
	if input_path:
		_router = get_node_or_null(input_path) as InputRouter
	up_direction = Vector2.UP
	floor_snap_length = 8.0
	floor_max_angle = deg_to_rad(50.0)
	motion_mode = MOTION_MODE_GROUNDED
	_apply_stand_shape()
	position = Vector2(Layout.START_X, Layout.stand_y())
	velocity = Vector2.ZERO
	_play_pose("idle")


func _physics_process(delta: float) -> void:
	if _invuln > 0.0:
		_invuln = maxf(_invuln - delta, 0.0)
		if _visual:
			_visual.modulate.a = 0.45 if int(_invuln * 16.0) % 2 == 0 else 1.0
	elif _visual:
		_visual.modulate.a = 1.0

	var frozen := GameClock.is_soft_frozen() or _fallen
	var axis := 0.0
	var jump_held := false
	var jump_pressed := false
	var slide_pressed := false
	var sprint := false
	if _use_force:
		axis = _force_axis
		jump_held = _force_jump_held
		jump_pressed = _force_jump_pressed
		slide_pressed = _force_slide
		sprint = _force_sprint
		_force_jump_pressed = false
		_force_slide = false
	elif _router and not frozen:
		axis = _router.move_axis()
		jump_held = _router.jump_held()
		jump_pressed = _router.consume_jump_pressed()
		slide_pressed = _router.consume_slide_pressed()
		sprint = _router.sprint_held()
	elif _router and frozen:
		_router.consume_jump_pressed()
		_router.consume_slide_pressed()

	if frozen:
		velocity = Vector2.ZERO
		_update_pose()
		return

	if jump_pressed:
		_jump_buf = 0.12
	else:
		_jump_buf = maxf(_jump_buf - delta, 0.0)

	if is_on_floor():
		_coyote = 0.1
	else:
		_coyote = maxf(_coyote - delta, 0.0)

	var jumped_now := false
	if _jump_buf > 0.0 and _coyote > 0.0:
		_end_slide()
		velocity.y = Layout.JUMP_VELOCITY
		_jump_buf = 0.0
		_coyote = 0.0
		_cut_armed = true
		jumped_now = true
		jumped.emit()

	if _cut_armed and not jump_held and velocity.y < 0.0:
		velocity.y *= Layout.JUMP_CUT
		_cut_armed = false

	if _sliding:
		_slide_left -= delta
		if _slide_left <= 0.0 or (not is_on_floor() and _slide_left < 0.32):
			_end_slide()

	if slide_pressed and is_on_floor() and not _sliding and not jumped_now:
		_start_slide()

	var speed := Layout.SPRINT_SPEED if sprint else Layout.RUN_SPEED
	if _sliding:
		velocity.x = float(facing) * speed * 1.05
	else:
		velocity.x = axis * speed
		if absf(axis) > 0.1:
			facing = 1 if axis > 0.0 else -1

	if not is_on_floor() or velocity.y < 0.0:
		velocity.y = minf(velocity.y + Layout.GRAVITY * delta, Layout.MAX_FALL)
	elif velocity.y > 0.0:
		velocity.y = 0.0

	floor_snap_length = 0.0 if velocity.y < 0.0 else 8.0
	move_and_slide()
	_update_facing()
	_update_pose()

	if _invuln <= 0.0 and position.y > Layout.KILL_Y:
		_fallen = true
		velocity = Vector2.ZERO
		pit_fallen.emit()


func is_grounded() -> bool:
	return is_on_floor()


func is_sliding_now() -> bool:
	return _sliding


func is_fallen() -> bool:
	return _fallen


func collision_height() -> float:
	if _shape == null or _shape.shape == null:
		return 0.0
	return (_shape.shape as RectangleShape2D).size.y


func force_input(axis: float, jump_held: bool, jump_pressed: bool, slide_pressed: bool, sprint: bool) -> void:
	_use_force = true
	_force_axis = axis
	_force_jump_held = jump_held
	_force_jump_pressed = jump_pressed
	_force_slide = slide_pressed
	_force_sprint = sprint


func clear_force() -> void:
	_use_force = false
	_force_axis = 0.0
	_force_jump_held = false
	_force_jump_pressed = false
	_force_slide = false
	_force_sprint = false


func respawn_at(world_pos: Vector2) -> void:
	position = world_pos
	velocity = Vector2.ZERO
	_fallen = false
	_invuln = 0.75
	_coyote = 0.1
	_jump_buf = 0.0
	_cut_armed = false
	_end_slide()
	_update_pose()
	respawned.emit()


func _start_slide() -> void:
	_sliding = true
	_slide_left = 0.62
	_apply_slide_shape()
	slid.emit()


func _end_slide() -> void:
	if not _sliding and _shape:
		_apply_stand_shape()
	_sliding = false
	_slide_left = 0.0
	_apply_stand_shape()


func _apply_stand_shape() -> void:
	if _shape == null or not (_shape.shape is RectangleShape2D):
		return
	var rect := _shape.shape as RectangleShape2D
	rect.size = Vector2(Layout.STAND_HALF_W * 2.0, Layout.STAND_BOTTOM - Layout.STAND_TOP)
	_shape.position = Vector2(0.0, (Layout.STAND_TOP + Layout.STAND_BOTTOM) * 0.5)


func _apply_slide_shape() -> void:
	if _shape == null or not (_shape.shape is RectangleShape2D):
		return
	var rect := _shape.shape as RectangleShape2D
	rect.size = Vector2(Layout.SLIDE_HALF_W * 2.0, Layout.SLIDE_BOTTOM - Layout.SLIDE_TOP)
	_shape.position = Vector2(6.0 * float(facing), (Layout.SLIDE_TOP + Layout.SLIDE_BOTTOM) * 0.5)


func _update_facing() -> void:
	if _sprite:
		_sprite.flip_h = facing < 0


func _update_pose() -> void:
	if _sprite:
		_sprite.position.y = 14.0 if _sliding else -6.0
	if _sliding:
		_play_pose("slide")
	elif not is_on_floor():
		_play_pose("jump")
	elif absf(velocity.x) > 10.0:
		# 脚在地上并且在往左右走就迈腿。不看歌曲时钟，停住才是待机。
		_play_pose("run")
	else:
		_play_pose("idle")


func _play_pose(anim: String) -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return
	if not _sprite.sprite_frames.has_animation(anim):
		return
	if _sprite.animation == anim and _sprite.is_playing():
		return
	_sprite.play(anim)
