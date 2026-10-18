extends Control
## Results 场景壳。从上局 SceneTree meta 读取分数。

const RESULTS_META := "run_results"

@onready var _ui: ResultsUI = $ResultsUI


func _ready() -> void:
	if _ui == null:
		return
	_ui.retry_pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/game/Game.tscn")
	)
	_ui.title_pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/title/Title.tscn")
	)
	var data: Dictionary = {}
	if get_tree().has_meta(RESULTS_META):
		var raw = get_tree().get_meta(RESULTS_META)
		if typeof(raw) == TYPE_DICTIONARY:
			data = raw
	if data.is_empty():
		data = {
			"score": 0,
			"max_combo": 0,
			"perfect": 0,
			"good": 0,
			"miss": 0,
			"dodge": 0,
			"lives": 0,
			"kisses": 0,
		}
	_ui.show_results(data)
