extends Node
## 无头检查跑跳、滑铲、掉坑、亲亲冻结、接住布布加命、布布停留、谱面铺关，以及开始游戏锁钟自动跑。
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
	if not _jump_sprite_clean():
		return _fail("jump sprite has a stray fragment or bottom-right blob")

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
	if not await _run_cadence(player, sprite):
		return false
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
	if sprite.animation != "slide" or absf(sprite.rotation) > 0.01 or absf(sprite.position.y - 14.0) > 0.6:
		return _fail("slide pose anim %s rot %s y %s" % [sprite.animation, sprite.rotation, sprite.position.y])
	if sprite.scale.distance_to(Vector2.ONE) > 0.02:
		return _fail("slide scale %s" % sprite.scale)

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
	if not await _buddy_hold(host):
		return false
	if not await _song_autorun(host):
		return false
	if not await _hurt_boxes(host):
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


## 慢 3.5 秒的人在旧逻辑里会在进画面的同一帧把布布清掉。她现在要留到人跑过。
func _buddy_hold(host: Node) -> bool:
	# 上一局 queue_free 要等帧末才走 _exit_tree。先让它停钟，再开新局。
	for _i in 3:
		await get_tree().process_frame
	var game: Node = load("res://scenes/game/Game.tscn").instantiate()
	host.add_child(game)
	for _i in 20:
		await get_tree().process_frame
		if GameClock.is_playing:
			break
	if not GameClock.is_playing:
		return _fail("buddy hold: clock did not start")
	GameClock.soft_freeze()
	var player: RunnerController = game.get_node("World/Player")
	var buddy: Node2D = game.get_node("World/Buddy")
	var catcher: BuddyCatch = game.get_node("BuddyCatch")
	var hud: GameHUD = game.get_node("HUD")
	var hit := 13.0
	var anchor_x := TrackLayout.x_at_time(hit)
	var late := 3.5
	var kisses := {"n": 0}
	var brushes := {"n": 0}
	var brush_t := {"t": -1.0}
	catcher.caught.connect(func(): kisses["n"] += 1)
	catcher.brushed.connect(func():
		brushes["n"] += 1
		brush_t["t"] = GameClock.song_time_sec
	)
	var first_on := -1.0
	var last_on := -1.0
	var saw_after_window := false
	var seen_vis := false
	var i := 0
	while i <= 460:
		var t := i * 0.05
		GameClock.song_time_sec = t
		player.position = Vector2(TrackLayout.x_at_time(t - late), TrackLayout.stand_y())
		player.velocity = Vector2.ZERO
		await get_tree().process_frame
		if absf(t - (hit + 0.5)) <= 0.026:
			saw_after_window = true
			if not buddy.visible:
				return _fail("buddy hidden %.2fs after the beat while player is still behind" % (t - hit))
			if absf(buddy.position.x - anchor_x) > 200.0:
				return _fail("buddy left her mark at x=%.0f (anchor %.0f)" % [buddy.position.x, anchor_x])
		if buddy.visible:
			seen_vis = true
		elif seen_vis and brushes["n"] == 0:
			return _fail("buddy hidden at t=%.2f before the miss resolved" % t)
		var on := _buddy_in_view(player, buddy)
		if on:
			if first_on < 0.0:
				first_on = t
			last_on = t
		if brushes["n"] > 0:
			break
		i += 1
	var held := last_on - first_on
	print("buddy late hold %.2fs (%.2f..%.2f) brush_t=%.2f" % [held, first_on, last_on, brush_t["t"]])
	if not saw_after_window:
		return _fail("late run never sampled the post-window frame")
	if first_on < 0.0 or held < 2.0:
		return _fail("late buddy on screen only %.2fs" % held)
	if kisses["n"] != 0:
		return _fail("late pass should not kiss")
	if brushes["n"] != 1:
		return _fail("late pass brushes %s" % brushes["n"])
	if brush_t["t"] < hit + 1.5:
		return _fail("brush fired too early at %.2f" % brush_t["t"])
	if hud.lives_label.text != "生命 3":
		return _fail("late brush changed lives to %s" % hud.lives_label.text)

	GameClock.song_time_sec = 0.0
	player.position = Vector2(TrackLayout.START_X, TrackLayout.stand_y())
	catcher.reset_for_chart()
	var pace_kisses := {"n": 0}
	catcher.caught.connect(func(): pace_kisses["n"] += 1)
	var pace_first := -1.0
	var pace_catch := -1.0
	var pace_gap := false
	i = 0
	while i <= 280:
		var t := i * 0.05
		GameClock.song_time_sec = t
		player.position = Vector2(TrackLayout.x_at_time(t), TrackLayout.stand_y())
		player.velocity = Vector2.ZERO
		await get_tree().process_frame
		var on := _buddy_in_view(player, buddy)
		if pace_kisses["n"] > 0:
			pace_catch = t
			break
		if on:
			if pace_first < 0.0:
				pace_first = t
		elif pace_first >= 0.0:
			pace_gap = true
			break
		i += 1
	var pace_held := pace_catch - pace_first
	print("buddy pace hold %.2fs until kiss (%.2f..%.2f)" % [pace_held, pace_first, pace_catch])
	if pace_gap or pace_first < 0.0 or pace_catch < 0.0 or pace_held < 3.0:
		return _fail("on-pace approach %.2fs gap=%s" % [pace_held, pace_gap])
	if not buddy.visible:
		return _fail("buddy hidden at the moment of the kiss")
	GameClock.stop()
	game.queue_free()
	await get_tree().process_frame
	print("buddy hold ok")
	return true


