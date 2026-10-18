extends Node
## 歌曲权威时钟。勿用 _process(delta) 累加当主时间。
## 文档：https://docs.godotengine.org/en/stable/tutorials/audio/sync_with_audio.html
## MVP 推荐方案 B（硬件播放位置 + mix/latency）；短曲也可试方案 A。
## 无音频流时走空跑：用 Time 墙钟推进 song_time_sec，谱面/障碍仍可读同一时钟。

signal song_started
signal song_stopped
signal song_finished

enum SyncMode { HARDWARE_CLOCK, SYSTEM_CLOCK }

## 当前歌曲时间（秒），已扣玩家校准；未播放时为 0。
var song_time_sec: float = 0.0
## 是否正在播放（逻辑层；与 AudioStreamPlayer.playing 对齐，空跑时仅逻辑层）。
var is_playing: bool = false
## 同步模式：有 stream 时 Phase 0–1 默认 HARDWARE_CLOCK。
var sync_mode: SyncMode = SyncMode.HARDWARE_CLOCK

var _music_player: AudioStreamPlayer = null
var _last_song_time: float = 0.0
var _cached_output_latency: float = 0.0
# 方案 A 用：
var _time_begin_usec: int = 0
var _time_delay: float = 0.0
## 无 stream 的空跑墙钟起点。
var _empty_run: bool = false
var _empty_origin_usec: int = 0


func _process(_delta: float) -> void:
	if not is_playing:
		return
	if _empty_run:
		var raw := (Time.get_ticks_usec() - _empty_origin_usec) / 1_000_000.0
		song_time_sec = _with_player_offset(raw)
		return
	if _music_player == null:
		return
	song_time_sec = _compute_song_time()


## 绑定本局 MusicPlayer；开局调用。
func bind_player(player: AudioStreamPlayer) -> void:
	_music_player = player


## 有 stream 时走音频时钟并 play()；无 stream 时用墙钟空跑，不调用 play()。
func start() -> void:
	if _music_player == null:
		push_error("GameClock.start: no AudioStreamPlayer bound")
		return
	_last_song_time = 0.0
	song_time_sec = 0.0
	if _music_player.stream == null:
		_empty_run = true
		_empty_origin_usec = Time.get_ticks_usec()
		is_playing = true
		song_started.emit()
		return
	_empty_run = false
	_refresh_latency_cache()
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
	var was_playing := is_playing
	is_playing = false
	_empty_run = false
	if _music_player and _music_player.playing:
		_music_player.stop()
	song_time_sec = 0.0
	_last_song_time = 0.0
	if was_playing:
		song_stopped.emit()


func pause_clock() -> void:
	# TODO(Phase 2): 切后台暂停；恢复时提示重开或校准
	is_playing = false
	if _empty_run:
		return
	if _music_player and _music_player.playing:
		_music_player.stream_paused = true


func resume_clock() -> void:
	# TODO(Phase 2)
	if _empty_run:
		# 从当前 song_time 续上，避免暂停期间墙钟把时间跳走。
		_empty_origin_usec = Time.get_ticks_usec() - int(song_time_sec * 1_000_000.0)
		is_playing = true
		return
	if _music_player:
		_music_player.stream_paused = false
	is_playing = true


func is_empty_run() -> bool:
	return _empty_run


func _refresh_latency_cache() -> void:
	_cached_output_latency = AudioServer.get_output_latency()


func _with_player_offset(raw: float) -> float:
	var offset_sec := 0.0
	if Settings:
		offset_sec = Settings.player_offset_ms / 1000.0
	return maxf(0.0, raw - offset_sec)


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
	return _with_player_offset(raw)
