extends Node2D
class_name ParkCourse
## 按谱面时间把恋爱公园铺到世界上：草地、坑、矮丛、花门、平台。
## 横坐标来自 GameClock 的音符时刻，不是手摆关卡。

const Layout = preload("res://scripts/gameplay/TrackLayout.gd")
const Palette = preload("res://scripts/ui/ArtPalette.gd")
const HEART := preload("res://assets/characters/vfx_heart.png")

const AHEAD_PX := 1100.0
const BUSH_W := 78.0
const ARCH_W := 96.0

var _player: RunnerController
var _judge: Judge
var _hazards: Array = []
var _checkpoints: Array[Vector2] = []
var _pits: Array = []
var _built: bool = false
var _decor: Node2D
var _ground: Node2D
var _hazards_root: Node2D
var _markers: Node2D


func _ready() -> void:
	_decor = _ensure_bucket("Decor", 0)
	_ground = _ensure_bucket("Ground", 1)
	_hazards_root = _ensure_bucket("Hazards", 2)
	_markers = _ensure_bucket("Markers", 3)


func build_from_chart(player: RunnerController, judge: Judge) -> void:
	_player = player
	_judge = judge
	_built = true
	_hazards.clear()
	_checkpoints.clear()
	_pits.clear()
	for bucket in [_decor, _ground, _hazards_root, _markers]:
		if bucket:
			for child in bucket.get_children():
				child.free()
	_collect_pits()
	_build_ground()
	_build_decor()
	_collect_hazards()
	_build_checkpoints()
	_apply_camera_limits()
	if _player and not _player.respawned.is_connected(_on_respawned):
		_player.respawned.connect(_on_respawned)


func hazard_total() -> int:
	return _hazards.size()


func spawned_count() -> int:
	var n := 0
	for h in _hazards:
		if h.get("spawned", false):
			n += 1
	return n


func checkpoint_count() -> int:
	return _checkpoints.size()


func ground_body_count() -> int:
	if _ground == null:
		return 0
	return _ground.get_child_count()


func current_checkpoint(player_x: float) -> Vector2:
	var best := Vector2(Layout.START_X, Layout.stand_y())
	for spot in _checkpoints:
		if spot.x <= player_x + 6.0:
			best = spot
	return best


func _process(_delta: float) -> void:
	if not _built or not GameClock.is_playing:
		return
	var px := _player.position.x if _player else Layout.START_X
	_spawn_due(GameClock.song_time_sec, px)


func _physics_process(_delta: float) -> void:
	if not _built or _player == null or not GameClock.is_playing:
		return
	if not GameClock.is_soft_frozen() and not _player.is_fallen():
		_grade_passes()
	_skate_pit_recovery()


func _spawn_due(song_t: float, player_x: float) -> void:
	var lead := float(ChartLoader.chart.get("approachSec", 4.5))
	for h in _hazards:
		if h.get("spawned", false):
			continue
		var t := float(h["t"])
		var left := float(h["left"])
		if song_t + lead >= t or player_x + AHEAD_PX >= left:
			_spawn_hazard(h)


func _grade_passes() -> void:
	var px := _player.position.x
	var feet := Layout.feet_y(_player.position.y)
	var song_t := GameClock.song_time_sec
	for h in _hazards:
		if h.get("cleared", false) or not h.get("spawned", false):
			continue
		var left := float(h["left"])
		var right := float(h["right"])
		var top := float(h["top"])
		if px < left - 24.0:
			h["armed"] = false
			h["center_t"] = -1.0
			continue
		var center := (left + right) * 0.5
		var overlapping := px + 28.0 >= left and px - 28.0 <= right
		var kind := str(h["type"])
		match kind:
			"low":
				if overlapping and (not _player.is_grounded() or feet < top + 8.0):
					h["armed"] = true
				if overlapping and px >= center and h.get("armed", false) and float(h.get("center_t", -1.0)) < 0.0:
					h["center_t"] = song_t
			"high":
				if overlapping and _player.is_sliding_now():
					h["armed"] = true
				if overlapping and px >= center and h.get("armed", false) and float(h.get("center_t", -1.0)) < 0.0:
					h["center_t"] = song_t
			"pit":
				if px >= center and feet < Layout.KILL_Y - 80.0 and float(h.get("center_t", -1.0)) < 0.0:
					h["center_t"] = song_t
					h["armed"] = true
			"platform":
				if overlapping and _player.is_grounded() and absf(feet - top) <= 20.0:
					h["armed"] = true
					if float(h.get("center_t", -1.0)) < 0.0:
						h["center_t"] = song_t
		if h.get("cleared", false) or not h.get("armed", false):
			continue
		var passed := false
		if kind == "pit":
			passed = px > right + 16.0 and _player.is_grounded() and feet < Layout.GROUND_Y + 8.0
		elif kind == "platform":
			passed = true
		else:
			passed = px > right + 10.0
		if passed:
			h["cleared"] = true
			var when := float(h.get("center_t", song_t))
			if when < 0.0:
				when = song_t
			if _judge:
				_judge.submit_clear(int(h["index"]), when)


