extends Control
## 听歌打点。播放音频，按键把公园音符写到时间轴上，导出 ChartLoader 能读的 JSON。
## 不改游戏键位。试玩只武装一次预览谱，标题里的「开始游戏」仍进 song_01。
## 试玩里一二的横坐标跟歌曲走，点在时刻 T 的音符会在这一拍落到她脚下。

const DraftLib = preload("res://scripts/tools/ChartDraft.gd")
const TimelineLib = preload("res://scripts/tools/ChartTimeline.gd")
const WavLib = preload("res://scripts/audio/WavStream.gd")

const KEYS_PATH := "user://chart_tap.cfg"
const PREVIEW_PATH := "user://charts/preview.json"
const PEAK_BUCKETS := 1024

const HELP_TEXT := "空格 播放/暂停    1 矮丛  2 花门  3 坑  4 平台  5 布布（点下方按钮再按键可改）\nZ 撤销    X 删除播放头附近    Tab 改类型    [ ] 调宽度    ← → 移动    Shift+← → 微调选中音符\n滚轮缩放时间轴。点击空白跳转，点击音符选中。偏移 ms 写入谱面 offsetMs，不改变你点下去的时刻，平时保持 0。试玩时一二跟着歌自动跑，跳和滑铲仍要自己按。"

var draft: ChartDraft
var last_error := ""

var _player: AudioStreamPlayer
var _timeline: Control
var _title_edit: LineEdit
var _id_edit: LineEdit
var _bpm: SpinBox
var _offset: SpinBox
var _snap: CheckBox
var _div: OptionButton
var _play_button: Button
var _scrub: HSlider
var _time_label: Label
var _width: SpinBox
var _height: SpinBox
var _select_label: Label
var _count_label: Label
var _status: Label
var _key_buttons: Dictionary = {}
var _audio_dialog: FileDialog
var _open_dialog: FileDialog
var _save_dialog: FileDialog

var _keys: Dictionary = {}
var _capture_type := ""
var _playhead := 0.0
var _want_pause := true
var _selected := -1
var _view_start := 0.0
var _view_len := 60.0
var _peaks := PackedFloat32Array()
var _filling := false
var _syncing_slider := false
var _size_undo_open := false


func _ready() -> void:
	draft = DraftLib.new()
	_build_ui()
	_load_keys()
	_push_meta_fields()
	_refresh_key_buttons()
	_refresh_selection()
	_sync_time_label()
	_sync_timeline()
	_status_text("加载一首歌，跟着点。WAV 会画出波形。")


func load_audio_path(path: String) -> bool:
	var stream := WavLib.load_file(path)
	if stream == null:
		_status_text("打不开音频（需要 ogg / wav / mp3）：%s" % path.get_file())
		return false
	var length := stream.get_length()
	if length <= 0.05:
		_status_text("音频长度无效")
		return false
	_player.stream = stream
	_player.stop()
	_want_pause = true
	_play_button.text = "播放"
	draft.audio = _portable_path(path)
	draft.duration_sec = length
	if _title_edit.text.strip_edges().is_empty() or _title_edit.text == "未命名":
		_filling = true
		_title_edit.text = path.get_file().get_basename()
		_filling = false
		draft.title = _title_edit.text
	if _id_edit.text.strip_edges().is_empty() or _id_edit.text == "custom_01":
		_filling = true
		_id_edit.text = _sanitize_id(path.get_file().get_basename())
		_filling = false
		draft.song_id = _id_edit.text
	_peaks = _peaks_from_wav(stream)
	_playhead = 0.0
	_view_start = 0.0
	_view_len = length
	_selected = -1
	_scrub.max_value = length
	seek_seconds(0.0)
	var wave := "，已画波形" if not _peaks.is_empty() else "（这种格式不画波形，拍线还在）"
	_status_text("已加载 %s，%.1f 秒%s" % [path.get_file(), length, wave])
	_refresh_selection()
	return true