## 标题「开始游戏」进的就是这首 song_01。横坐标跟歌曲走，按左和冲刺拉不走。
func _song_autorun(host: Node) -> bool:
	ChartLoader.clear_run_override(get_tree())
	for _i in 3:
		await get_tree().process_frame
	var game: Node = load("res://scenes/game/Game.tscn").instantiate()
	host.add_child(game)
	GameClock.set_process(false)
	var player: RunnerController = game.get_node("World/Player")
	if not player.clock_locked:
		return _autorun_fail(game, "title start is not clock locked")
	if str(ChartLoader.chart.get("songId", "")) != "song_01":
		return _autorun_fail(game, "title start song %s" % ChartLoader.chart.get("songId", ""))
	for sfx_name in ["perfect", "good", "miss", "kiss", "jump", "slide"]:
		if not game.has_sfx(sfx_name):
			return _autorun_fail(game, "missing sfx %s" % sfx_name)
	var worst := 0.0
	for i in 21:
		var t := float(i) * 0.2
		GameClock.song_time_sec = t
		player.force_input(-1.0, false, false, false, true)
		await get_tree().physics_frame
		worst = maxf(worst, absf(player.position.x - TrackLayout.x_at_time(t)))
	print("song autorun worst=%.3f" % worst)
	if worst > 1.0:
		return _autorun_fail(game, "auto-run drifted %.2f px" % worst)
	if player.facing < 0:
		return _autorun_fail(game, "left input flipped facing")
	player.clear_force()
	Input.action_press("move_left")
	Input.action_press("sprint")
	GameClock.song_time_sec = 0.5
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("move_left")
	Input.action_release("sprint")
	if absf(player.position.x - TrackLayout.x_at_time(0.5)) > 1.0:
		return _autorun_fail(game, "holding left pulled off beat at %s" % player.position.x)
	GameClock.song_time_sec = 1.0
	for _i in 60:
		player.force_input(0.0, false, false, false, false)
		await get_tree().physics_frame
		if player.is_grounded() and absf(player.position.y - TrackLayout.stand_y()) < 1.0:
			break
	if not player.is_grounded():
		return _autorun_fail(game, "not grounded before jump at %s" % player.position)
	var y0 := player.position.y
	player.force_input(-1.0, true, true, false, false)
	GameClock.song_time_sec = 1.15
	await get_tree().physics_frame
	if player.position.y >= y0 - 1.0:
		return _autorun_fail(game, "auto-run jump did not rise")
	if absf(player.position.x - TrackLayout.x_at_time(1.15)) > 1.0:
		return _autorun_fail(game, "jump pulled x off the beat")
	for _i in 50:
		GameClock.song_time_sec = 1.3
		player.force_input(0.0, false, false, false, false)
		await get_tree().physics_frame
		if player.is_grounded():
			break
	if not player.is_grounded():
		return _autorun_fail(game, "did not land after jump at %s" % player.position)
	player.force_input(-1.0, false, false, true, true)
	GameClock.song_time_sec = 2.0
	await get_tree().physics_frame
	if not player.is_sliding_now():
		return _autorun_fail(game, "slide ignored during auto-run")
	if absf(player.position.x - TrackLayout.x_at_time(2.0)) > 1.0:
		return _autorun_fail(game, "slide pulled x off the beat")
	var falls := {"n": 0}
	player.pit_fallen.connect(func() -> void: falls["n"] += 1)
	GameClock.song_time_sec = 10.0
	player.position.y = TrackLayout.KILL_Y + 80.0
	await get_tree().physics_frame
	if falls["n"] < 1:
		return _autorun_fail(game, "pit did not cost a life")
	for i in 4:
		GameClock.song_time_sec = 10.0 + float(i) * 0.05
		await get_tree().physics_frame
		if absf(player.position.x - TrackLayout.x_at_time(GameClock.song_time_sec)) > 1.0:
			return _autorun_fail(game, "respawn left the clock at %s" % player.position)
		if absf(player.position.y - TrackLayout.stand_y()) > 2.0:
			return _autorun_fail(game, "respawn fell back into the pit at %s" % player.position)
	var hud: GameHUD = game.get_node("HUD")
	if hud.lives_label.text != "生命 2":
		return _autorun_fail(game, "pit lives %s" % hud.lives_label.text)
	GameClock.set_process(true)
	GameClock.stop()
	game.queue_free()
	await get_tree().process_frame
	print("song autorun ok")
	return true


