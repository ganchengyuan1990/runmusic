extends Node2D
## Game 主玩法根：绑 MusicPlayer、加载谱、开跑，结束时把结算塞进 SceneTree meta。

const DEFAULT_CHART := "res://charts/song_01.json"
const START_LIVES := 3
const RESULTS_META := "run_results"

@onready var music: AudioStreamPlayer = $MusicPlayer
@onready var runner: RunnerController = $World/Player
@onready var spawner: ObstacleSpawner = $World/ObstacleSpawner
@onready var pool: ObstaclePool = $World/ObstaclePool
@onready var judge: Judge = $Judge
@onready var score_tracker: ScoreTracker = $ScoreTracker
@onready var input_router: InputRouter = $InputRouter
@onready var hud: GameHUD = $HUD

var _lives: int = START_LIVES
var _ended: bool = false


func _ready() -> void:
	GameClock.bind_player(music)
	if not ChartLoader.load_chart(DEFAULT_CHART):
		push_error("GameRoot: chart load failed: %s" % str(ChartLoader.get_last_errors()))
	# TODO(Phase 1): 按 chart.audio 加载 OGG 到 music.stream
	# var stream := load(ChartLoader.chart.get("audio", "")) as AudioStream
	# music.stream = stream
	if score_tracker and hud:
		score_tracker.score_changed.connect(hud.set_score)
	if judge:
		judge.judged.connect(_on_judged)
		judge.reset()
	if score_tracker:
		score_tracker.reset()
	if spawner:
		spawner.reset_for_chart()
	_lives = START_LIVES
	if hud:
		hud.set_lives(_lives)
		hud.flash_judge("")
	if music.stream == null:
		push_warning("GameRoot: no BGM stream yet — Phase 0 空跑模式")
	GameClock.start()


func _process(_delta: float) -> void:
	if _ended or not GameClock.is_playing:
		return
	if judge:
		var lane := runner.current_lane if runner else 1
		judge.process_auto_misses(GameClock.song_time_sec, lane)
	if _lives <= 0 or _chart_finished():
		_end_run()


func _on_judged(result: String, note: Dictionary, _delta_ms: float) -> void:
	if _ended:
		return
	if score_tracker:
		score_tracker.register_hit(result)
	if hud:
		hud.flash_judge(result)
	if result == "miss" and str(note.get("type", "")) == "block":
		_lives = maxi(_lives - 1, 0)
		if hud:
			hud.set_lives(_lives)
		if _lives <= 0:
			_end_run()


func _chart_finished() -> bool:
	var song_t := GameClock.song_time_sec
	var duration := float(ChartLoader.chart.get("durationSec", 0.0))
	if ChartLoader.notes.is_empty():
		return song_t >= 30.0
	if judge and judge.unresolved_count() > 0:
		return duration > 0.0 and song_t >= duration
	var last_t := float(ChartLoader.notes.back().get("t", 0.0))
	var window := 0.1
	if judge:
		window = judge.good_ms / 1000.0
	if song_t >= last_t + window + 0.5:
		return true
	return duration > 0.0 and song_t >= duration


func _end_run() -> void:
	if _ended:
		return
	_ended = true
	var data := {}
	if score_tracker:
		data = score_tracker.get_results_dict()
	data["lives"] = _lives
	get_tree().set_meta(RESULTS_META, data)
	_go_results()


func _go_results() -> void:
	GameClock.stop()
	get_tree().change_scene_to_file("res://scenes/results/Results.tscn")


func _exit_tree() -> void:
	if GameClock.is_playing:
		GameClock.stop()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		GameClock.pause_clock()
		# TODO(Phase 2): 弹「已暂停，建议重开」
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		if not _ended:
			GameClock.resume_clock()
