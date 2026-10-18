extends Node
## 读写 user://settings.cfg：player_offset_ms、音量等。
## Phase 0：先能读配置；键位重绑定可后置。

const CONFIG_PATH := "user://settings.cfg"
const SECTION := "player"

## 玩家全局校准（毫秒）。正值 = 判定提前（感觉音频偏晚时往右拖）。
var player_offset_ms: float = 0.0
var bgm_volume_db: float = 0.0
var sfx_volume_db: float = 0.0
var master_volume_linear: float = 1.0


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(CONFIG_PATH)
	if err != OK:
		# 首次运行：写默认值
		save_settings()
		return
	player_offset_ms = float(cfg.get_value(SECTION, "player_offset_ms", 0.0))
	bgm_volume_db = float(cfg.get_value(SECTION, "bgm_volume_db", 0.0))
	sfx_volume_db = float(cfg.get_value(SECTION, "sfx_volume_db", 0.0))
	master_volume_linear = float(cfg.get_value(SECTION, "master_volume_linear", 1.0))
	_apply_audio_buses()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, "player_offset_ms", player_offset_ms)
	cfg.set_value(SECTION, "bgm_volume_db", bgm_volume_db)
	cfg.set_value(SECTION, "sfx_volume_db", sfx_volume_db)
	cfg.set_value(SECTION, "master_volume_linear", master_volume_linear)
	var err := cfg.save(CONFIG_PATH)
	if err != OK:
		push_warning("Settings: failed to save %s (err=%s)" % [CONFIG_PATH, err])
	_apply_audio_buses()


func set_player_offset_ms(value: float) -> void:
	player_offset_ms = value
	save_settings()


func _apply_audio_buses() -> void:
	# BGM / SFX 音量写在各自的 AudioStreamPlayer 上。这里只推 Master。
	var master := AudioServer.get_bus_index("Master")
	if master < 0:
		return
	var linear := clampf(master_volume_linear, 0.0, 1.0)
	if linear <= 0.0001:
		AudioServer.set_bus_volume_db(master, -80.0)
	else:
		AudioServer.set_bus_volume_db(master, linear_to_db(linear))
