extends Node2D
## Game 主玩法根：绑 MusicPlayer、加载谱、开跑。

const DEFAULT_CHART := "res://charts/song_01.json"

@onready var music: AudioStreamPlayer = $MusicPlayer
@onready var runner: RunnerController = $World/Player
@onready var spawner: ObstacleSpawner = $World/ObstacleSpawner
@onready var pool: ObstaclePool = $World/ObstaclePool
@onready var judge: Judge = $Judge
@onready var score_tracker: ScoreTracker = $ScoreTracker
@onready var input_router: InputRouter = $InputRouter


func _ready() -> void:
	GameClock.bind_player(music)
	if not ChartLoader.load_chart(DEFAULT_CHART):
		push_error("GameRoot: chart load failed: %s" % str(ChartLoader.get_last_errors()))
	# TODO(Phase 1): 按 chart.audio 加载 OGG 到 music.stream
	# var stream := load(ChartLoader.chart.get("audio", "")) as AudioStream
	# music.stream = stream
	if judge:
		judge.reset()
	if score_tracker:
		score_tracker.reset()
	if spawner:
		spawner.reset_for_chart()
	if judge:
		judge.judged.connect(_on_judged)
	# Phase 0：无音频也可测输入；有 stream 时再 start
	if music.stream:
		GameClock.start()
	else:
		push_warning("GameRoot: no BGM stream yet — Phase 0 空跑模式")


func _on_judged(result: String, _note: Dictionary, _delta_ms: float) -> void:
	if score_tracker:
		score_tracker.register_hit(result)


func _go_results() -> void:
	# TODO: 用 Autoload 或 SceneTree meta 传结算数据
	get_tree().change_scene_to_file("res://scenes/results/Results.tscn")


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		GameClock.pause_clock()
		# TODO(Phase 2): 弹「已暂停，建议重开」
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		pass
