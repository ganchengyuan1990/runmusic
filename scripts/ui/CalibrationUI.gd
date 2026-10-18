extends Control
class_name CalibrationUI
## 全局 player_offset_ms 滑条 + 简易听拍。偏移写入 Settings，立刻作用于 GameClock。

signal offset_changed(ms: float)
signal continue_pressed
signal skip_pressed

const WavLib = preload("res://scripts/audio/WavStream.gd")
const TAP_BEATS := 8
const MIN_TAPS := 3

@onready var _slider: HSlider = $VBox/OffsetSlider
@onready var _label: Label = $VBox/OffsetLabel
@onready var _tap_button: Button = $VBox/TapButton
@onready var _tap_status: Label = $VBox/TapStatus
@onready var _btn_continue: Button = $VBox/Buttons/ContinueButton
@onready var _btn_skip: Button = $VBox/Buttons/SkipButton

var _click: AudioStreamPlayer
var _listening := false
var _bpm := 120.0
var _metro_origin_usec := 0
var _metro_delay := 0.0
var _tap_errors_ms: Array[float] = []
var _saw_hardware := false


func _ready() -> void:
	_click = AudioStreamPlayer.new()
	_click.name = "Metronome"
	add_child(_click)
	if ChartLoader.chart.is_empty():
		ChartLoader.load_chart("res://charts/song_01.json")
	_bpm = float(ChartLoader.chart.get("bpm", 120.0))
	if _bpm < 40.0:
		_bpm = 120.0
	if _slider:
		_slider.min_value = -200.0
		_slider.max_value = 200.0
		_slider.step = 1.0
		_slider.value = Settings.player_offset_ms
		_slider.value_changed.connect(_on_slider_changed)
	_refresh_label()
	_set_status("点「听拍校准」，跟着嘀声按空格或再点按钮。")
	if _tap_button:
		_tap_button.pressed.connect(_on_tap_button)
	if _btn_continue:
		_btn_continue.pressed.connect(func(): continue_pressed.emit())
	if _btn_skip:
		_btn_skip.pressed.connect(func(): skip_pressed.emit())


func _exit_tree() -> void:
	_stop_metronome()


func _process(_delta: float) -> void:
	if not _listening:
		return
	var t := _metronome_time()
	if t > 0.05:
		_saw_hardware = true
	var beat := 60.0 / _bpm
	var duration := beat * float(TAP_BEATS)
	var beat_index := clampi(int(t / beat) + 1, 1, TAP_BEATS)
	_set_status("听拍中 %d/%d 拍，已点 %d 下" % [beat_index, TAP_BEATS, _tap_errors_ms.size()])
	if t >= duration + 0.35:
		_finish_taps()


func _unhandled_input(event: InputEvent) -> void:
	if not _listening:
		return
	if event.is_action_pressed("jump") or event.is_action_pressed("ui_accept"):
		_register_tap()
		get_viewport().set_input_as_handled()


func _on_slider_changed(value: float) -> void:
	Settings.set_player_offset_ms(value)
	_refresh_label()
	offset_changed.emit(value)


func _on_tap_button() -> void:
	if _listening:
		_register_tap()
	else:
		start_tap_calibration()


## 播放 8 拍嘀声。玩家点拍相对方案 B 时钟的平均误差写回 offset。
func start_tap_calibration() -> void:
	_stop_metronome()
	_tap_errors_ms.clear()
	_saw_hardware = false
	_click.stream = WavLib.make_metronome(_bpm, TAP_BEATS)
	_click.volume_db = Settings.sfx_volume_db if Settings else 0.0
	_metro_origin_usec = Time.get_ticks_usec()
	_metro_delay = AudioServer.get_time_to_next_mix() + AudioServer.get_output_latency()
	_click.play()
	_listening = true
	_set_status("听拍开始")


func _register_tap() -> void:
	if not _listening:
		return
	var t := _metronome_time()
	var beat := 60.0 / _bpm
	var index := clampi(int(round(t / beat)), 0, TAP_BEATS - 1)
	var error_ms := (t - float(index) * beat) * 1000.0
	_tap_errors_ms.append(error_ms)


func _finish_taps() -> void:
	_listening = false
	_stop_metronome()
	if _tap_errors_ms.size() < MIN_TAPS:
		_set_status("拍子少于 %d 下，偏移未改。" % MIN_TAPS)
		return
	var sum := 0.0
	for err in _tap_errors_ms:
		sum += err
	var average := sum / float(_tap_errors_ms.size())
	var clamped := clampf(average, -200.0, 200.0)
	Settings.set_player_offset_ms(clamped)
	if _slider:
		_slider.set_value_no_signal(clamped)
	_refresh_label()
	offset_changed.emit(clamped)
	_set_status("已写入偏移 %.0f ms（%d 拍）" % [clamped, _tap_errors_ms.size()])


func _metronome_time() -> float:
	# 播放中优先方案 B，和局内时钟同一公式。播完后硬件位置会归零，收尾改用墙钟。
	var hardware := GameClock.hardware_clock_sec(_click)
	var wall := maxf(0.0, (Time.get_ticks_usec() - _metro_origin_usec) / 1_000_000.0 - _metro_delay)
	if _click and _click.playing and hardware > 0.03:
		return hardware
	return wall


func _stop_metronome() -> void:
	_listening = false
	if _click and _click.playing:
		_click.stop()


func _refresh_label() -> void:
	if _label:
		_label.text = "偏移：%.0f ms" % Settings.player_offset_ms


func _set_status(text: String) -> void:
	if _tap_status:
		_tap_status.text = text
