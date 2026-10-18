extends Node
## 无头检查跑跳、滑铲、掉坑、亲亲冻结、接住布布加命和谱面铺关。
## 带 --shots 时再用 OpenGL 视口截恋爱公园。
## 作为场景运行（不要 --script），自动加载才在编译期可见。

const SHOT_DIR := "/opt/cursor/artifacts/screenshots"


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var failed := false
	var shots := "--shots" in OS.get_cmdline_user_args()
	if not await _logic():
		failed = true
	if not failed and shots:
		if not await _shots():
			failed = true
	if failed:
		print("MVP_FAIL")
		get_tree().quit(1)
		return
	print("MVP_OK")
	get_tree().quit(0)


func _logic() -> bool:
	if not ChartLoader.load_chart("res://charts/song_01.json"):
		return _fail("chart: %s" % str(ChartLoader.get_last_errors()))
	var kinds := {}
	for n in ChartLoader.notes:
		kinds[ChartLoader.canonical_type(str(n.get("type", "")))] = true
	for need in ["low", "high", "pit", "platform", "buddy"]:
		if not kinds.has(need):
			return _fail("chart missing %s" % need)
	var bad := {"schemaVersion": 1, "songId": "x", "title": "x", "audio": "x", "bpm": 120, "durationSec": 10, "notes": [{"t": 1.0, "type": "nope"}]}
	if ChartLoader.validate_chart(bad):
		return _fail("bad type was accepted")
	if not ChartLoader.load_chart("res://charts/song_01.json"):
		return _fail("reload chart")
	for action in ["move_left", "move_right", "jump", "slide", "sprint"]:
		if not InputMap.has_action(action):
			return _fail("missing action %s" % action)

	var host := get_tree().root
	var router := InputRouter.new()
	host.add_child(router)
	Input.action_press("move_right")
	await get_tree().physics_frame
	if router.move_axis() < 0.9:
		return _fail("move_right axis %s" % router.move_axis())
	Input.action_release("move_right")
	Input.action_press("sprint")
	await get_tree().physics_frame
	if not router.sprint_held():
		return _fail("sprint not held")
	Input.action_release("sprint")
	router.queue_free()

	var world := Node2D.new()
	host.add_child(world)
	_add_ground(world, -200.0, 900.0)
	_add_ground(world, 1100.0, 2200.0)
	var player: RunnerController = load("res://scenes/game/Player.tscn").instantiate()
	player.input_path = NodePath("")
	world.add_child(player)
	for _i in 8:
		player.force_input(0.0, false, false, false, false)
		await get_tree().physics_frame
	if not player.is_grounded():
		return _fail("not grounded at %s vel %s" % [player.position, player.velocity])
	if not _jump_tail_connected():
		return _fail("jump tail is disconnected from the body")

	var sprite := player.get_node("Visual/Sprite") as AnimatedSprite2D
	GameClock.is_playing = false
	var seen := {}
	for _i in 48:
		player.force_input(1.0, false, false, false, false)
		await get_tree().physics_frame
		if not player.is_grounded():
			return _fail("run cycle left the ground at %s" % player.position)
		if sprite.animation != "run":
			return _fail("ground move anim %s frame %s" % [sprite.animation, sprite.frame])
		seen[sprite.frame] = true
	if not seen.has(0) or not seen.has(1):
		return _fail("run cycle missing frames %s" % seen)
	player.respawn_at(Vector2(TrackLayout.START_X, TrackLayout.stand_y()))
	for _i in 6:
		player.force_input(0.0, false, false, false, false)
		await get_tree().physics_frame

	var full := await _jump_rise(player, true)
	player.respawn_at(Vector2(player.position.x, TrackLayout.stand_y()))
	for _i in 6:
		player.force_input(0.0, false, false, false, false)
		await get_tree().physics_frame
	var short := await _jump_rise(player, false)
	print("jump rise full=%.1f short=%.1f" % [full, short])
	if full < 70.0 or short > 55.0 or full < short + 35.0:
		return _fail("variable jump full=%.1f short=%.1f" % [full, short])

	player.respawn_at(Vector2(240.0, TrackLayout.stand_y()))
	for _i in 4:
		player.force_input(0.0, false, false, false, false)
		await get_tree().physics_frame
	player.force_input(0.0, false, false, true, false)
	await get_tree().physics_frame
	if not player.is_sliding_now() or player.collision_height() > 36.0:
		return _fail("slide height %s sliding %s" % [player.collision_height(), player.is_sliding_now()])

	var pit_hits := {"n": 0}
	player.pit_fallen.connect(func(): pit_hits["n"] += 1)
	player.respawn_at(Vector2(860.0, TrackLayout.stand_y()))
	for _i in 70:
		player.force_input(1.0, false, false, false, false)
		await get_tree().physics_frame
		if pit_hits["n"] > 0:
			break
	if pit_hits["n"] < 1:
		return _fail("expected pit fall, pos %s" % player.position)

	player.respawn_at(Vector2(980.0, 40.0))
	GameClock.is_playing = true
	GameClock.soft_freeze()
	var frozen_y := player.position.y
	for _i in 20:
		player.force_input(1.0, true, true, true, true)
		await get_tree().physics_frame
	if absf(player.position.y - frozen_y) > 0.01 or pit_hits["n"] != 1:
		return _fail("freeze moved y %.2f -> %.2f pits %s" % [frozen_y, player.position.y, pit_hits["n"]])
	GameClock.soft_resume()
	var fell_again := false
	for _i in 80:
		player.force_input(0.0, false, false, false, false)
		await get_tree().physics_frame
		if pit_hits["n"] >= 2:
			fell_again = true
			break
	if not fell_again:
		return _fail("expected fall after resume, pos %s" % player.position)
	GameClock.stop()

	var buddy := BuddyCatch.new()
	host.add_child(buddy)
	await get_tree().process_frame
	var anchor := Vector2(1000, TrackLayout.stand_y())
	if not buddy.within_catch(anchor + Vector2(40, 0), anchor, 13.0, 13.1):
		return _fail("buddy window should accept")
	if buddy.within_catch(anchor + Vector2(400, 0), anchor, 13.0, 13.0):
		return _fail("buddy far x should reject")
	if buddy.within_catch(anchor, anchor, 13.0, 14.2):
		return _fail("buddy late time should reject")
	buddy.queue_free()

	var park := ParkCourse.new()
	world.add_child(park)
	park.build_from_chart(player, null)
	if park.ground_body_count() < 3:
		return _fail("ground segments %s" % park.ground_body_count())
	if park.checkpoint_count() < 4:
		return _fail("checkpoints %s" % park.checkpoint_count())
	if park.hazard_total() < 8:
		return _fail("hazards %s" % park.hazard_total())
	GameClock.song_time_sec = 0.0
	GameClock.is_playing = true
	await get_tree().process_frame
	var spawned := park.spawned_count()
	print("spawned %s / %s" % [spawned, park.hazard_total()])
	if spawned < 1 or spawned >= park.hazard_total():
		return _fail("spawn lead spawned=%s total=%s" % [spawned, park.hazard_total()])
	var spot := park.current_checkpoint(TrackLayout.x_at_time(10.0))
	if spot.x >= TrackLayout.x_at_time(10.0):
		return _fail("checkpoint inside pit %s" % spot)
	GameClock.stop()
	world.queue_free()

	if not await _kiss_life(host):
		return false
	print("logic ok")
	return true


