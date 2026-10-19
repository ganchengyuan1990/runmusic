# 音乐跑酷 / Music Runner（Godot 4.x 恋爱公园）

横版恋爱公园。一二跟着歌曲时钟自动往右跑，可以变高跳跃、短滑铲，相机跟着走。障碍和平台按谱面时间铺在世界上（`x = 起点 + t × pxPerSec`），歌曲时钟仍是 `GameClock`。掉进坑扣 1 条命，回到检查点，不是直接结束。布布出现时，靠近并且卡在时间窗里就能亲亲。

> 曲目仍是可再生成的嘀声测试音。有音频时 `GameClock` 用播放位置驱动谱面；没有音频时走墙钟。Boot → Title →（可选校准）→ Game → Results → Title。

---

## 如何用 Godot 4 打开

1. 安装 **Godot 4.7**（与 `project.godot` 里 `config/features` 一致）。  
   下载：https://godotengine.org/download  
2. 启动 Godot → **Import** / **导入** → 选择本目录下的 `project.godot`。  
3. 首次打开会生成 `.godot/` 与导入缓存（已在 `.gitignore` 中忽略）。  
4. 按 **F5** 运行；主场景为 `scenes/boot/Boot.tscn`（Boot → Title）。  
5. Title 可进 **校准** 或 **开始游戏**。默认会播 `assets/audio/bgm/song_01_test.wav`（60 秒、120 BPM 的嘀声，不是版权音乐）。生命归零、或曲子走完，进入结算。

### 换成自己的歌

标题里点 **听歌打点**，加载 ogg / wav / mp3，跟着敲，导出 JSON，再点 **试玩**。步骤见下一节。

手里已经有谱时，也可以继续手工改 `charts/song_01.json`：

1. 把文件放到 `assets/audio/bgm/song_01.ogg`（有这个文件时，默认局优先于测试音；打点试玩不会被它盖掉）。  
2. 用 Godot 打开工程，让它导入 ogg。  
3. 若长度不是 60 秒，改 `durationSec`，并按拍改 `notes` / `bpm`。`pxPerSec` 是局内自动跑的世界速度，障碍横坐标跟它对齐。  
4. 测试音可随时用 `python3 tools/gen_test_tone.py` 再生成（正弦嘀声，公共领域）。

### 听歌打点

运行主场景后点 **听歌打点**，或在编辑器里直接打开 `scenes/tools/ChartTap.tscn`（F6）。不改游戏键位，也不改默认的 `song_01`。

1. **加载音频**。WAV 会画波形；ogg / mp3 只画 BPM 拍线。也可以把文件拖进窗口。  
2. **播放**，在听到的位置点下去。默认键：**1** 矮丛、**2** 花门、**3** 坑、**4** 平台、**5** 布布。点音符按钮再按一个键可以改键，记在 `user://chart_tap.cfg`。  
3. **Z** 撤销，**X** 删掉播放头附近的音符，**Tab** 循环类型，**[ ]** 调坑和平台的宽度。勾选 **吸附** 时，落点吸到整拍或 1/2、1/4。  
4. **导出 JSON**。`schemaVersion` 是 1，字段和 `charts/song_01.json` 一样，`ChartLoader` 能直接读。坑带 `width`，平台带 `width` 和 `height`。  
5. **试玩** 把谱写到 `user://charts/preview.json` 并进公园。一二按谱面 `pxPerSec` 跟着歌曲自动往右跑，不用按住右，所以你点在时刻 T 的障碍会在这一拍出现在她脚下。跳和滑铲仍要自己按。结算里「再来一次」还是这首，并且仍然自动跑。回标题后 **开始游戏** 仍是 `song_01`，同样跟着这首歌的时钟自动跑。  
6. **加载谱面** 可以接着改已经导出的 JSON，或仓库里的 `charts/song_01.json`。

`offsetMs` 只影响局内判定时钟，不改你点下去的时刻。听着准就保持 0。

滚轮缩放时间轴，点空白处跳转，点音符选中。左右方向键移动播放头。

### 校准