func load_chart_path(path: String) -> bool:
	var loaded: Dictionary = DraftLib.load_path(path)
	if not bool(loaded.get("ok", false)):
		last_error = str(loaded.get("error", "无法加载谱面"))
		_status_text(last_error)
		return false
	draft = loaded["draft"]
	_selected = -1
	_size_undo_open = false
	_push_meta_fields()
	_view_start = 0.0
	_view_len = maxf(draft.duration_sec, 2.0)
	_playhead = 0.0
	_scrub.max_value = maxf(draft.duration_sec, 0.1)
	if not draft.audio.is_empty() and FileAccess.file_exists(draft.audio):
		var audio_ok := load_audio_path(draft.audio)
		# 音频加载可能改曲名；谱面里的名字为准。
		_push_meta_fields()
		if not audio_ok:
			_status_text("谱面已打开，但音频没读出来：%s" % draft.audio)
			_refresh_selection()
			_sync_timeline()
			return true
	else:
		_player.stream = null
		_peaks = PackedFloat32Array()
		seek_seconds(0.0)
	_status_text("已加载谱面 %s，%d 个音符" % [path.get_file(), draft.notes.size()])
	_refresh_selection()
	_sync_timeline()
	return true


func export_path(path: String) -> bool:
	_pull_meta()
	var err: String = draft.save_to(path)
	last_error = err
	if not err.is_empty():
		_status_text(err)
		return false
	_status_text("已导出 %s（%d 个音符）" % [path, draft.notes.size()])
	return true


func seek_seconds(t: float) -> void:
	_playhead = clampf(t, 0.0, maxf(draft.duration_sec, 0.0))
	if _player.stream != null:
		if _player.playing:
			_player.seek(_playhead)
		else:
			_player.play(_playhead)
		_player.stream_paused = _want_pause
	_sync_slider()
	_sync_time_label()
	_sync_timeline()


func toggle_playback() -> void:
	if _player.stream == null:
		_status_text("先加载音频")
		return
	if _player.playing and not _player.stream_paused:
		_playhead = _heard_time()
		_want_pause = true
		_player.stream_paused = true
		_play_button.text = "播放"
	else:
		_want_pause = false
		if not _player.playing:
			_player.play(_playhead)
		_player.stream_paused = false
		_play_button.text = "暂停"
	_sync_time_label()


func place_type(ntype: String) -> String:
	_pull_meta()
	var err: String = draft.place(_heard_time(), ntype, _snap_step())
	if not err.is_empty():
		_status_text(err)
		return err
	var kind := ChartLoader.canonical_type(ntype)
	_selected = int(draft.last_index)
	_status_text("记下 %s  @ %.3f" % [DraftLib.label_of(kind), _selected_time()])
	_refresh_selection()
	_sync_timeline()
	return ""


func undo_last() -> bool:
	if not draft.undo():
		_status_text("没有可撤销的操作")
		return false
	_selected = -1
	_size_undo_open = false
	_status_text("已撤销")
	_refresh_selection()
	_sync_timeline()
	return true


func delete_near_playhead() -> bool:
	var window := _edit_window()
	var index: int = draft.nearest_index(_heard_time(), window)
	if index < 0:
		_status_text("播放头附近没有音符")
		return false
	var err: String = draft.delete_at(index)
	if not err.is_empty():
		_status_text(err)
		return false
	if _selected == index or _selected >= draft.notes.size():
		_selected = -1
	_status_text("已删除播放头附近的音符")
	_refresh_selection()
	_sync_timeline()
	return true


func assign_key(ntype: String, code: int) -> String:
	if ntype not in DraftLib.NOTE_TYPES:
		return "未知音符"
	if _reserved(code):
		var err := "这个键留给播放和编辑"
		_status_text(err)
		return err
	var drop: Array = []
	for existing in _keys.keys():
		if int(existing) == code or str(_keys[existing]) == ntype:
			drop.append(existing)
	for existing in drop:
		_keys.erase(existing)
	_keys[code] = ntype
	_save_keys()
	_refresh_key_buttons()
	_status_text("%s 改为 %s" % [DraftLib.label_of(ntype), OS.get_keycode_string(code)])
	return ""


func peak_count() -> int:
	return _peaks.size()


func _unhandled_input(event: InputEvent) -> void:
	if _dialog_open():
		return
	if _text_focused():
		if _capture_type != "":
			_capture_type = ""
			_refresh_key_buttons()
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo:
			_handle_key(key)


