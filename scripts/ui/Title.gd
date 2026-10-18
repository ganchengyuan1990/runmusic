extends Control
## Title：开始 / 校准 / 退出。

@onready var _btn_start: Button = $VBox/StartButton
@onready var _btn_cal: Button = $VBox/CalibrationButton
@onready var _btn_quit: Button = $VBox/QuitButton


func _ready() -> void:
	if _btn_start:
		_btn_start.pressed.connect(_on_start)
	if _btn_cal:
		_btn_cal.pressed.connect(_on_cal)
	if _btn_quit:
		_btn_quit.pressed.connect(_on_quit)


func _on_start() -> void:
	get_tree().change_scene_to_file("res://scenes/game/Game.tscn")


func _on_cal() -> void:
	get_tree().change_scene_to_file("res://scenes/calibration/Calibration.tscn")


func _on_quit() -> void:
	get_tree().quit()
