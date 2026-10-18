extends CanvasLayer
class_name GameHUD
## 主反馈是一二接住布布的亲亲次数。分数和生命放在下面。

@onready var kiss_label: Label = $Root/KissLabel
@onready var score_label: Label = $Root/ScoreLabel
@onready var lives_label: Label = $Root/LivesLabel
@onready var judge_label: Label = $Root/JudgeLabel
@onready var kiss_overlay: Control = $Root/KissOverlay
@onready var heart: TextureRect = $Root/KissOverlay/Heart

var _flash_left: float = 0.0
var _kiss_time: float = 0.0


func _process(delta: float) -> void:
	if kiss_overlay and kiss_overlay.visible and heart:
		_kiss_time += delta
		var bob := sin(_kiss_time * 6.0) * 8.0
		heart.offset_top = -168.0 + bob
		heart.offset_bottom = -104.0 + bob
	if _flash_left <= 0.0:
		return
	_flash_left = maxf(_flash_left - delta, 0.0)
	if _flash_left <= 0.0 and judge_label:
		judge_label.text = ""


func set_kisses(kisses: int) -> void:
	if kiss_label:
		kiss_label.text = "亲亲 ×%d" % kisses


func set_score(score: int, combo: int) -> void:
	if score_label:
		score_label.text = "分数 %d · 连击 %d" % [score, combo]


func set_lives(lives: int) -> void:
	if lives_label:
		lives_label.text = "生命 %d" % lives


func show_kiss(active: bool) -> void:
	if kiss_overlay:
		kiss_overlay.visible = active
	if active:
		_kiss_time = 0.0


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
		"brush":
			judge_label.text = "擦肩"
		"kiss":
			judge_label.text = "啾"
		_:
			judge_label.text = text
	_flash_left = 0.55