## 试玩锁在歌曲时间上。掉坑重生后如果这一拍还在缺口里，先贴着地面跟着歌滑过去，
## 免得同一拍把命扣光，也免得为了落地而把人拉回检查点、和打点对不齐。
func _skate_pit_recovery() -> void:
	if _player == null or not _player.clock_locked:
		return
	if _player.recovery_left() <= 0.0:
		return
	if GameClock.is_soft_frozen() or _player.is_fallen():
		return
	if not _near_pit(_player.position.x, 6.0):
		return
	_player.position.y = Layout.stand_y()
	_player.velocity.y = 0.0
	_player.keep_recovery(0.25)


func _on_respawned() -> void:
	if _player == null:
		return
	var px := _player.position.x
	for h in _hazards:
		if h.get("cleared", false):
			continue
		if px < float(h["right"]) + 8.0:
			h["armed"] = false
			h["center_t"] = -1.0


func _collect_pits() -> void:
	for i in ChartLoader.notes.size():
		var n: Dictionary = ChartLoader.notes[i]
		if ChartLoader.canonical_type(str(n.get("type", ""))) != "pit":
			continue
		var center := Layout.x_at_time(float(n.get("t", 0.0)))
		var width := float(n.get("width", 128.0))
		width = clampf(width, 48.0, 420.0)
		_pits.append({"left": center - width * 0.5, "right": center + width * 0.5})
	_pits.sort_custom(func(a, b): return float(a["left"]) < float(b["left"]))


func _build_ground() -> void:
	var duration := float(ChartLoader.chart.get("durationSec", 60.0))
	var cursor := Layout.START_X - 720.0
	var end_x := Layout.x_at_time(duration) + 900.0
	for pit in _pits:
		var left := float(pit["left"])
		var right := float(pit["right"])
		if left > cursor + 4.0:
			_add_ground(cursor, left)
		_add_pond(left, right)
		cursor = right
	if end_x > cursor + 4.0:
		_add_ground(cursor, end_x)


func _add_ground(x0: float, x1: float) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	var rect := Rect2(x0, Layout.GROUND_Y, x1 - x0, 96.0)
	body.add_child(_collision(rect))
	body.add_child(_rect_poly(rect, Color("#E7CDB4")))
	var path := Rect2(x0, Layout.GROUND_Y, x1 - x0, 36.0)
	body.add_child(_rect_poly(path, Palette.LANE))
	var grass := Rect2(x0, Layout.GROUND_Y - 12.0, x1 - x0, 16.0)
	body.add_child(_rect_poly(grass, Color("#B7D39A")))
	var blush := Rect2(x0, Layout.GROUND_Y + 28.0, x1 - x0, 4.0)
	body.add_child(_rect_poly(blush, Palette.BLUSH))
	_ground.add_child(body)


func _add_pond(x0: float, x1: float) -> void:
	var pond := _rect_poly(Rect2(x0 - 6.0, Layout.GROUND_Y + 8.0, (x1 - x0) + 12.0, 150.0), Color("#F3B6C8"))
	_decor.add_child(pond)
	var shine := _rect_poly(Rect2(x0 + 10.0, Layout.GROUND_Y + 28.0, maxf(12.0, (x1 - x0) * 0.35), 6.0), Color("#FFE3EE"))
	_decor.add_child(shine)


func _build_decor() -> void:
	var duration := float(ChartLoader.chart.get("durationSec", 60.0))
	var x := Layout.START_X - 360.0
	var end_x := Layout.x_at_time(duration) + 400.0
	var hill_i := 0
	while x < end_x:
		var hill := _circle(Vector2(x, Layout.GROUND_Y - 20.0), 90.0 + float(hill_i % 3) * 18.0, Color("#F7D3C4"), 14)
		hill.z_index = -1
		_decor.add_child(hill)
		x += 460.0
		hill_i += 1
	var t := 0.5
	while t < duration:
		var fx := Layout.x_at_time(t)
		if not _near_pit(fx, 36.0) and not _near_hazard_x(fx, 80.0):
			_add_flower(fx, (int(t * 2.0) % 2) == 0)
		t += 1.0
	_add_gate_banner()


