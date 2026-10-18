# 音乐跑酷 / Music Runner（Godot 4.x MVP 骨架）

横版三轨音乐跑酷。一二在侧视赛道上躲障碍，布布出现时换到同一条赛道接住。以**音频时钟**驱动障碍与判定，含校准 Offset 与结算。

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

### 画面（横版侧视）

窗口默认 **1280×720** 横屏（`project.godot` 里 `viewport` 与 `window_*_override`）。拉伸是 `canvas_items` + `expand`，手持方向锁在横屏（`sensor landscape`）。

三条赛道沿 X 轴铺开，相机从侧面看：

| 谱面 `lane` | 位置 | 键盘 |
| --- | --- | --- |
| 0 | 上轨 | `A` / `←` |
| 1 | 中轨（开局） | |
| 2 | 下轨 | `D` / `→` |

一二站在左侧竖线（判定线，画面约 22%，1280 宽时 x≈280）上，障碍从画面右缘沿本轨向左移动，在 `note.t` 到达判定线。跳是相对当前赛道向上的一小段弧，滑铲把身体压矮。变道只改 Y，不改判定线的 X。

### 角色

| 名字 | 谁 | 画面 |
| --- | --- | --- |
| 一二 | 玩家 | 白熊猫，圆头、黑耳、黑眼圈 |
| 布布 | 可接住的搭档 | 棕熊猫，从右侧靠近 |

占位是工程里的色块，不是商业作品的官方立绘。名字用在界面和说明里；授权由项目方自行处理。造型只作气质参考。

### 美术方向 C

主方向是 **手绘 Q 版熊猫**（Figma 板 06–08）：https://www.figma.com/design/jWxcYeRIyPcnhj9iKlabys

暖纸底 `#FFF6E8`，车道 `#F5E6D3`（中轨 `#F8EBDA`），车道线 `#D4C4B0`，判定线 `#5B8DEF`。一二毛色 `#FFFEFA`，布布 `#C4A484`，描边 `#2B2B2B`。障碍仍是四色：跳 `#5ECF7A`、滑 `#F0C14A`、挡 `#E85D5D`、长按 `#9B7EDE`。亲亲计数 `#E85D7A`。

### 接住布布

谱面音符 `type: "buddy"`。状态是 Approach → CatchWindow → Kiss → Resume。

- 同车道，并且时间落在 `windowsMs.buddy`（默认 ±250ms）里，就算接住。
- 亲亲约 0.6 秒：两人并列放大、出心和「啾」、播放 `assets/audio/sfx/kiss.wav`。歌曲时钟暂停。点一下或按任意键可跳过。
- 没接住只闪「擦肩」，不扣生命。
- 布布和前后障碍至少错开 1.6 秒，避免叠在同一段路上。
- HUD 最上行是「亲亲 ×N」。分数和连击在下面。

### 操作（桌面调试）

| Action | 默认键 | 画面上 |
| --- | --- | --- |
| 上一条赛道 | `A` / `←` | 往上轨 |
| 下一条赛道 | `D` / `→` | 往下轨 |
| 跳 | `W` / `Space` / `↑` | 本轨上跳 |
| 滑 | `S` / `↓` / `Ctrl` | 本轨下蹲 |
| 暂停 | `Esc` / `P` | |

### 触屏（横版分区）

视口分成左右两半、上下两半。没有触摸屏时，鼠标左键单击走同一套分区。

| 区域 | 动作 |
| --- | --- |
| 左半 · 上 | 上一条赛道 |
| 左半 · 下 | 下一条赛道 |
| 右半 · 上 | 跳 |
| 右半 · 下 | 滑铲 |

滑动：上滑跳，下滑滑铲，左滑上轨，右滑下轨。实现见 `scripts/input/InputRouter.gd` 的 `handle_touch`。标题、校准、结算都按 1280×720 居中排，不按竖屏窄栏。

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
5. **触屏分区**：横版四区，见上文。

## Phase 1 — 音频时钟

已接上：

1. **方案 B**：有音频且曲子长于 15 秒时，`song_time` = `get_playback_position()` + `get_time_since_last_mix()` − 缓存的 `get_output_latency()`，回跳丢掉。短曲改用系统钟（方案 A）。两者都减去 `Settings.player_offset_ms` 和谱面 `offsetMs`。  
2. **校准**：滑条 + 听拍，写入 Settings。  
3. **曲目**：`song_01.ogg` 优先；否则用谱面 `audio`；再否则用生成的 `song_01_test.wav`。都没有才空跑。  
4. **谱面**：`song_01.json` 约 60 秒，音符跟测试音的拍对齐。  
5. **音效**：Perfect / Good / Miss 播放 `assets/audio/sfx/` 里的短嘀声。HUD 的分数、连击、生命在音频时钟下同样更新。  
6. **横版**：赛道、判定线、障碍走向、触屏分区和标题/校准/结算都按 1280×720 侧视排列。谱面里的 `lane` 仍是 0/1/2，0 在上、2 在下。方向 C 的纸感底和一二 / 布布占位已接上。布布用音符类型 `buddy`。

仍可后做：一二的跑步两帧、跳、滑正式图，Windows / Android 导出。没有谱面编辑器，也不会自动侦测 BPM。

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