func _kiss_life(host: Node) -> bool:
	var game: Node = load("res://scenes/game/Game.tscn").instantiate()
	host.add_child(game)
	if not GameClock.is_playing:
		return _fail("kiss life: clock did not start")
	# 冻住歌曲时间，把人放到第一只布布的脚下，走真正的接住路径。
	GameClock.soft_freeze()
	var hit := 13.0
	var anchor := Vector2(TrackLayout.x_at_time(hit), TrackLayout.stand_y())
	var player: RunnerController = game.get_node("World/Player")
	player.position = anchor
	player.velocity = Vector2.ZERO
	GameClock.song_time_sec = hit
	var hud: GameHUD = game.get_node("HUD")
	var catcher: BuddyCatch = game.get_node("BuddyCatch")
	var tracker: ScoreTracker = game.get_node("ScoreTracker")
	if hud.lives_label.text != "生命 3":
		return _fail("start lives %s" % hud.lives_label.text)
	var kissed := false
	for _i in 4:
		await get_tree().process_frame
		if hud.lives_label.text == "生命 4":
			kissed = true
			break
	if not kissed:
		return _fail("kiss should grant life, got %s kisses %s" % [hud.lives_label.text, tracker.kiss_count])
	if hud.judge_label.text != "生命 +1":
		return _fail("life flash %s" % hud.judge_label.text)
	if tracker.kiss_count != 1:
		return _fail("kiss score %s" % tracker.kiss_count)
	if not hud.kiss_overlay.visible:
		return _fail("kiss overlay missing")
	var lives_after_kiss := hud.lives_label.text
	catcher.brushed.emit()
	await get_tree().process_frame
	if hud.lives_label.text != lives_after_kiss:
		return _fail("brush changed lives to %s" % hud.lives_label.text)
	catcher.caught.emit()
	await get_tree().process_frame
	if hud.lives_label.text != "生命 5":
		return _fail("second kiss lives %s" % hud.lives_label.text)
	hud.flash_judge("")
	catcher.caught.emit()
	await get_tree().process_frame
	if hud.lives_label.text != "生命 5":
		return _fail("life cap %s" % hud.lives_label.text)
	if hud.judge_label.text == "生命 +1":
		return _fail("capped kiss still flashed a life")
	if tracker.kiss_count != 3:
		return _fail("capped kiss dropped score %s" % tracker.kiss_count)
	GameClock.stop()
	game.queue_free()
	print("kiss life ok")
	return true


