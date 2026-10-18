extends Control
class_name CalibrationUI
## 全局 player_offset_ms 滑条 + 简易听拍点校准。

signal offset_changed(ms: float)
signal continue_pressed
signal skip_pressed

@onready var _slider: HSlider = $VBox/OffsetSlider
@onready var _label: Label = $VBox/OffsetLabel
@onready var _btn_continue: Button = $VBox/Buttons/ContinueButton
@onready var _btn_skip: Button = $VBox/Buttons/SkipButton


func _ready() -> void:
	if _slider:
		_slider.min_value = -200.0
		_slider.max_value = 200.0
		_slider.step = 1.0
		_slider.value = Settings.player_offset_ms
		_slider.value_changed.connect(_on_slider_changed)
	_refresh_label()
	if _btn_continue:
		_btn_continue.pressed.connect(func(): continue_pressed.emit())
	if _btn_skip:
		_btn_skip.pressed.connect(func(): skip_pressed.emit())


func _on_slider_changed(value: float) -> void:
	Settings.set_player_offset_ms(value)
	_refresh_label()
	offset_changed.emit(value)


func _refresh_label() -> void:
	if _label:
		_label.text = "偏移：%.0f ms" % Settings.player_offset_ms


## TODO(Phase 1): 听拍点 — 播放短 metronome，玩家点拍测平均误差写入 offset
func start_tap_calibration() -> void:
	pass