Title → **校准 Offset**。

- 滑条范围 ±200 ms，松手即写入 `user://settings.cfg` 的 `player_offset_ms`。正值让判定时钟变慢（觉得声音偏晚时往右拖）。  
- **听拍校准**：播 8 拍嘀声，跟着按空格或再点按钮。至少 3 下后，平均误差会写进同一个偏移。局内时钟是播放位置 + 距上次混音的时间 − 输出延迟，再减去这个偏移。

### 画面（恋爱公园）

窗口默认 **1280×720** 横屏。拉伸是 `canvas_items` + `expand`，手持方向锁在横屏。

一二站在草地上，相机在角色右前方。开局后她按谱面 `pxPerSec`（默认 280 px/s）跟着 `GameClock` 自动往右，会在音符时刻赶到对应的障碍。左右和冲刺不改横坐标。跳和滑铲仍由玩家控制。掉进坑之后，重生的横坐标仍锁在当前歌曲时间上。

| 音符 `type` | 公园里 | 怎么过 |
| --- | --- | --- |
| `low`（旧名 `jump`） | 矮丛 | 跳过去。碰到叶子记 Miss，不挡路，不扣命 |
| `high`（旧名 `slide`） | 花门 | 滑铲从梁下过。碰到门身记 Miss，不挡路，不扣命 |
| `pit`（旧名 `block`） | 玫瑰池缺口 | 跳过去。掉下去才扣 1 命，回到检查点，横坐标仍跟歌曲 |
| `platform`（旧名 `hold`） | 心形平台 | 从上往下落到台面。侧面不会把人顶开 |
| `buddy` | 布布 | 人在身边，并且时间落在 `windowsMs.buddy` |

`lane` 可以不写。旧谱如果还带 `lane`，只能是 0..2。检查点由每个坑的前后和布布位置自动放，谱面不用单独写。

干净跳过矮丛、滑过花门时，靠近 `note.t` 记 Perfect / Good，偏离记躲开，都有分。身体碰到矮丛或花门记一次 Miss：断连击、不扣命，人继续跟着歌曲走。扣命只来自掉进坑。接住布布回复 1 条命，最多 5 条。

判定盒比画面小一圈，角上擦到不算。矮丛是收在叶子里的圆，不是那块看不见的方砖。花门的梁下沿也往里收了一点，滑铲立绘能从开口过去。坑的两侧各留约 12px 草地。按 **F3** 可以画出这些盒子。

### 角色

| 名字 | 谁 | 画面 |
| --- | --- | --- |
| 一二 | 玩家 | 白熊猫，圆头、黑耳、黑眼圈 |
| 布布 | 可接住的搭档 | 棕熊猫，站在谱面对应的位置 |

一二和布布用的是 `assets/characters/` 里的 128×128 手绘占位图（见同目录 `MANIFEST.md`），不是商业作品的官方立绘。换成正式立绘时，覆盖同名文件即可：`yier_idle.png`、`yier_run_01.png`、`yier_run_02.png`、`yier_jump.png`、`yier_slide.png`、`bubu_idle.png`、`bubu_approach.png`、`vfx_heart.png`。

### 美术

暖纸底 `#FFF6E8`，草地与小路沿用车道纸色 `#F5E6D3`，描边 `#2B2B2B`。矮丛 `#5ECF7A`，花门金梁 `#F0C14A`，玫瑰池 `#F3B6C8`，平台 `#E7B7C8`。亲亲计数 `#E85D7A`。

### 接住布布

谱面音符 `type: "buddy"`。布布的世界坐标是 `x_at_time(t)`，站在地面上。状态仍是 Approach → CatchWindow → Kiss → Resume。

- 横向距离约 96 px 以内（大约一只身位再加一点容错），纵向约 120 px，并且时间落在 `windowsMs.buddy`（这首歌 ±400ms）里，就算接住。跳起来也亲得到。
- 亲亲约 0.6 秒：两人并列放大、出心和「啾」、播放 `assets/audio/sfx/kiss.wav`。歌曲时钟 `soft_freeze`。这一拍里左右跑、跳、滑和重力都不生效，所以不会在亲亲时掉进坑。点一下或按任意键可跳过。
- 没接住只闪「擦肩」，不扣生命。接住则生命 +1（最多 5），生命数立刻刷新，并短闪「生命 +1」。放大、心形和冻结仍在。