func _jump_rise(player: RunnerController, hold: bool) -> float:
	var start_y := player.position.y
	var min_y := start_y
	for i in 50:
		var pressed := i == 0
		var held := hold or i == 0
		player.force_input(0.0, held, pressed, false, false)
		await get_tree().physics_frame
		min_y = minf(min_y, player.position.y)
	return start_y - min_y


func _add_ground(parent: Node, x0: float, x1: float) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(x1 - x0, 80.0)
	col.shape = shape
	col.position = Vector2((x0 + x1) * 0.5, TrackLayout.GROUND_Y + 40.0)
	body.add_child(col)
	parent.add_child(body)


func _shots() -> bool:
	DirAccess.make_dir_recursive_absolute(SHOT_DIR)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var host := get_tree().root
	var title: Node = load("res://scenes/title/Title.tscn").instantiate()
	host.add_child(title)
	if not await _grab(SHOT_DIR + "/title.png"):
		return false
	title.queue_free()
	await get_tree().process_frame

	var game: Node = load("res://scenes/game/Game.tscn").instantiate()
	host.add_child(game)
	var player: RunnerController = game.get_node("World/Player")
	var cam := player.get_node("Camera2D") as Camera2D
	cam.make_current()
	var ready := false
	for _i in 180:
		await get_tree().physics_frame
		if GameClock.is_playing:
			ready = true
			break
	if not ready:
		return _fail("game clock did not start")
	player.force_input(0.0, false, false, false, false)
	for _i in 12:
		await get_tree().physics_frame
	if not await _grab(SHOT_DIR + "/park_start.png"):
		return false

	var sprite := player.get_node("Visual/Sprite") as AnimatedSprite2D
	if not await _grab_run_frame(player, sprite, 0, SHOT_DIR + "/park_run.png"):
		return false
	if not await _grab_run_frame(player, sprite, 1, SHOT_DIR + "/park_run_b.png"):
		return false

	var bush_x := TrackLayout.x_at_time(4.0)
	for _i in 240:
		var dx := bush_x - player.position.x
		if dx < 90.0:
			break
		player.force_input(1.0, false, false, false, false)
		await get_tree().physics_frame
	for i in 18:
		player.force_input(1.0, true, i == 0, false, false)
		await get_tree().physics_frame
	if not await _grab(SHOT_DIR + "/park_jump.png"):
		return false

	var arch_x := TrackLayout.x_at_time(7.0)
	for _i in 240:
		if player.position.x > arch_x - 120.0:
			break
		player.force_input(1.0, false, false, false, false)
		await get_tree().physics_frame
	player.force_input(1.0, false, false, true, false)
	await get_tree().physics_frame
	for _i in 8:
		player.force_input(1.0, false, false, false, false)
		await get_tree().physics_frame
	if not await _grab(SHOT_DIR + "/park_slide.png"):
		return false

	var pit_x := TrackLayout.x_at_time(10.0)
	for _i in 300:
		if player.position.x > pit_x - 160.0:
			break
		player.force_input(1.0, false, false, false, false)
		await get_tree().physics_frame
	if not await _grab(SHOT_DIR + "/park_pit.png"):
		return false
	player.clear_force()
	GameClock.stop()
	print("shots ok")
	return true


