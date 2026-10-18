extends Node2D
## Game 主玩法根：绑 MusicPlayer、加载谱与音频、开跑，结束时把结算塞进 SceneTree meta。

const DEFAULT_CHART := "res://charts/song_01.json"
const OGG_OVERRIDE := "res://assets/audio/bgm/song_01.ogg"
const TEST_TONE := "res://assets/audio/bgm/song_01_test.wav"
const START_LIVES := 3
const RESULTS_META := "run_results"

const WavLib = preload("res://scripts/audio/WavStream.gd")

@onready var music: AudioStreamPlayer = $MusicPlayer
@onready var sfx: AudioStreamPlayer = $SfxPlayer
@onready var runner: RunnerController = $World/Player
@onready var spawner: ObstacleSpawner = $World/ObstacleSpawner
@onready var pool: ObstaclePool = $World/ObstaclePool
@onready var judge: Judge = $Judge
@onready var score_tracker: ScoreTracker = $ScoreTracker
@onready var input_router: InputRouter = $InputRouter
@onready var hud: GameHUD = $HUD
@onready var buddy_catch = $BuddyCatch

var _lives: int = START_LIVES
var _ended: bool = false
var _sfx_streams: Dictionary = {}


func _ready() -> void:
	if not ChartLoader.load_chart(DEFAULT_CHART):
		push_error("GameRoot: chart load failed: %s" % str(ChartLoader.get_last_errors()))
	_load_bgm()
	_load_sfx()
	GameClock.chart_offset_ms = float(ChartLoader.chart.get("offsetMs", 0.0))
	GameClock.configure_for_song(
		float(ChartLoader.chart.get("durationSec", 0.0)),
		GameClock.chart_offset_ms
	)
	GameClock.bind_player(music)
	if score_tracker and hud:
		score_tracker.score_changed.connect(hud.set_score)
		score_tracker.kisses_changed.connect(hud.set_kisses)
		hud.set_kisses(0)
	if judge:
		judge.judged.connect(_on_judged)
		judge.reset()
	if score_tracker:
		score_tracker.reset()
	if spawner:
		spawner.reset_for_chart()
	if buddy_catch:
		buddy_catch.reset_for_chart()
		if not buddy_catch.caught.is_connected(_on_kiss):
			buddy_catch.caught.connect(_on_kiss)
	_lives = START_LIVES
	if hud:
		hud.set_lives(_lives)
		hud.flash_judge("")
	if not GameClock.song_finished.is_connected(_on_song_finished):
		GameClock.song_finished.connect(_on_song_finished)
	if music.stream == null:
		push_warning("GameRoot: no BGM stream — 空跑墙钟")
	GameClock.start()


func _process(_delta: float) -> void:
	if _ended or not GameClock.is_playing:
		return
	if judge:
		var lane := runner.current_lane if runner else 1
		judge.process_auto_misses(GameClock.song_time_sec, lane)
	if _lives <= 0 or _chart_finished():
		_end_run()


func _load_bgm() -> void:
	# 玩家把 song_01.ogg 丢进目录时优先用它；否则用谱面 audio，再否则用生成的测试音。
	var chosen := ""
	var stream: AudioStream = null
	if FileAccess.file_exists(OGG_OVERRIDE):
		chosen = OGG_OVERRIDE
		stream = WavLib.load_file(OGG_OVERRIDE)
	if stream == null:
		var chart_path := str(ChartLoader.chart.get("audio", ""))
		if not chart_path.is_empty() and FileAccess.file_exists(chart_path):
			chosen = chart_path
			stream = WavLib.load_file(chart_path)
	if stream == null and FileAccess.file_exists(TEST_TONE):
		chosen = TEST_TONE
		stream = WavLib.load_file(TEST_TONE)
	music.stream = stream
	music.volume_db = Settings.bgm_volume_db if Settings else 0.0
	if stream != null:
		print("GameRoot: BGM %s" % chosen)


func _load_sfx() -> void:
	sfx.volume_db = Settings.sfx_volume_db if Settings else 0.0
	for name in ["perfect", "good", "miss", "kiss"]:
		var path := "res://assets/audio/sfx/%s.wav" % name
		var stream := WavLib.load_file(path)
		if stream:
			_sfx_streams[name] = stream


func _play_sfx(result: String) -> void:
	if sfx == null or not _sfx_streams.has(result):
		return
	sfx.stream = _sfx_streams[result]
	sfx.play()


func _on_judged(result: String, note: Dictionary, _delta_ms: float) -> void:
	if _ended:
		return
	if score_tracker:
		score_tracker.register_hit(result)
	if hud:
		hud.flash_judge(result)
	_play_sfx(result)
	if result == "kiss":
		return
	if result == "miss" and str(note.get("type", "")) == "block":
		_lives = maxi(_lives - 1, 0)
		if hud:
			hud.set_lives(_lives)
		if _lives <= 0:
			_end_run()


func _on_kiss() -> void:
	if _ended:
		return
	if score_tracker:
		score_tracker.register_hit("kiss")
	_play_sfx("kiss")


func _on_song_finished() -> void:
	_end_run()


func _chart_finished() -> bool:
	var song_t := GameClock.song_time_sec
	var duration := float(ChartLoader.chart.get("durationSec", 0.0))
	if ChartLoader.notes.is_empty():
		return song_t >= 30.0
	# 有音频时跟到曲长（或 song_finished），避免最后一个音符刚判定就掐断尾音。
	if not GameClock.is_empty_run():
		return duration > 0.0 and song_t >= duration - 0.05
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
	if GameClock.song_finished.is_connected(_on_song_finished):
		GameClock.song_finished.disconnect(_on_song_finished)
	if GameClock.is_playing:
		GameClock.stop()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		GameClock.pause_clock()
		# TODO(Phase 2): 弹「已暂停，建议重开」
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		if not _ended:
			GameClock.resume_clock()