func _autorun_fail(game: Node, msg: String) -> bool:
	Input.action_release("move_left")
	Input.action_release("sprint")
	GameClock.set_process(true)
	GameClock.stop()
	if is_instance_valid(game):
		game.queue_free()
	return _fail(msg)


## 矮丛和花门不再是墙。站在里面只记 Miss，不扣命，横坐标仍跟歌曲。
func _hurt_boxes(host: Node) -> bool:
	var slide_art_top := 14.0 + (30.0 - 64.0)
	var opening_local := TrackLayout.FEET_OFFSET - TrackLayout.ARCH_CLEARANCE
	if slide_art_top < opening_local + 6.0:
		return _fail("slide art still clips the arch (art %.1f opening %.1f)" % [slide_art_top, opening_local])
	var arch_hurt_bottom := opening_local - TrackLayout.ARCH_HURT_INSET
	if TrackLayout.HURT_STAND.position.y > arch_hurt_bottom - 4.0:
		return _fail("stand hurt no longer reaches the gate")
	if TrackLayout.HURT_SLIDE.position.y < arch_hurt_bottom:
		return _fail("slide hurt still intersects the gate")

	ChartLoader.clear_run_override(get_tree())
	for _i in 3:
		await get_tree().process_frame
	var game: Node = load("res://scenes/game/Game.tscn").instantiate()
	host.add_child(game)
	GameClock.set_process(false)
	var player: RunnerController = game.get_node("World/Player")
	var park: ParkCourse = game.get_node("World/ParkCourse")
	var tracker: ScoreTracker = game.get_node("ScoreTracker")
	var hud: GameHUD = game.get_node("HUD")
	park.spawn_all()
	if park.solid_gate_count() != 0:
		return _hurt_fail(game, "bush or arch is still a solid wall")
	var pit_x := TrackLayout.x_at_time(10.0)
	if not park.ground_covers(pit_x - 64.0 + 4.0):
		return _hurt_fail(game, "pit lip is not solid")
	if park.ground_covers(pit_x):
		return _hurt_fail(game, "pit center is still ground")
	if not InputMap.has_action("debug_hitboxes"):
		return _hurt_fail(game, "missing debug_hitboxes")
	var debug := park.get_node("HitboxDebug")
	debug.toggle()
	if not debug.enabled:
		return _hurt_fail(game, "hitbox debug did not turn on")
	debug.toggle()
	if debug.enabled:
		return _hurt_fail(game, "hitbox debug did not turn off")

	GameClock.song_time_sec = 1.0
	for _i in 8:
		player.force_input(0.0, false, false, false, false)
		await get_tree().physics_frame
	if not player.is_grounded():
		return _hurt_fail(game, "not grounded before hurt checks at %s" % player.position)
	var stand_h := player.hurt_rect().size.y
	var misses := tracker.miss_count
	if not await _expect_brush(game, player, tracker, hud, 4.0, misses + 1, false):
		return false
	if not await _expect_brush(game, player, tracker, hud, 7.0, misses + 2, false):
		return false
	var before_platform := tracker.miss_count
	if not await _hold_on_clock(game, player, 16.5, false):
		return false
	if tracker.miss_count != before_platform:
		return _hurt_fail(game, "platform on the ground counted as a hit")
	GameClock.song_time_sec = 19.5
	var raised := TrackLayout.stand_y() - 120.0
	player.position.y = raised
	player.velocity = Vector2.ZERO
	await get_tree().physics_frame
	if tracker.miss_count != before_platform:
		return _hurt_fail(game, "jumping over the bush counted as a hit")
	if absf(player.position.x - TrackLayout.x_at_time(19.5)) > 1.5:
		return _hurt_fail(game, "airborne x left the clock")
	if player.position.y > raised + 48.0:
		return _hurt_fail(game, "airborne player was shoved down to %s" % player.position.y)
	var plat_top := 0.0
	for h in park._hazards:
		if str(h.get("type", "")) == "platform" and absf(float(h.get("t", -1.0)) - 16.5) < 0.01:
			plat_top = float(h["top"])
	if plat_top <= 1.0:
		return _hurt_fail(game, "platform top missing")
	GameClock.song_time_sec = 16.5
	player.velocity = Vector2.ZERO
	player.position.y = plat_top - TrackLayout.FEET_OFFSET - 36.0
	var landed := false
	for _i in 50:
		player.force_input(0.0, false, false, false, false)
		await get_tree().physics_frame
		var feet := TrackLayout.feet_y(player.position.y)
		if player.is_grounded() and absf(feet - plat_top) < 12.0:
			landed = true
			break
	if not landed:
		return _hurt_fail(game, "did not land on the platform at %s" % player.position)
	if absf(player.position.x - TrackLayout.x_at_time(16.5)) > 1.5:
		return _hurt_fail(game, "landing pulled x off the platform beat")
	GameClock.song_time_sec = 1.2
	player.position.y = TrackLayout.stand_y()
	player.velocity = Vector2.ZERO
	for _i in 10:
		player.force_input(0.0, false, false, false, false)
		await get_tree().physics_frame
		if player.is_grounded():
			break
	if not player.is_grounded():
		return _hurt_fail(game, "did not land before the slide check")
	player.force_input(0.0, false, false, true, false)
	await get_tree().physics_frame
	if not player.is_sliding_now():
		return _hurt_fail(game, "slide did not start")
	if player.collision_height() > 36.0:
		return _hurt_fail(game, "slide physics height %s" % player.collision_height())
	if player.hurt_rect().size.y >= stand_h:
		return _hurt_fail(game, "slide hurt is not shorter than standing")
	var before_slide := tracker.miss_count
	if not await _hold_on_clock(game, player, 22.5, true):
		return false
	if tracker.miss_count != before_slide:
		return _hurt_fail(game, "sliding under the arch counted as a hit")
	if hud.lives_label.text != "生命 3":
		return _hurt_fail(game, "gate contact changed lives to %s" % hud.lives_label.text)
	GameClock.set_process(true)
	GameClock.stop()
	game.queue_free()
	await get_tree().process_frame
	print("hurt boxes ok")
	return true


