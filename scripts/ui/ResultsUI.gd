extends Control
class_name ResultsUI
## 结算屏：分数、连击、Perfect/Good/Miss。

signal retry_pressed
signal title_pressed

@onready var _score_label: Label = $VBox/ScoreLabel
@onready var _combo_label: Label = $VBox/ComboLabel
@onready var _stats_label: Label = $VBox/StatsLabel
@onready var _btn_retry: Button = $VBox/Buttons/RetryButton
@onready var _btn_title: Button = $VBox/Buttons/TitleButton


func _ready() -> void:
	if _btn_retry:
		_btn_retry.pressed.connect(func(): retry_pressed.emit())
	if _btn_title:
		_btn_title.pressed.connect(func(): title_pressed.emit())


func show_results(data: Dictionary) -> void:
	if _score_label:
		_score_label.text = "亲亲 ×%d" % int(data.get("kisses", 0))
		_score_label.add_theme_color_override("font_color", Color("#E85D7A"))
	if _combo_label:
		_combo_label.text = "分数：%d    最大连击：%d" % [int(data.get("score", 0)), int(data.get("max_combo", 0))]
	if _stats_label:
		_stats_label.text = "Perfect %d  |  Good %d  |  Miss %d  |  躲开 %d  |  生命 %d" % [
			int(data.get("perfect", 0)),
			int(data.get("good", 0)),
			int(data.get("miss", 0)),
			int(data.get("dodge", 0)),
			int(data.get("lives", 0)),
		]
