extends Node
## 歌曲权威时钟。勿用 _process(delta) 累加当主时间。
## 文档：https://docs.godotengine.org/en/stable/tutorials/audio/sync_with_audio.html
## 有 stream：长曲用方案 B（播放位置 + mix - 输出延迟，单调）；短曲用方案 A 系统钟。
## 无 stream：墙钟空跑。两种都扣 Settings.player_offset_ms 和谱面 offsetMs。

signal song_started
signal song_stopped
signal song_finished

enum SyncMode { HARDWARE_CLOCK, SYSTEM_CLOCK }

## 短于此时长的曲子用系统钟（方案 A）。测试音 60s 走方案 B。
const SHORT_SONG_SEC := 15.0

## 当前歌曲时间（秒），已扣玩家校准与谱面偏移；未播放时为 0。
var song_time_sec: float = 0.0
## 是否正在播放（逻辑层；空跑时仅逻辑层为 true）。
var is_playing: bool = false
## 有 stream 时的同步模式。configure_for_song() 会按曲长选择。
var sync_mode: SyncMode = SyncMode.HARDWARE_CLOCK
## 谱面自带偏移（毫秒），与玩家校准相加。正值让 song_time 落后于扬声器时间。
var chart_offset_ms: float = 0.0

var _music_player: AudioStreamPlayer = null
var _last_song_time: float = 0.0
var _cached_output_latency: float = 0.0
var _latency_refresh_sec: float = 0.0
# 方案 A 用：
var _time_begin_usec: int = 0
var _time_delay: float = 0.0
## 无 stream 的空跑墙钟起点。
var _empty_run: bool = false
var _empty_origin_usec: int = 0
var _finish_armed: bool = false


func _process(delta: float) -> void:
	if not is_playing:
		return
	if _empty_run:
		var wall := (Time.get_ticks_usec() - _empty_origin_usec) / 1_000_000.0
		song_time_sec = _with_offsets(wall)
		return
	if _music_player == null:
		return
	_refresh_latency_if_stable(delta)
	song_time_sec = _compute_song_time()
	_poll_natural_end()


## 绑定本局 MusicPlayer；开局调用。
func bind_player(player: AudioStreamPlayer) -> void:
	_music_player = player


## 按曲长选择方案 B 或短曲方案 A，并记下谱面偏移。
func configure_for_song(duration_sec: float, song_offset_ms: float = 0.0) -> void:
	chart_offset_ms = song_offset_ms
	if duration_sec > 0.0 and duration_sec <= SHORT_SONG_SEC:
		sync_mode = SyncMode.SYSTEM_CLOCK
	else:
		sync_mode = SyncMode.HARDWARE_CLOCK


## 方案 B 的原始公式，不含玩家校准。校准听拍用它，避免把已有 offset 再算一遍。
static func hardware_clock_sec(player: AudioStreamPlayer) -> float:
	if player == null:
		return 0.0
	return player.get_playback_position() \
		+ AudioServer.get_time_since_last_mix() \
		- AudioServer.get_output_latency()


## 有 stream 时走音频时钟并 play()；无 stream 时用墙钟空跑，不调用 play()。
func start() -> void:
	if _music_player == null:
		push_error("GameClock.start: no AudioStreamPlayer bound")
		return
	_last_song_time = 0.0
	song_time_sec = 0.0
	_finish_armed = false
	_latency_refresh_sec = 0.0
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
			# 方案 A：先采样混音延迟，再 play()。短曲比硬件位置稳。
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
	_finish_armed = false
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
		var elapsed := song_time_sec + _offset_sec()
		_empty_origin_usec = Time.get_ticks_usec() - int(maxf(elapsed, 0.0) * 1_000_000.0)
		is_playing = true
		return
	if _music_player:
		_music_player.stream_paused = false
		if sync_mode == SyncMode.SYSTEM_CLOCK:
			# 方案 A 暂停后重锚，免得墙钟把暂停算进歌里。
			var raw := song_time_sec + _offset_sec()
			_time_begin_usec = Time.get_ticks_usec()
			_time_delay = -raw
	is_playing = true


func is_empty_run() -> bool:
	return _empty_run


func _refresh_latency_cache() -> void:
	_cached_output_latency = AudioServer.get_output_latency()


func _refresh_latency_if_stable(delta: float) -> void:
	if sync_mode != SyncMode.HARDWARE_CLOCK:
		return
	_latency_refresh_sec += delta
	if _latency_refresh_sec < 0.5:
		return
	_latency_refresh_sec = 0.0
	var latest := AudioServer.get_output_latency()
	# 只跟小幅变化，避免设备切换把单调时钟卡死在旧值上。
	if absf(latest - _cached_output_latency) < 0.02:
		_cached_output_latency = latest


func _offset_sec() -> float:
	var ms := chart_offset_ms
	if Settings:
		ms += Settings.player_offset_ms
	return ms / 1000.0


func _with_offsets(raw: float) -> float:
	return maxf(0.0, raw - _offset_sec())


func _compute_song_time() -> float:
	var raw := 0.0
	match sync_mode:
		SyncMode.SYSTEM_CLOCK:
			raw = (Time.get_ticks_usec() - _time_begin_usec) / 1_000_000.0
			raw -= _time_delay
			raw = maxf(0.0, raw)
		SyncMode.HARDWARE_CLOCK:
			# 方案 B：硬件播放位置 + mix - latency；丢弃回跳。
			if _music_player == null:
				return song_time_sec
			raw = _music_player.get_playback_position() \
				+ AudioServer.get_time_since_last_mix() \
				- _cached_output_latency
			if raw < _last_song_time:
				raw = _last_song_time
			_last_song_time = raw
	return _with_offsets(raw)


func _poll_natural_end() -> void:
	if _music_player == null or _music_player.stream_paused:
		return
	if _music_player.playing:
		if song_time_sec > 0.2:
			_finish_armed = true
		return
	if not _finish_armed:
		return
	_finish_armed = false
	is_playing = false
	song_finished.emit()