func _expect_brush(game: Node, player: RunnerController, tracker: ScoreTracker, hud: GameHUD, beat: float, misses: int, sliding: bool) -> bool:
	if not await _hold_on_clock(game, player, beat, sliding):
		return false
	if tracker.miss_count != misses:
		return _hurt_fail(game, "contact at t=%.1f misses %s want %s" % [beat, tracker.miss_count, misses])
	if hud.lives_label.text != "生命 3":
		return _hurt_fail(game, "contact at t=%.1f lives %s" % [beat, hud.lives_label.text])
	return true


func _hold_on_clock(game: Node, player: RunnerController, beat: float, sliding: bool) -> bool:
	GameClock.song_time_sec = beat
	var y0 := player.position.y
	for _i in 4:
		player.force_input(-1.0, false, false, false, true)
		await get_tree().physics_frame
		if absf(player.position.x - TrackLayout.x_at_time(beat)) > 1.5:
			return _hurt_fail(game, "clock x drifted at t=%.1f pos %s" % [beat, player.position])
	if not sliding and absf(player.position.y - y0) > 6.0:
		return _hurt_fail(game, "gate shoved y at t=%.1f from %.1f to %.1f" % [beat, y0, player.position.y])
	if sliding and absf(player.position.y - TrackLayout.stand_y()) > 8.0:
		return _hurt_fail(game, "slide left the ground at %s" % player.position)
	return true


