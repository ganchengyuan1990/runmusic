# 音乐跑酷 / Music Runner（Godot 4.x MVP 骨架）

三车道音乐跑酷 Solo MVP 工程骨架。以**音频时钟**驱动障碍与判定，含校准 Offset 与结算流程占位。

> 本仓库当前为 **Phase 1**：自带一段可再生成的嘀声测试音。有音频时 `GameClock` 用播放位置驱动障碍；没有音频时仍走墙钟空跑。Boot → Title →（可选校准）→ Game → Results → Title。

---

## 如何用 Godot 4 打开

1. 安装 **Godot 4.3+**（推荐与 `project.godot` 中 `config/features` 一致；4.2+ 一般可用）。  
   下载：https://godotengine.org/download  
2. 启动 Godot → **Import** / **导入** → 选择本目录下的 `project.godot`。  
3. 首次打开会生成 `.godot/` 与导入缓存（已在 `.gitignore` 中忽略）。  
4. 按 **F5** 运行；主场景为 `scenes/boot/Boot.tscn`（Boot → Title）。  
5. Title 可进 **校准** 或 **开始游戏**。默认会播 `assets/audio/bgm/song_01_test.wav`（60 秒、120 BPM 的嘀声，不是版权音乐）。吃满阻挡、曲子走完、或谱面时间到了，都会进入结算。

### 换成自己的歌

1. 把文件放到 `assets/audio/bgm/song_01.ogg`（有这个文件时优先于测试音）。  
2. 用 Godot 打开工程，让它导入 ogg。  
3. 若长度不是 60 秒，改 `charts/song_01.json` 的 `durationSec`，并按需要改 `notes` / `bpm`。判定窗仍是 `windowsMs`，障碍提前量是 `approachSec`。  
4. 测试音可随时用 `python3 tools/gen_test_tone.py` 再生成（正弦嘀声，公共领域）。

### 校准

Title → **校准 Offset**。

- 滑条范围 ±200 ms，松手即写入 `user://settings.cfg` 的 `player_offset_ms`。正值让判定时钟变慢（觉得声音偏晚时往右拖）。  
- **听拍校准**：播 8 拍嘀声，跟着按空格或再点按钮。至少 3 下后，平均误差会写进同一个偏移。局内时钟是播放位置 + 距上次混音的时间 − 输出延迟，再减去这个偏移。

### 操作（桌面调试）

| Action | 默认键 |
| --- | --- |
| 左变道 | `A` / `←` |
| 右变道 | `D` / `→` |
| 跳 | `W` / `Space` / `↑` |
| 滑 | `S` / `↓` / `Ctrl` |
| 暂停 | `Esc` / `P` |

### 触屏（Phase 0 原型）

视口分成三列。没有触摸屏时，鼠标左键单击走同一套分区。

| 区域 | 动作 |
| --- | --- |
| 左 1/3 | 向左变道 |
| 右 1/3 | 向右变道 |
| 中间上半 | 跳 |
| 中间下半 | 滑 |

滑动：横向超过阈值变道（左/右），上滑跳，下滑滑。实现见 `scripts/input/InputRouter.gd` 的 `handle_touch`。

---

## 目录结构（摘要）

```text
res://
├── project.godot
├── charts/song_01.json
├── assets/audio|art|fonts/
├── scenes/boot|title|calibration|game|results/
├── scripts/autoload|gameplay|input|ui/
└── tests/
```

**Autoload：** `Settings`、`GameClock`、`ChartLoader`（已在 `project.godot` 注册）。

---

## Phase 0 — 当前可玩 / 仍可后做

对照报告 §5 Phase 0 出口标准：**不听歌也能「跑、躲、跳、滑」约 30 秒不崩**。

已接上：

1. **空跑时钟**：`MusicPlayer` 没有 stream 时，`GameClock.start()` 用 `Time` 墙钟推进 `song_time_sec`。有 stream 时仍走硬件/系统音频时钟并 `play()`。  
2. **障碍**：`ObstacleSpawner` 按 `charts/song_01.json` 在 `approachSec` 内生成，挂到 `ObstacleRoot`，过线后归还对象池。  
3. **判定**：Perfect/Good 窗读谱面 `windowsMs`。超时的跳/滑自动 Miss；阻挡在 note.t 与玩家同车道则 Miss 并扣生命，否则算躲开。HUD 显示分数、连击、生命。  
4. **结算**：本局数字写入 SceneTree meta `run_results`，Results 显示后可回 Title 或再来一次。生命归零或谱面音符全部判定完也会进结算。  
5. **触屏分区**：见上文。

## Phase 1 — 音频时钟

已接上：

1. **方案 B**：有音频且曲子长于 15 秒时，`song_time` = `get_playback_position()` + `get_time_since_last_mix()` − 缓存的 `get_output_latency()`，回跳丢掉。短曲改用系统钟（方案 A）。两者都减去 `Settings.player_offset_ms` 和谱面 `offsetMs`。  
2. **校准**：滑条 + 听拍，写入 Settings。  
3. **曲目**：`song_01.ogg` 优先；否则用谱面 `audio`；再否则用生成的 `song_01_test.wav`。都没有才空跑。  
4. **谱面**：`song_01.json` 约 60 秒，音符跟测试音的拍对齐。  
5. **音效**：Perfect / Good / Miss 播放 `assets/audio/sfx/` 里的短嘀声。HUD 的分数、连击、生命在音频时钟下同样更新。

仍可后做：Player 手感与占位精灵、Windows / Android 导出。没有谱面编辑器，也不会自动侦测 BPM。

---

## 关联文档

| 文档 | 路径 |
| --- | --- |
| Godot MVP 拆解（本骨架依据） | `/workspace/reports/music-runner-godot-mvp-2026-10-18.md` |
| 品类 / 谱面 / 判定窗调研 | `/workspace/reports/music-runner-research-2026-10-18.md` |
| 引擎双端选型 | `/workspace/reports/music-runner-engine-dual-end-2026-10-18.md` |

官方 Sync with audio：https://docs.godotengine.org/en/stable/tutorials/audio/sync_with_audio.html

---

## 说明

- **不要**用 `_process(delta)` 累加当主歌曲时间；一律走 `GameClock.song_time_sec`。  
- 谱面 schema 见 `charts/song_01.json`；校验逻辑在 `ChartLoader.validate_chart`。  
- 未下载 Godot 二进制；本目录仅为可导入的文本脚手架。  
- `export_presets.cfg` 未提交（见 `.gitignore`），导出时在编辑器内新建预设。

---

*骨架生成日期：2026-10-18（Asia/Shanghai）*