func _handle_key(key: InputEventKey) -> void:
	var code := int(key.physical_keycode)
	if _capture_type != "":
		get_viewport().set_input_as_handled()
		if code == KEY_ESCAPE:
			_capture_type = ""
			_refresh_key_buttons()
			_status_text("取消改键")
			return
		var err := assign_key(_capture_type, code)
		if err.is_empty():
			_capture_type = ""
		return
	if code == KEY_SPACE:
		toggle_playback()
		get_viewport().set_input_as_handled()
		return
	if code == KEY_Z and (key.ctrl_pressed or key.meta_pressed):
		undo_last()
		get_viewport().set_input_as_handled()
		return
	if _keys.has(code):
		place_type(str(_keys[code]))
		get_viewport().set_input_as_handled()
		return
	match code:
		KEY_Z:
			undo_last()
			get_viewport().set_input_as_handled()
		KEY_X, KEY_DELETE, KEY_BACKSPACE:
			delete_near_playhead()
			get_viewport().set_input_as_handled()
		KEY_TAB:
			_cycle_selected()
			get_viewport().set_input_as_handled()
		KEY_LEFT:
			if key.shift_pressed:
				_nudge_selected(-0.01)
			else:
				seek_seconds(_playhead - _scrub_step())
			get_viewport().set_input_as_handled()
		KEY_RIGHT:
			if key.shift_pressed:
				_nudge_selected(0.01)
			else:
				seek_seconds(_playhead + _scrub_step())
			get_viewport().set_input_as_handled()
		KEY_BRACKETLEFT:
			_bump_width(-8)
			get_viewport().set_input_as_handled()
		KEY_BRACKETRIGHT:
			_bump_width(8)
			get_viewport().set_input_as_handled()
		KEY_HOME:
			seek_seconds(0.0)
			get_viewport().set_input_as_handled()
		KEY_END:
			seek_seconds(draft.duration_sec)
			get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _player.stream == null:
		return
	if not _want_pause and _player.playing and not _player.stream_paused:
		_playhead = _heard_time()
		_follow_playhead()
		_sync_slider()
		_sync_time_label()
		_sync_timeline()
	elif not _want_pause and not _player.playing:
		_want_pause = true
		_playhead = draft.duration_sec
		_play_button.text = "播放"
		_sync_slider()
		_sync_time_label()
		_sync_timeline()


