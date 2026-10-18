extends CanvasLayer
class_name GameHUD
## 分数 / 连击 / 生命 / 判定反馈。

@onready var score_label: Label = $Root/ScoreLabel
@onready var combo_label: Label = $Root/ComboLabel
@onready var lives_label: Label = $Root/LivesLabel
@onready var judge_label: Label = $Root/JudgeLabel

var _flash_left: float = 0.0


func _process(delta: float) -> void:
	if _flash_left <= 0.0:
		return
	_flash_left = maxf(_flash_left - delta, 0.0)
	if _flash_left <= 0.0 and judge_label:
		judge_label.text = ""


func set_score(score: int, combo: int) -> void:
	if score_label:
		score_label.text = "分数 %d" % score
	if combo_label:
		combo_label.text = "连击 %d" % combo


func set_lives(lives: int) -> void:
	if lives_label:
		lives_label.text = "生命 %d" % lives


func flash_judge(text: String) -> void:
	if judge_label == null:
		return
	if text.is_empty():
		judge_label.text = ""
		_flash_left = 0.0
		return
	match text:
		"perfect":
			judge_label.text = "Perfect"
		"good":
			judge_label.text = "Good"
		"miss":
			judge_label.text = "Miss"
		"dodge":
			judge_label.text = "Dodge"
		_:
			judge_label.text = text
	_flash_left = 0.55