func _add_gate_banner() -> void:
	var gate_x := Layout.START_X - 130.0
	var post_h := 70.0
	for side in [-1.0, 1.0]:
		var post := _rect_poly(Rect2(gate_x + side * 36.0 - 4.0, Layout.GROUND_Y - post_h, 8.0, post_h), Palette.BUDDY)
		_decor.add_child(post)
	var beam := _rect_poly(Rect2(gate_x - 44.0, Layout.GROUND_Y - post_h - 8.0, 88.0, 12.0), Palette.KISS)
	_decor.add_child(beam)
	var heart := Sprite2D.new()
	heart.texture = HEART
	heart.position = Vector2(gate_x, Layout.GROUND_Y - post_h - 22.0)
	heart.scale = Vector2(0.42, 0.42)
	_decor.add_child(heart)


func _add_flower(x: float, rose: bool) -> void:
	var stem := _rect_poly(Rect2(x - 2.0, Layout.GROUND_Y - 22.0, 4.0, 22.0), Color("#7DAA6A"))
	_decor.add_child(stem)
	var color := Palette.KISS if rose else Palette.BLUSH
	_decor.add_child(_circle(Vector2(x, Layout.GROUND_Y - 26.0), 7.0, color, 8))


func _collect_hazards() -> void:
	for i in ChartLoader.notes.size():
		var n: Dictionary = ChartLoader.notes[i]
		var kind := ChartLoader.canonical_type(str(n.get("type", "")))
		if kind in ["buddy", "checkpoint"]:
			continue
		var t := float(n.get("t", 0.0))
		var center := Layout.x_at_time(t)
		var left := center
		var right := center
		var top := Layout.GROUND_Y
		var bottom := Layout.GROUND_Y
		match kind:
			"low":
				left = center - BUSH_W * 0.5
				right = center + BUSH_W * 0.5
				top = Layout.GROUND_Y - Layout.BUSH_HEIGHT
				bottom = Layout.GROUND_Y
			"high":
				left = center - ARCH_W * 0.5
				right = center + ARCH_W * 0.5
				top = Layout.GROUND_Y - Layout.ARCH_RISE
				bottom = Layout.GROUND_Y - Layout.ARCH_CLEARANCE
			"pit":
				var width := clampf(float(n.get("width", 128.0)), 48.0, 420.0)
				left = center - width * 0.5
				right = center + width * 0.5
				top = Layout.GROUND_Y
				bottom = Layout.KILL_Y
			"platform":
				var width := float(n.get("width", 0.0))
				if width <= 1.0:
					width = float(n.get("duration", 0.7)) * Layout.px_per_sec()
				width = clampf(width, 80.0, 520.0)
				var height := clampf(float(n.get("height", 70.0)), 36.0, 120.0)
				left = center - 30.0
				right = left + width
				top = Layout.GROUND_Y - height
				bottom = top + 18.0
			_:
				continue
		_hazards.append({
			"index": i,
			"type": kind,
			"t": t,
			"left": left,
			"right": right,
			"top": top,
			"bottom": bottom,
			"spawned": false,
			"cleared": false,
			"armed": false,
			"center_t": -1.0,
			"node": null,
		})


func _spawn_hazard(h: Dictionary) -> void:
	h["spawned"] = true
	var kind := str(h["type"])
	if kind == "pit":
		return
	var left := float(h["left"])
	var right := float(h["right"])
	var top := float(h["top"])
	var bottom := float(h["bottom"])
	var body := StaticBody2D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	var rect := Rect2(left, top, right - left, bottom - top)
	body.add_child(_collision(rect))
	match kind:
		"low":
			body.add_child(_circle(Vector2((left + right) * 0.5, bottom - 16.0), 28.0, Color("#3EAA62"), 12))
			body.add_child(_circle(Vector2(left + 22.0, bottom - 10.0), 18.0, Palette.JUMP, 10))
			body.add_child(_circle(Vector2(right - 20.0, bottom - 12.0), 16.0, Color("#8FD99A"), 10))
			body.add_child(_circle(Vector2((left + right) * 0.5, top + 10.0), 7.0, Palette.KISS, 8))
		"high":
			body.add_child(_rect_poly(rect, Color("#F7C3D2")))
			var beam := Rect2(left - 6.0, bottom - 16.0, (right - left) + 12.0, 16.0)
			body.add_child(_rect_poly(beam, Palette.SLIDE))
			var heart := Sprite2D.new()
			heart.texture = HEART
			heart.position = Vector2((left + right) * 0.5, top + 28.0)
			heart.scale = Vector2(0.35, 0.35)
			body.add_child(heart)
		"platform":
			body.add_child(_rect_poly(rect, Color("#E7B7C8")))
			body.add_child(_rect_poly(Rect2(left, top, right - left, 6.0), Palette.HOLD))
			var heart := Sprite2D.new()
			heart.texture = HEART
			heart.position = Vector2((left + right) * 0.5, top - 10.0)
			heart.scale = Vector2(0.28, 0.28)
			body.add_child(heart)
		_:
			body.add_child(_rect_poly(rect, Palette.BLOCK))
	_hazards_root.add_child(body)
	h["node"] = body


