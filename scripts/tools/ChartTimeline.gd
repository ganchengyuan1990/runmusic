extends Control
## 时间轴：波形（有 WAV 时）、拍线、音符和播放头。视图由打点场景写入。

signal seek_requested(t: float)
signal note_picked(index: int)
signal view_changed(start: float, length: float)

const Palette = preload("res://scripts/ui/ArtPalette.gd")
const Draft = preload("res://scripts/tools/ChartDraft.gd")

const COLORS := {
	"low": Palette.JUMP,
	"high": Palette.SLIDE,
	"pit": Palette.BLOCK,
	"platform": Palette.HOLD,
	"buddy": Palette.KISS,
}

var duration := 60.0
var view_start := 0.0
var view_len := 60.0
var playhead := 0.0
var bpm := 120.0
var selected := -1
var notes: Array = []
var peaks := PackedFloat32Array()

var _scrubbing := false


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_WHEEL_UP and button.pressed:
			_zoom(0.8, _time_at(button.position.x))
			accept_event()
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN and button.pressed:
			_zoom(1.25, _time_at(button.position.x))
			accept_event()
		elif button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed:
				var idx := _pick_note(button.position.x)
				if idx >= 0:
					_scrubbing = false
					note_picked.emit(idx)
				else:
					_scrubbing = true
					seek_requested.emit(_time_at(button.position.x))
			else:
				_scrubbing = false
			accept_event()
	elif event is InputEventMouseMotion and _scrubbing:
		var motion := event as InputEventMouseMotion
		seek_requested.emit(_time_at(motion.position.x))
		accept_event()


func _zoom(factor: float, anchor: float) -> void:
	var next := clampf(view_len * factor, 2.0, maxf(duration, 2.0))
	var span := maxf(view_len, 0.001)
	var ratio := clampf((anchor - view_start) / span, 0.0, 1.0)
	view_len = next
	view_start = clampf(anchor - ratio * view_len, 0.0, maxf(duration - view_len, 0.0))
	view_changed.emit(view_start, view_len)
	queue_redraw()


func _draw() -> void:
	if size.x < 2.0 or size.y < 2.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Palette.LANE)
	draw_rect(Rect2(Vector2.ZERO, size), Palette.LANE_LINE, false, 2.0)
	_draw_wave()
	_draw_beats()
	_draw_notes()
	_draw_playhead()


func _draw_wave() -> void:
	if peaks.is_empty() or duration <= 0.0:
		return
	var mid := size.y * 0.46
	var amp := size.y * 0.28
	var n := peaks.size()
	var i0 := clampi(int(view_start / duration * float(n)), 0, n - 1)
	var i1 := clampi(int((view_start + view_len) / duration * float(n)), i0 + 1, n)
	var col := Palette.MUTED
	col.a = 0.55
	for i in range(i0, i1):
		var t := float(i) / float(n) * duration
		var x := _x_of(t)
		var h := peaks[i] * amp
		draw_line(Vector2(x, mid - h), Vector2(x, mid + h), col, 1.0)


func _draw_beats() -> void:
	if bpm < 1.0 or view_len <= 0.0:
		return
	var beat := 60.0 / bpm
	if beat < 0.05:
		return
	var px_per_beat := beat / view_len * size.x
	var first_index := int(floor(view_start / beat))
	var t := float(first_index) * beat
	var font := get_theme_default_font()
	var guard := 0
	while t <= view_start + view_len + 0.0001 and guard < 8000:
		guard += 1
		var bar := first_index % 4 == 0
		var draw_this := true
		if px_per_beat < 3.0 and first_index % 16 != 0:
			draw_this = false
		elif px_per_beat < 8.0 and not bar:
			draw_this = false
		if draw_this:
			var x := _x_of(t)
			var col := Palette.INK
			col.a = 0.38 if bar else 0.14
			draw_line(Vector2(x, 0.0), Vector2(x, size.y), col, 2.0 if bar else 1.0)
			if bar and font != null and px_per_beat >= 24.0:
				draw_string(font, Vector2(x + 4.0, 18.0), str(first_index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col)
		t += beat
		first_index += 1


func _draw_notes() -> void:
	var font := get_theme_default_font()
	var last_label_x := -100.0
	for i in notes.size():
		var note: Dictionary = notes[i]
		var t := float(note.get("t", 0.0))
		if t < view_start - 0.5 or t > view_start + view_len + 0.5:
			continue
		var x := _x_of(t)
		var kind := str(note.get("type", ""))
		var col: Color = COLORS.get(kind, Palette.INK)
		var y := size.y - 36.0
		draw_rect(Rect2(x - 6.0, y, 12.0, 22.0), col)
		if i == selected:
			draw_rect(Rect2(x - 9.0, y - 3.0, 18.0, 28.0), Palette.INK, false, 2.0)
		if font != null and x - last_label_x > 36.0:
			draw_string(font, Vector2(x - 14.0, size.y - 6.0), Draft.label_of(kind), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col)
			last_label_x = x


func _draw_playhead() -> void:
	var x := _x_of(playhead)
	draw_line(Vector2(x, 0.0), Vector2(x, size.y), Palette.KISS, 2.0)
	var font := get_theme_default_font()
	if font == null:
		return
	var sec := maxf(playhead, 0.0)
	var text := "%.2f" % sec
	draw_string(font, Vector2(x + 6.0, 36.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Palette.KISS)


func _pick_note(mouse_x: float) -> int:
	var best := -1
	var best_px := 14.0
	for i in notes.size():
		var x := _x_of(float(notes[i].get("t", 0.0)))
		var d := absf(x - mouse_x)
		if d <= best_px:
			best_px = d
			best = i
	return best


func _time_at(x: float) -> float:
	if size.x <= 1.0:
		return view_start
	var t := view_start + (x / size.x) * view_len
	return clampf(t, 0.0, maxf(duration, 0.0))


func _x_of(t: float) -> float:
	if view_len <= 0.001:
		return 0.0
	return (t - view_start) / view_len * size.x
