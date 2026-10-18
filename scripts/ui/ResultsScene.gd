extends Control
## Results 场景壳。

@onready var _ui: ResultsUI = $ResultsUI


func _ready() -> void:
	if _ui:
		_ui.retry_pressed.connect(func():
			get_tree().change_scene_to_file("res://scenes/game/Game.tscn")
		)
		_ui.title_pressed.connect(func():
			get_tree().change_scene_to_file("res://scenes/title/Title.tscn")
		)
		# TODO: 从全局取上局 ScoreTracker.get_results_dict()
		_ui.show_results({
			"score": 0,
			"max_combo": 0,
			"perfect": 0,
			"good": 0,
			"miss": 0,
		})
