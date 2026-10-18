extends Node
## 歌曲权威时钟。勿用 _process(delta) 累加当主时间。
## 文档：https://docs.godotengine.org/en/stable/tutorials/audio/sync_with_audio.html
## MVP 推荐方案 B（硬件播放位置 + mix/latency）；短曲也可试方案 A。

signal song_started
signal song_stopped
signal song_finished

enum SyncMode { HARDWARE_CLOCK, SYSTEM_CLOCK }

## 当前歌曲时间（秒），已扣玩家校准；未播放时为 0。
var song_time_sec: float = 0.0
## 是否正在播放（逻辑层；与 AudioStreamPlayer.playing 对齐）。
var is_playing: bool = false
## 同步模式：Phase 0–1 默认 HARDWARE_CLOCK。
var sync_mode: SyncMode = SyncMode.HARDWARE_CLOCK

var _music_player: AudioStreamPlayer = null
var _last_song_time: float = 0.0
var _cached_output_latency: float = 0.0
# 方案 A 用：
var _time_begin_usec: int = 0
var _time_delay: float = 0.0


func _process(_delta: float) -> void:
	if not is_playing or _music_player == null:
		return
	song_time_sec = _compute_song_time()


## 绑定本局 MusicPlayer；开局调用。
func bind_player(player: AudioStreamPlayer) -> void:
	_music_player = player


## 开始同步（在 Music.play() 前后按文档调用）。
func start() -> void:
	if _music_player == null:
		push_error("GameClock.start: no AudioStreamPlayer bound")
		return
	_refresh_latency_cache()
	_last_song_time = 0.0
	song_time_sec = 0.0
	match sync_mode:
		SyncMode.SYSTEM_CLOCK:
			_time_begin_usec = Time.get_ticks_usec()
			_time_delay = AudioServer.get_time_to_next_mix() + AudioServer.get_output_latency()
		SyncMode.HARDWARE_CLOCK:
			pass
	if not _music_player.playing:
		_music_player.play()
	is_playing = true
	song_started.emit()


func stop() -> void:
	is_playing = false
	if _music_player and _music_player.playing:
		_music_player.stop()
	song_time_sec = 0.0
	_last_song_time = 0.0
	song_stopped.emit()


func pause_clock() -> void:
	# TODO(Phase 2): 切后台暂停；恢复时提示重开或校准
	is_playing = false
	if _music_player and _music_player.playing:
		_music_player.stream_paused = true


func resume_clock() -> void:
	# TODO(Phase 2)
	if _music_player:
		_music_player.stream_paused = false
	is_playing = true


func _refresh_latency_cache() -> void:
	_cached_output_latency = AudioServer.get_output_latency()


func _compute_song_time() -> float:
	var raw := 0.0
	match sync_mode:
		SyncMode.SYSTEM_CLOCK:
			# 方案 A：系统时钟（短曲推荐）
			raw = (Time.get_ticks_usec() - _time_begin_usec) / 1_000_000.0
			raw -= _time_delay
			raw = maxf(0.0, raw)
		SyncMode.HARDWARE_CLOCK:
			# 方案 B：硬件播放位置 + mix - latency；丢弃回跳
			if _music_player == null:
				return song_time_sec
			raw = _music_player.get_playback_position() \
				+ AudioServer.get_time_since_last_mix() \
				- _cached_output_latency
			if raw < _last_song_time:
				raw = _last_song_time
			_last_song_time = raw
	# 叠加玩家校准
	var offset_sec := 0.0
	if Settings:
		offset_sec = Settings.player_offset_ms / 1000.0
	return maxf(0.0, raw - offset_sec)
