extends Node
class_name ScoreTracker
## 连击、总分、Perfect/Good/Miss 计数；结算屏读取。

signal score_changed(score: int, combo: int)
signal kisses_changed(kisses: int)
signal stats_changed

var score: int = 0
var combo: int = 0
var max_combo: int = 0
var perfect_count: int = 0
var good_count: int = 0
var miss_count: int = 0
var dodge_count: int = 0
## 一二接住布布的次数。结算和 HUD 都以它为主。
var kiss_count: int = 0

const PERFECT_SCORE := 100
const GOOD_SCORE := 50
const DODGE_SCORE := 100
const KISS_SCORE := 300


func reset() -> void:
	score = 0
	combo = 0
	max_combo = 0
	perfect_count = 0
	good_count = 0
	miss_count = 0
	dodge_count = 0
	kiss_count = 0
	score_changed.emit(score, combo)
	kisses_changed.emit(kiss_count)
	stats_changed.emit()


func register_hit(grade: String) -> void:
	match grade:
		"perfect":
			perfect_count += 1
			combo += 1
			score += PERFECT_SCORE + mini(combo, 50)
		"good":
			good_count += 1
			combo += 1
			score += GOOD_SCORE
		"dodge":
			dodge_count += 1
			combo += 1
			score += DODGE_SCORE
		"kiss":
			kiss_count += 1
			score += KISS_SCORE
			kisses_changed.emit(kiss_count)
		"miss":
			miss_count += 1
			combo = 0
		_:
			pass
	max_combo = maxi(max_combo, combo)
	score_changed.emit(score, combo)
	stats_changed.emit()


func get_results_dict() -> Dictionary:
	return {
		"score": score,
		"combo": combo,
		"max_combo": max_combo,
		"perfect": perfect_count,
		"good": good_count,
		"miss": miss_count,
		"dodge": dodge_count,
		"kisses": kiss_count,
	}