func _hurt_fail(game: Node, msg: String) -> bool:
	GameClock.set_process(true)
	GameClock.stop()
	if is_instance_valid(game):
		game.queue_free()
	return _fail(msg)


func _buddy_in_view(player: Node2D, buddy: Node2D) -> bool:
	if not buddy.visible:
		return false
	var cam := player.get_node("Camera2D") as Camera2D
	var center := player.global_position + cam.position
	var half := Vector2(640.0, 360.0)
	var sprite := buddy.get_node_or_null("Sprite") as Sprite2D
	var pad := 64.0
	if sprite and sprite.texture:
		pad = maxf(sprite.texture.get_width(), sprite.texture.get_height()) * 0.5
	var bp := buddy.global_position
	return absf(bp.x - center.x) <= half.x + pad and absf(bp.y - center.y) <= half.y + pad


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
	if not player.clock_locked:
		return _fail("shot run is not clock locked")
	GameClock.set_process(false)
	GameClock.song_time_sec = 0.0
	player.clear_force()
	for _i in 8:
		await get_tree().physics_frame
	if absf(player.position.x - TrackLayout.START_X) > 1.5:
		return _fail("shot start left the clock at %s" % player.position.x)
	if not await _grab(SHOT_DIR + "/park_start.png"):
		return false

	var sprite := player.get_node("Visual/Sprite") as AnimatedSprite2D
	if not await _grab_run_frame(player, sprite, 0, SHOT_DIR + "/park_run.png"):
		return false
	if not await _grab_run_frame(player, sprite, 1, SHOT_DIR + "/park_run_b.png"):
		return false
	if not await _grab_run_phase(player, sprite, 0.0, SHOT_DIR + "/park_run_plant.png"):
		return false
	if not await _grab_run_phase(player, sprite, 0.25, SHOT_DIR + "/park_run_float.png"):
		return false
	if not await _grab_run_phase(player, sprite, 0.5, SHOT_DIR + "/park_run_plant_b.png"):
		return false
	if not await _grab_run_phase(player, sprite, 0.75, SHOT_DIR + "/park_run_float_b.png"):
		return false

	var bush_err := await _advance_to(player, TrackLayout.x_at_time(4.0), 90.0)
	if bush_err != "":
		return _fail(bush_err)
	var debug := game.get_node("World/ParkCourse/HitboxDebug")
	debug.toggle()
	if not await _grab(SHOT_DIR + "/park_hitbox.png"):
		return false
	debug.toggle()
	for i in 18:
		GameClock.song_time_sec += 1.0 / 60.0
		player.force_input(-1.0, true, i == 0, false, true)
		await get_tree().physics_frame
	if absf(player.position.x - TrackLayout.x_at_time(GameClock.song_time_sec)) > 1.5:
		return _fail("jump shot left the beat")
	if not await _grab(SHOT_DIR + "/park_jump.png"):
		return false

	var arch_err := await _advance_to(player, TrackLayout.x_at_time(7.0), 120.0)
	if arch_err != "":
		return _fail(arch_err)
	for _i in 40:
		if player.is_grounded() and not player.is_sliding_now():
			break
		GameClock.song_time_sec += 1.0 / 60.0
		player.force_input(-1.0, false, false, false, true)
		await get_tree().physics_frame
	player.force_input(-1.0, false, false, true, true)
	GameClock.song_time_sec += 1.0 / 60.0
	await get_tree().physics_frame
	for _i in 8:
		GameClock.song_time_sec += 1.0 / 60.0
		player.force_input(-1.0, false, false, false, true)
		await get_tree().physics_frame
	if not player.is_sliding_now():
		return _fail("shot slide did not start")
	if absf(player.position.x - TrackLayout.x_at_time(GameClock.song_time_sec)) > 1.5:
		return _fail("slide shot left the beat")
	if not await _grab(SHOT_DIR + "/park_slide.png"):
		return false

	var pit_err := await _advance_to(player, TrackLayout.x_at_time(10.0), 160.0)
	if pit_err != "":
		return _fail(pit_err)
	if not await _grab(SHOT_DIR + "/park_pit.png"):
		return false
	player.clear_force()
	GameClock.set_process(true)
	GameClock.stop()
	print("shots ok")
	return true


