extends Control
## Calibration 场景壳：连接 UI 信号并跳转。

@onready var _ui: CalibrationUI = $CalibrationUI


func _ready() -> void:
	if _ui:
		_ui.continue_pressed.connect(_go_game)
		_ui.skip_pressed.connect(_go_game)


func _go_game() -> void:
	get_tree().change_scene_to_file("res://scenes/game/Game.tscn")
