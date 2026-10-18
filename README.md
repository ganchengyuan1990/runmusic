# 音乐跑酷 / Music Runner（Godot 4.x MVP 骨架）

三车道音乐跑酷 Solo MVP 工程骨架。以**音频时钟**驱动障碍与判定，含校准 Offset 与结算流程占位。

> 本仓库当前为 **Phase 0**：无 BGM 也可空跑。Boot → Title → Game → Results → Title。障碍按谱接近判定线，HUD 计分，结算显示本局数字。

---

## 如何用 Godot 4 打开

1. 安装 **Godot 4.3+**（推荐与 `project.godot` 中 `config/features` 一致；4.2+ 一般可用）。  
   下载：https://godotengine.org/download  
2. 启动 Godot → **Import** / **导入** → 选择本目录下的 `project.godot`。  
3. 首次打开会生成 `.godot/` 与导入缓存（已在 `.gitignore` 中忽略）。  
4. 按 **F5** 运行；主场景为 `scenes/boot/Boot.tscn`（Boot → Title）。  
5. Title 可进 **校准** 或 **开始游戏**。没有 BGM 时 `GameClock` 用墙钟空跑，谱面障碍仍会接近判定线。吃满阻挡或谱面走完会进入结算，再回标题。

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

仍可后做：Player 手感与占位精灵打磨、Windows 导出、往 `assets/audio/bgm/` 放 `song_01.ogg`（不要在本阶段提交音频）。

进入 **Phase 1** 时再实现：方案 B 时钟联调日志、完整谱生成、Calibration 听拍、SFX、Android Debug APK。

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