## 按住左和冲刺的同时把歌曲时间往前拨。人只能跟着时钟走。
func _advance_to(player: RunnerController, target_x: float, slack: float) -> String:
	for _i in 520:
		if player.position.x > target_x - slack:
			if absf(player.position.x - TrackLayout.x_at_time(GameClock.song_time_sec)) > 1.5:
				return "left input left the beat at %s" % player.position.x
			return ""
		GameClock.song_time_sec += 1.0 / 60.0
		player.force_input(-1.0, false, false, false, true)
		await get_tree().physics_frame
	return "auto-run did not reach x %.0f (at %.0f)" % [target_x, player.position.x]


## 自由跑时整步大约 0.5 秒（120 BPM 一拍）。身体要有明显起伏，跳起来时压扁和前倾要收回。
func _run_cadence(player: RunnerController, sprite: AnimatedSprite2D) -> bool:
	var changes := 0
	var last := sprite.frame
	var min_y := sprite.position.y
	var max_y := sprite.position.y
	for _i in 72:
		player.force_input(1.0, false, false, false, false)
		await get_tree().physics_frame
		if not player.is_grounded() or sprite.animation != "run":
			return _fail("cadence left run at %s anim %s" % [player.position, sprite.animation])
		min_y = minf(min_y, sprite.position.y)
		max_y = maxf(max_y, sprite.position.y)
		if sprite.frame != last:
			changes += 1
			last = sprite.frame
	var bob := max_y - min_y
	print("run cadence changes=%s bob=%.1f" % [changes, bob])
	if changes < 3 or changes > 7:
		return _fail("run cadence changes %s (want about 4 per second)" % changes)
	if bob < 5.0:
		return _fail("run bob only %.1f px" % bob)

	player.set_clock_locked(true)
	GameClock.is_playing = true
	GameClock.song_time_sec = 0.0
	for _i in 6:
		player.force_input(0.0, false, false, false, false)
		await get_tree().physics_frame
	if not player.is_grounded() or sprite.animation != "run":
		return _fail("clock run not grounded anim %s" % sprite.animation)
	var phase_plant := player.run_cycle_phase()
	var y_plant := sprite.position.y
	GameClock.song_time_sec = 0.125
	player.force_input(0.0, false, false, false, false)
	await get_tree().physics_frame
	var phase_float := player.run_cycle_phase()
	var y_float := sprite.position.y
	print("run clock phase %.3f -> %.3f y %.1f -> %.1f" % [phase_plant, phase_float, y_plant, y_float])
	if absf(phase_plant) > 0.04 or absf(phase_float - 0.25) > 0.04:
		return _fail("clock phase plant %.3f float %.3f" % [phase_plant, phase_float])
	if y_float > y_plant - 4.0:
		return _fail("clock bob plant %.1f float %.1f" % [y_plant, y_float])
	player.force_input(0.0, true, true, false, false)
	await get_tree().physics_frame
	if sprite.animation != "jump" or absf(sprite.rotation) > 0.02 or absf(sprite.position.y + 6.0) > 0.6:
		return _fail("jump pose anim %s rot %s y %s" % [sprite.animation, sprite.rotation, sprite.position.y])
	if sprite.scale.distance_to(Vector2.ONE) > 0.02:
		return _fail("jump scale %s" % sprite.scale)
	player.set_clock_locked(false)
	GameClock.is_playing = false
	if not _sfx_tones():
		return false
	return true