### 操作

| Action | 默认键 | 效果 |
| --- | --- | --- |
| `move_left` | `A` / `←` | 局内不改位置，横坐标跟歌曲 |
| `move_right` | `D` / `→` | 局内不改位置，横坐标跟歌曲 |
| `jump` | `W` / `Space` / `↑` | 按下起跳，按住更高，松开截断 |
| `slide` | `S` / `↓` / `Ctrl` | 短滑铲，判定盒贴地 |
| `sprint` | `Shift` | 局内不加速，速度固定为 `pxPerSec` |
| `pause` | `Esc` / `P` | |
| `debug_hitboxes` | `F3` | 画出判定盒，再按一次关掉 |

### 触屏（横屏分区）

按住不放即持续。没有触摸屏时，鼠标左键按住走同一套分区。

| 区域 | 动作 |
| --- | --- |
| 最左约 22% | 不改水平位置 |
| 左中到约 48% | 不改水平位置 |
| 右半 · 上 | 按住跳 |
| 右半 · 下 | 滑铲 |
| 上滑 / 下滑 | 跳 / 滑铲 |

实现见 `scripts/input/InputRouter.gd`。

---

## 目录结构（摘要）

```text
res://
├── project.godot
├── charts/song_01.json
├── assets/audio|art|fonts|characters/
├── scenes/boot|title|calibration|game|results|tools/
├── scripts/autoload|gameplay|input|ui|tools/
└── tests/mvp_probe.gd
```

**Autoload：** `Settings`、`GameClock`、`ChartLoader`。

玩法脚本：`RunnerController`（重力与跑跳）、`ParkCourse`（按谱面铺 StaticBody）、`BuddyCatch`、`Judge`、`GameRoot`。

---

## 无头 / OpenGL 自检

已安装 Godot 4.3 时：

```bash
godot --headless --path . --import
godot --headless --path . res://tests/mvp_probe.tscn
godot --path . --rendering-method gl_compatibility res://tests/mvp_probe.tscn -- --shots
```

探针会检查：谱面类型、输入映射、着地、变高跳、滑铲碰撞盒、掉坑、亲亲冻结时不掉下去、接住布布生命 +1（最多 5）、擦肩不扣命、障碍按歌曲提前量生成，开始游戏时一二锁在歌曲时钟上（按左、冲刺不会跑出节拍，跳和滑铲仍有效），以及矮丛/花门不挡路、碰到只记 Miss 不扣命。`--shots` 另存标题与公园截图。

---

## 音频时钟（摘要）

1. **方案 B**：有音频且曲子长于 15 秒时，`song_time` = `get_playback_position()` + `get_time_since_last_mix()` − 缓存的 `get_output_latency()`。短曲用系统钟。两者都减去 `Settings.player_offset_ms` 和谱面 `offsetMs`。  
2. **曲目**：`song_01.ogg` 优先；否则用谱面 `audio`；再否则用 `song_01_test.wav`。都没有才空跑。  
3. **音效**：Perfect / Good / Miss / Kiss 播放 `assets/audio/sfx/` 里的短嘀声。  
4. **不要**用 `_process(delta)` 累加当主歌曲时间；一律走 `GameClock.song_time_sec`。

官方 Sync with audio：https://docs.godotengine.org/en/stable/tutorials/audio/sync_with_audio.html

---

## 说明

- 谱面 schema 见 `charts/song_01.json`；校验在 `ChartLoader.validate_chart`。`schemaVersion` 仍是 1，公园类型是加进去的。  
- 旧的三轨滚动障碍脚本还在仓库里，Game 场景已经不挂它们。  
- `export_presets.cfg` 未提交（见 `.gitignore`）。

---

*恋爱公园这一版：2026-10-18*