func _build_checkpoints() -> void:
	_checkpoints.append(Vector2(Layout.START_X, Layout.stand_y()))
	for pit in _pits:
		var before := float(pit["left"]) - 110.0
		var after := float(pit["right"]) + 80.0
		_checkpoints.append(Vector2(before, Layout.stand_y()))
		_checkpoints.append(Vector2(after, Layout.stand_y()))
	for i in ChartLoader.notes.size():
		var n: Dictionary = ChartLoader.notes[i]
		if ChartLoader.canonical_type(str(n.get("type", ""))) != "buddy":
			continue
		var x := Layout.x_at_time(float(n.get("t", 0.0))) - 40.0
		if not _near_pit(x, 20.0):
			_checkpoints.append(Vector2(x, Layout.stand_y()))
	_checkpoints.sort_custom(func(a, b): return a.x < b.x)
	var kept: Array[Vector2] = []
	var last_x := -100000.0
	for spot in _checkpoints:
		if spot.x - last_x < 40.0:
			continue
		if _near_pit(spot.x, 24.0):
			continue
		kept.append(spot)
		last_x = spot.x
		_add_checkpoint_marker(spot)
	_checkpoints = kept
	if _checkpoints.is_empty():
		_checkpoints.append(Vector2(Layout.START_X, Layout.stand_y()))


func _add_checkpoint_marker(spot: Vector2) -> void:
	var pole := _rect_poly(Rect2(spot.x - 3.0, Layout.GROUND_Y - 46.0, 6.0, 46.0), Palette.BUDDY)
	_markers.add_child(pole)
	var heart := Sprite2D.new()
	heart.texture = HEART
	heart.position = Vector2(spot.x, Layout.GROUND_Y - 58.0)
	heart.scale = Vector2(0.22, 0.22)
	_markers.add_child(heart)


func _apply_camera_limits() -> void:
	var cam := get_node_or_null("../Player/Camera2D") as Camera2D
	if cam == null:
		return
	var duration := float(ChartLoader.chart.get("durationSec", 60.0))
	cam.limit_left = -180
	cam.limit_top = -160
	cam.limit_bottom = 540
	cam.limit_right = int(Layout.x_at_time(duration) + 640.0)


func _near_pit(x: float, pad: float) -> bool:
	for pit in _pits:
		if x >= float(pit["left"]) - pad and x <= float(pit["right"]) + pad:
			return true
	return false


func _near_hazard_x(x: float, pad: float) -> bool:
	for i in ChartLoader.notes.size():
		var n: Dictionary = ChartLoader.notes[i]
		var kind := ChartLoader.canonical_type(str(n.get("type", "")))
		if kind in ["buddy", "checkpoint"]:
			continue
		if absf(Layout.x_at_time(float(n.get("t", 0.0))) - x) <= pad:
			return true
	return false


func _ensure_bucket(node_name: String, z: int) -> Node2D:
	var found := get_node_or_null(node_name) as Node2D
	if found:
		found.z_index = z
		return found
	var bucket := Node2D.new()
	bucket.name = node_name
	bucket.z_index = z
	add_child(bucket)
	return bucket


func _collision(rect: Rect2) -> CollisionShape2D:
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	col.shape = shape
	col.position = rect.position + rect.size * 0.5
	return col


func _rect_poly(rect: Rect2, color: Color) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.color = color
	var p := rect.position
	var s := rect.size
	poly.polygon = PackedVector2Array([
		p,
		p + Vector2(s.x, 0.0),
		p + s,
		p + Vector2(0.0, s.y),
	])
	return poly


func _circle(center: Vector2, radius: float, color: Color, n: int) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.color = color
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	poly.polygon = pts
	return poly