func _grab_run_frame(player: RunnerController, sprite: AnimatedSprite2D, frame: int, path: String) -> bool:
	var seen := false
	for _i in 40:
		player.force_input(1.0, false, false, false, false)
		await get_tree().physics_frame
		if sprite.animation == "run" and sprite.frame == frame:
			seen = true
			break
	if not seen:
		return _fail("run frame %s not reached (anim %s frame %s)" % [frame, sprite.animation, sprite.frame])
	sprite.speed_scale = 0.0
	sprite.frame = frame
	var ok := await _grab(path)
	sprite.speed_scale = 1.0
	return ok


## 跳图的尾巴尖必须和身体连在同一块不透明像素上。
func _jump_tail_connected() -> bool:
	var tex := load("res://assets/characters/yier_jump.png") as Texture2D
	if tex == null:
		return false
	var img := tex.get_image()
	if img == null:
		return false
	var w := img.get_width()
	var h := img.get_height()
	var seen := {}
	var stack: Array[Vector2i] = []
	var seeded := false
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a > 0.15:
				stack.append(Vector2i(x, y))
				seeded = true
				break
		if seeded:
			break
	var reached_tip := false
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h:
			continue
		var key := p.y * w + p.x
		if seen.has(key):
			continue
		if img.get_pixel(p.x, p.y).a <= 0.15:
			continue
		seen[key] = true
		if p.y >= 110 and p.x >= 95:
			reached_tip = true
		stack.append(Vector2i(p.x + 1, p.y))
		stack.append(Vector2i(p.x - 1, p.y))
		stack.append(Vector2i(p.x, p.y + 1))
		stack.append(Vector2i(p.x, p.y - 1))
	return reached_tip


func _grab(path: String) -> bool:
	for _i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null or img.get_width() < 32 or img.get_height() < 32:
		return _fail("empty screenshot %s" % path)
	var sample := img.get_pixel(img.get_width() / 2, img.get_height() / 2)
	if sample.r < 0.02 and sample.g < 0.02 and sample.b < 0.02:
		return _fail("black screenshot %s" % path)
	img.save_png(path)
	print("shot %s %sx%s" % [path, img.get_width(), img.get_height()])
	return true


func _fail(msg: String) -> bool:
	push_error(msg)
	print("FAIL: ", msg)
	return false