func _exit_tree() -> void:
	if _player:
		_player.stop()


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right"]:
		margin.add_theme_constant_override(side, 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)
	var title := Label.new()
	title.text = "听歌打点"
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var back := _button("返回标题")
	back.pressed.connect(_on_back)
	header.add_child(back)

	var meta := HBoxContainer.new()
	meta.add_theme_constant_override("separation", 8)
	root.add_child(meta)
	meta.add_child(_label("歌名"))
	_title_edit = LineEdit.new()
	_title_edit.custom_minimum_size = Vector2(180, 0)
	_title_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_edit.text_changed.connect(func(_t: String) -> void:
		if not _filling:
			draft.title = _title_edit.text
	)
	meta.add_child(_title_edit)
	meta.add_child(_label("ID"))
	_id_edit = LineEdit.new()
	_id_edit.custom_minimum_size = Vector2(120, 0)
	meta.add_child(_id_edit)
	meta.add_child(_label("BPM"))
	_bpm = _spin(40, 240, 1)
	_bpm.value_changed.connect(func(v: float) -> void:
		if not _filling:
			draft.bpm = v
			_sync_timeline()
	)
	meta.add_child(_bpm)
	meta.add_child(_label("偏移 ms"))
	_offset = _spin(-500, 500, 1)
	_offset.value_changed.connect(func(v: float) -> void:
		if not _filling:
			draft.offset_ms = int(v)
	)
	meta.add_child(_offset)
	_snap = CheckBox.new()
	_snap.text = "吸附"
	_snap.focus_mode = Control.FOCUS_NONE
	meta.add_child(_snap)
	_div = OptionButton.new()
	_div.focus_mode = Control.FOCUS_NONE
	_div.add_item("1 拍", 1)
	_div.add_item("1/2", 2)
	_div.add_item("1/4", 4)
	_div.selected = 2
	meta.add_child(_div)

	var files := HBoxContainer.new()
	files.add_theme_constant_override("separation", 8)
	root.add_child(files)
	var load_audio := _button("加载音频")
	load_audio.pressed.connect(func() -> void: _audio_dialog.popup_centered(Vector2i(900, 560)))
	files.add_child(load_audio)
	var load_chart := _button("加载谱面")
	load_chart.pressed.connect(func() -> void: _open_dialog.popup_centered(Vector2i(900, 560)))
	files.add_child(load_chart)
	var export_button := _button("导出 JSON")
	export_button.pressed.connect(_on_export)
	files.add_child(export_button)
	var preview := _button("试玩")
	preview.tooltip_text = "一二跟着歌曲自动往右跑，跳和滑铲仍要自己按。开始游戏也是这样，打点才对得上。"
	preview.pressed.connect(_on_preview)
	files.add_child(preview)

	_timeline = TimelineLib.new()
	_timeline.custom_minimum_size = Vector2(0, 220)
	_timeline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_timeline.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_timeline.mouse_filter = Control.MOUSE_FILTER_STOP
	_timeline.seek_requested.connect(seek_seconds)
	_timeline.note_picked.connect(_on_note_picked)
	_timeline.view_changed.connect(_on_view_changed)
	root.add_child(_timeline)

	var transport := HBoxContainer.new()
	transport.add_theme_constant_override("separation", 8)
	root.add_child(transport)
	_play_button = _button("播放")
	_play_button.pressed.connect(toggle_playback)
	transport.add_child(_play_button)
	_scrub = HSlider.new()
	_scrub.min_value = 0.0
	_scrub.max_value = draft.duration_sec
	_scrub.step = 0.001
	_scrub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scrub.value_changed.connect(_on_scrub)
	transport.add_child(_scrub)
	_time_label = Label.new()
	_time_label.custom_minimum_size = Vector2(150, 0)
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	transport.add_child(_time_label)

	var edit := HBoxContainer.new()
	edit.add_theme_constant_override("separation", 8)
	root.add_child(edit)
	var undo_button := _button("撤销")
	undo_button.pressed.connect(undo_last)
	edit.add_child(undo_button)
	var delete_button := _button("删除附近")
	delete_button.pressed.connect(delete_near_playhead)
	edit.add_child(delete_button)
	var cycle_button := _button("改类型")
	cycle_button.pressed.connect(_cycle_selected)
	edit.add_child(cycle_button)
	edit.add_child(_label("宽"))
	_width = _spin(48, 520, 1)
	_width.editable = false
	_width.focus_exited.connect(func() -> void: _size_undo_open = false)
	_width.value_changed.connect(_on_width)
	edit.add_child(_width)
	edit.add_child(_label("高"))
	_height = _spin(36, 120, 1)
	_height.editable = false
	_height.focus_exited.connect(func() -> void: _size_undo_open = false)
	_height.value_changed.connect(_on_height)
	edit.add_child(_height)
	_select_label = Label.new()
	_select_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.add_child(_select_label)
	_count_label = Label.new()
	edit.add_child(_count_label)

	var keys := HBoxContainer.new()
	keys.add_theme_constant_override("separation", 8)
	root.add_child(keys)
	for ntype in DraftLib.NOTE_TYPES:
		var button := _button(DraftLib.label_of(ntype))
		button.pressed.connect(_begin_capture.bind(ntype))
		_key_buttons[ntype] = button
		keys.add_child(button)
	var remap_hint := _label("点按钮后按新键")
	keys.add_child(remap_hint)

	var help := Label.new()
	help.text = HELP_TEXT
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_color_override("font_color", Color("#8A7F72"))
	root.add_child(help)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_status)

	_player = AudioStreamPlayer.new()
	_player.name = "ChartPlayer"
	add_child(_player)

	var audio_dir := ProjectSettings.globalize_path("res://assets/audio/bgm")
	var chart_dir := ProjectSettings.globalize_path("res://charts")
	_audio_dialog = _make_dialog("加载音频", FileDialog.FILE_MODE_OPEN_FILE, audio_dir)
	_audio_dialog.filters = PackedStringArray(["*.ogg,*.wav,*.mp3 ; 音频"])
	_audio_dialog.file_selected.connect(load_audio_path)
	_open_dialog = _make_dialog("加载谱面", FileDialog.FILE_MODE_OPEN_FILE, chart_dir)
	_open_dialog.filters = PackedStringArray(["*.json ; 谱面"])
	_open_dialog.file_selected.connect(load_chart_path)
	_save_dialog = _make_dialog("导出谱面", FileDialog.FILE_MODE_SAVE_FILE, chart_dir)
	_save_dialog.filters = PackedStringArray(["*.json ; 谱面"])
	_save_dialog.file_selected.connect(export_path)


