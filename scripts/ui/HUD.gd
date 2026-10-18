extends CanvasLayer
class_name GameHUD
## 分数 / 连击 / 判定反馈占位。

@onready var score_label: Label = $Root/ScoreLabel
@onready var combo_label: Label = $Root/ComboLabel
@onready var judge_label: Label = $Root/JudgeLabel


func set_score(score: int, combo: int) -> void:
	if score_label:
		score_label.text = "分数 %d" % score
	if combo_label:
		combo_label.text = "连击 %d" % combo


func flash_judge(text: String) -> void:
	if judge_label:
		judge_label.text = text
	# TODO: 淡出动画