func _sfx_tones() -> bool:
	var WavLib = load("res://scripts/audio/WavStream.gd")
	var specs := {
		"perfect": {"hz": 1318.5, "sec": 0.12},
		"good": {"hz": 880.0, "sec": 0.10},
		"miss": {"hz": 329.6, "sec": 0.13},
		"kiss": {"hz": 880.0, "sec": 0.20},
		"jump": {"hz": 880.0, "sec": 0.09},
		"slide": {"hz": 550.0, "sec": 0.09},
	}
	for name in specs:
		var stream := WavLib.load_file("res://assets/audio/sfx/%s.wav" % name) as AudioStreamWAV
		if stream == null or stream.stereo or stream.data.is_empty():
			return _fail("sfx %s missing" % name)
		var length := stream.get_length()
		var expect: float = specs[name]["sec"]
		if length < 0.05 or length > 0.24 or absf(length - expect) > 0.03:
			return _fail("sfx %s length %.3f" % [name, length])
		var rate := int(stream.mix_rate)
		var data := stream.data
		var count := data.size() / 2
		var peak := _pcm_peak(data, 0, count)
		var attack := _pcm_peak(data, 0, mini(count, int(0.002 * float(rate))))
		if peak < 1800 or peak > 14000:
			return _fail("sfx %s peak %s" % [name, peak])
		if attack > int(float(peak) * 0.35):
			return _fail("sfx %s attack %s peak %s" % [name, attack, peak])
		var hz: float = specs[name]["hz"]
		var tone := _goertzel(data, rate, 0.012, 0.05, hz)
		var mud := _goertzel(data, rate, 0.012, 0.05, 110.0)
		if tone < mud * 2.0:
			return _fail("sfx %s pitch %.0f lost to low end" % [name, hz])
	var miss := WavLib.load_file("res://assets/audio/sfx/miss.wav") as AudioStreamWAV
	var miss_note := _goertzel(miss.data, int(miss.mix_rate), 0.012, 0.06, 329.6)
	var miss_thud := _goertzel(miss.data, int(miss.mix_rate), 0.012, 0.06, 95.0)
	if miss_note < miss_thud * 3.0:
		return _fail("miss still sounds like a thud")
	print("sfx tones ok")
	return true


func _pcm_sample(data: PackedByteArray, index: int) -> int:
	var lo := int(data[index * 2])
	var hi := int(data[index * 2 + 1])
	var sample := lo | (hi << 8)
	if sample >= 32768:
		sample -= 65536
	return sample