func _make_dialog(title: String, mode: FileDialog.FileMode, directory: String) -> FileDialog:
	var dialog := FileDialog.new()
	dialog.title = title
	dialog.file_mode = mode
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.current_dir = directory
	add_child(dialog)
	return dialog


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	return button


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label


func _spin(min_value: float, max_value: float, step: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.step = step
	spin.custom_minimum_size = Vector2(88, 0)
	return spin


func _begin_capture(ntype: String) -> void:
	var owner := get_viewport().gui_get_focus_owner()
	if owner:
		owner.release_focus()
	_capture_type = ntype
	_refresh_key_buttons()
	_status_text("按下 %s 的新键，Esc 取消" % DraftLib.label_of(ntype))


func _on_back() -> void:
	_player.stop()
	get_tree().change_scene_to_file("res://scenes/title/Title.tscn")


func _on_export() -> void:
	_pull_meta()
	_save_dialog.current_file = "%s.json" % draft.song_id
	_save_dialog.popup_centered(Vector2i(900, 560))


func _on_preview() -> void:
	if not export_path(PREVIEW_PATH):
		return
	_player.stop()
	ChartLoader.arm_preview(PREVIEW_PATH)
	get_tree().change_scene_to_file("res://scenes/game/Game.tscn")


func _on_scrub(value: float) -> void:
	if _syncing_slider:
		return
	seek_seconds(value)


func _on_view_changed(start: float, length: float) -> void:
	_view_start = start
	_view_len = length


func _on_note_picked(index: int) -> void:
	_selected = index
	_refresh_selection()
	_sync_timeline()


func _on_width(value: float) -> void:
	if _filling:
		return
	var index := _size_index()
	if index < 0:
		return
	if not _size_undo_open:
		draft.checkpoint()
		_size_undo_open = true
	draft.set_width(index, int(round(value)))
	_sync_timeline()


func _on_height(value: float) -> void:
	if _filling:
		return
	var index := _selected if _selected_is("platform") else -1
	if index < 0:
		return
	if not _size_undo_open:
		draft.checkpoint()
		_size_undo_open = true
	draft.set_height(index, int(round(value)))
	_sync_timeline()


func _cycle_selected() -> void:
	var index := _selected if _selected >= 0 else draft.nearest_index(_heard_time(), _edit_window())
	var err: String = draft.cycle_type(index)
	if not err.is_empty():
		_status_text(err)
		return
	_selected = index
	_status_text("类型改为 %s" % DraftLib.label_of(str(draft.notes[index].get("type", ""))))
	_refresh_selection()
	_sync_timeline()


func _nudge_selected(delta: float) -> void:
	var index := _selected if _selected >= 0 else draft.nearest_index(_heard_time(), _edit_window())
	var err: String = draft.nudge(index, delta)
	if not err.is_empty():
		_status_text(err)
		return
	_selected = int(draft.last_index)
	_refresh_selection()
	_sync_timeline()


func _bump_width(delta: int) -> void:
	var index := _size_index()
	if index < 0:
		_status_text("播放头附近没有坑或平台")
		return
	var note: Dictionary = draft.notes[index]
	var width := int(note.get("width", DraftLib.DEFAULT_PIT_WIDTH))
	draft.checkpoint()
	draft.set_width(index, width + delta)
	_selected = index
	_status_text("宽度 %d" % int(draft.notes[index].get("width", 0)))
	_refresh_selection()
	_sync_timeline()


func _size_index() -> int:
	if _selected >= 0 and _selected < draft.notes.size():
		var kind := str(draft.notes[_selected].get("type", ""))
		if kind == "pit" or kind == "platform":
			return _selected
	var near: int = draft.nearest_index(_heard_time(), _edit_window())
	if near < 0:
		return -1
	var near_kind := str(draft.notes[near].get("type", ""))
	if near_kind == "pit" or near_kind == "platform":
		return near
	return -1


func _selected_is(kind: String) -> bool:
	return _selected >= 0 and _selected < draft.notes.size() and str(draft.notes[_selected].get("type", "")) == kind


func _heard_time() -> float:
	if _player.playing and not _player.stream_paused:
		var t := _player.get_playback_position() \
			+ AudioServer.get_time_since_last_mix() \
			- AudioServer.get_output_latency()
		return clampf(t, 0.0, maxf(draft.duration_sec, 0.0))
	return _playhead


func _snap_step() -> float:
	if not _snap.button_pressed:
		return 0.0
	var div := 1
	if _div.selected >= 0:
		div = maxi(int(_div.get_item_id(_div.selected)), 1)
	return (60.0 / maxf(draft.bpm, 1.0)) / float(div)


func _selected_time() -> float:
	if _selected < 0 or _selected >= draft.notes.size():
		return _heard_time()
	return float(draft.notes[_selected].get("t", 0.0))


func _edit_window() -> float:
	var step := _snap_step()
	if step > 0.0:
		return maxf(0.12, step * 0.49)
	return 0.12


func _scrub_step() -> float:
	var step := _snap_step()
	if step > 0.0:
		return step
	return 0.1


func _follow_playhead() -> void:
	var view_end := _view_start + _view_len
	if _playhead < _view_start or _playhead > view_end - _view_len * 0.08:
		_view_start = clampf(_playhead - _view_len * 0.25, 0.0, maxf(draft.duration_sec - _view_len, 0.0))


func _pull_meta() -> void:
	draft.title = _title_edit.text.strip_edges()
	if draft.title.is_empty():
		draft.title = "未命名"
		_title_edit.text = draft.title
	draft.song_id = _sanitize_id(_id_edit.text)
	_filling = true
	_id_edit.text = draft.song_id
	_filling = false
	draft.bpm = float(_bpm.value)
	draft.offset_ms = int(_offset.value)


func _push_meta_fields() -> void:
	_filling = true
	_title_edit.text = draft.title
	_id_edit.text = draft.song_id
	_bpm.value = draft.bpm
	_offset.value = draft.offset_ms
	_scrub.max_value = maxf(draft.duration_sec, 0.1)
	_filling = false


func _refresh_selection() -> void:
	_filling = true
	var has: bool = _selected >= 0 and _selected < draft.notes.size()
	if not has:
		_select_label.text = "未选中"
		_width.editable = false
		_height.editable = false
	else:
		var note: Dictionary = draft.notes[_selected]
		var kind := str(note.get("type", ""))
		_select_label.text = "%s  %s" % [_format_time(float(note.get("t", 0.0))), DraftLib.label_of(kind)]
		var sizable := kind == "pit" or kind == "platform"
		_width.editable = sizable
		_height.editable = kind == "platform"
		if sizable:
			var fallback := DraftLib.DEFAULT_PIT_WIDTH if kind == "pit" else DraftLib.DEFAULT_PLATFORM_WIDTH
			_width.value = float(note.get("width", fallback))
		if kind == "platform":
			_height.value = float(note.get("height", DraftLib.DEFAULT_PLATFORM_HEIGHT))
	_count_label.text = "%d 个音符" % draft.notes.size()
	_filling = false


func _sync_slider() -> void:
	_syncing_slider = true
	_scrub.max_value = maxf(draft.duration_sec, 0.1)
	_scrub.value = _playhead
	_syncing_slider = false


func _sync_time_label() -> void:
	_time_label.text = "%s / %s" % [_format_time(_playhead), _format_time(draft.duration_sec)]


func _sync_timeline() -> void:
	_timeline.duration = maxf(draft.duration_sec, 0.01)
	_timeline.view_start = _view_start
	_timeline.view_len = maxf(_view_len, 0.5)
	_timeline.playhead = _playhead
	_timeline.bpm = draft.bpm
	_timeline.selected = _selected
	_timeline.notes = draft.notes
	_timeline.peaks = _peaks
	_timeline.queue_redraw()


func _status_text(text: String) -> void:
	if _status:
		_status.text = text


func _refresh_key_buttons() -> void:
	for ntype in DraftLib.NOTE_TYPES:
		var button: Button = _key_buttons[ntype]
		var code := _code_for(ntype)
		var key_name := "未绑定" if code == 0 else OS.get_keycode_string(code)
		var suffix := " …" if _capture_type == ntype else "  " + key_name
		button.text = DraftLib.label_of(ntype) + suffix


func _code_for(ntype: String) -> int:
	for code in _keys.keys():
		if str(_keys[code]) == ntype:
			return int(code)
	return 0


func _load_keys() -> void:
	_keys.clear()
	var cfg := ConfigFile.new()
	if cfg.load(KEYS_PATH) != OK:
		_reset_keys()
		return
	var found := false
	for ntype in DraftLib.NOTE_TYPES:
		if not cfg.has_section_key("keys", ntype):
			continue
		var code := int(cfg.get_value("keys", ntype, 0))
		if code == 0 or _reserved(code):
			continue
		_keys[code] = ntype
		found = true
	if not found or _keys.size() < DraftLib.NOTE_TYPES.size():
		_reset_keys()


func _reset_keys() -> void:
	_keys = {
		KEY_1: "low",
		KEY_2: "high",
		KEY_3: "pit",
		KEY_4: "platform",
		KEY_5: "buddy",
	}


func _save_keys() -> void:
	var cfg := ConfigFile.new()
	for code in _keys.keys():
		cfg.set_value("keys", str(_keys[code]), int(code))
	cfg.save(KEYS_PATH)


func _reserved(code: int) -> bool:
	return code in [
		KEY_SPACE, KEY_ESCAPE, KEY_Z, KEY_X, KEY_LEFT, KEY_RIGHT, KEY_TAB,
		KEY_BRACKETLEFT, KEY_BRACKETRIGHT, KEY_BACKSPACE, KEY_DELETE, KEY_HOME, KEY_END,
	]


func _text_focused() -> bool:
	var owner := get_viewport().gui_get_focus_owner()
	return owner is LineEdit


func _dialog_open() -> bool:
	return _audio_dialog.visible or _open_dialog.visible or _save_dialog.visible


func _portable_path(path: String) -> String:
	var root := ProjectSettings.globalize_path("res://")
	if path.begins_with(root):
		return "res://" + path.trim_prefix(root)
	return path


func _sanitize_id(raw: String) -> String:
	var out := ""
	var lower := raw.strip_edges().to_lower()
	for i in lower.length():
		var ch := lower[i]
		var code := ch.unicode_at(0)
		if (code >= 48 and code <= 57) or (code >= 97 and code <= 122) or ch == "_" or ch == "-":
			out += ch
		elif ch == " " or ch == ".":
			out += "_"
	while out.contains("__"):
		out = out.replace("__", "_")
	out = out.trim_prefix("_").trim_suffix("_")
	if out.is_empty():
		return "custom_01"
	return out.substr(0, 48)


func _format_time(t: float) -> String:
	var sec := maxf(t, 0.0)
	var minutes := int(sec / 60.0)
	return "%d:%05.2f" % [minutes, sec - float(minutes * 60)]


func _peaks_from_wav(stream: AudioStream) -> PackedFloat32Array:
	var empty := PackedFloat32Array()
	if not (stream is AudioStreamWAV):
		return empty
	var wav := stream as AudioStreamWAV
	if wav.format != AudioStreamWAV.FORMAT_16_BITS or wav.data.is_empty():
		return empty
	var channels := 2 if wav.stereo else 1
	var frame_bytes := 2 * channels
	var frames := int(wav.data.size() / frame_bytes)
	if frames <= 0:
		return empty
	var buckets := mini(PEAK_BUCKETS, frames)
	var peaks := PackedFloat32Array()
	peaks.resize(buckets)
	var per := maxi(int(float(frames) / float(buckets)), 1)
	for b in buckets:
		var start := b * per
		var finish := mini(start + per, frames)
		var step := maxi(int((finish - start) / 48), 1)
		var peak := 0.0
		var i := start
		while i < finish:
			var base := i * frame_bytes
			var sample := _s16(wav.data, base)
			if channels == 2:
				sample = maxf(sample, _s16(wav.data, base + 2))
			peak = maxf(peak, sample)
			i += step
		peaks[b] = peak
	return peaks


func _s16(data: PackedByteArray, offset: int) -> float:
	if offset + 1 >= data.size():
		return 0.0
	var value := data[offset] | (data[offset + 1] << 8)
	if value >= 32768:
		value -= 65536
	return absf(float(value) / 32768.0)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and (data as Dictionary).get("type", "") == "files"


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var files: PackedStringArray = (data as Dictionary).get("files", PackedStringArray())
	if files.is_empty():
		return
	var path := str(files[0])
	var ext := path.get_extension().to_lower()
	if ext == "json":
		load_chart_path(path)
	elif ext == "wav" or ext == "ogg" or ext == "mp3":
		load_audio_path(path)