func _pcm_peak(data: PackedByteArray, i0: int, i1: int) -> int:
	var peak := 0
	for i in range(i0, i1):
		peak = maxi(peak, absi(_pcm_sample(data, i)))
	return peak


func _goertzel(data: PackedByteArray, rate: int, t0: float, t1: float, freq: float) -> float:
	var count := data.size() / 2
	var i0 := clampi(int(t0 * float(rate)), 0, count)
	var i1 := clampi(int(t1 * float(rate)), i0, count)
	if i1 <= i0:
		return 0.0
	var coeff := 2.0 * cos(TAU * freq / float(rate))
	var s1 := 0.0
	var s2 := 0.0
	for i in range(i0, i1):
		var s0 := float(_pcm_sample(data, i)) + coeff * s1 - s2
		s2 = s1
		s1 = s0
	return s1 * s1 + s2 * s2 - coeff * s1 * s2


func _grab_run_phase(player: RunnerController, sprite: AnimatedSprite2D, phase: float, path: String) -> bool:
	var bpm := float(ChartLoader.chart.get("bpm", 120.0))
	var song_t := phase / (bpm / 60.0)
	# 截图时歌曲进程是关的，但保险起见每一步都把时钟钉在这一拍上，避免播放位置把相位冲掉。
	GameClock.set_process(false)
	var ready := false
	for _i in 8:
		GameClock.song_time_sec = song_t
		player.force_input(0.0, false, false, false, false)
		await get_tree().physics_frame
		if player.is_grounded() and sprite.animation == "run" and absf(player.run_cycle_phase() - phase) <= 0.04:
			ready = true
			break
	if not ready:
		return _fail("run phase want %.2f got %.3f song %.3f playing %s" % [phase, player.run_cycle_phase(), GameClock.song_time_sec, GameClock.is_playing])
	return await _grab(path)


func _grab_run_frame(player: RunnerController, sprite: AnimatedSprite2D, frame: int, path: String) -> bool:
	var seen := false
	for _i in 40:
		GameClock.song_time_sec += 1.0 / 60.0
		player.force_input(-1.0, false, false, false, true)
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


## 跳图只保留身体、腿和左侧蓬松尾巴。右下角的碎片和灰块都应该是透明的。
func _jump_sprite_clean() -> bool:
	var tex := load("res://assets/characters/yier_jump.png") as Texture2D
	if tex == null:
		return false
	var img := tex.get_image()
	if img == null:
		return false
	var w := img.get_width()
	var h := img.get_height()
	# 脚大约收在 y=96。再往下的右下角不能有成块的不透明像素。
	var corner := 0
	for y in range(98, h):
		for x in range(72, w):
			if img.get_pixel(x, y).a > 0.08:
				corner += 1
	if corner > 0:
		return false
	var seen := {}
	for y in h:
		for x in w:
			if seen.has(y * w + x):
				continue
			if img.get_pixel(x, y).a <= 0.12:
				continue
			var stack: Array[Vector2i] = [Vector2i(x, y)]
			var count := 0
			var min_y := y
			var min_x := x
			while not stack.is_empty():
				var p: Vector2i = stack.pop_back()
				if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h:
					continue
				var key := p.y * w + p.x
				if seen.has(key):
					continue
				if img.get_pixel(p.x, p.y).a <= 0.12:
					continue
				seen[key] = true
				count += 1
				min_y = mini(min_y, p.y)
				min_x = mini(min_x, p.x)
				stack.append(Vector2i(p.x + 1, p.y))
				stack.append(Vector2i(p.x - 1, p.y))
				stack.append(Vector2i(p.x, p.y + 1))
				stack.append(Vector2i(p.x, p.y - 1))
			# 脸上的眼睛是分开的小块，都在 y<70。脚以下的孤岛才是碎片。
			if count >= 16 and min_y >= 70:
				return false
			if count >= 24 and min_x >= 80 and min_y >= 90:
				return false
	return true


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
