# 音乐跑酷 / Music Runner（Godot 4.x MVP 骨架）

三车道音乐跑酷 Solo MVP 工程骨架。以**音频时钟**驱动障碍与判定，含校准 Offset 与结算流程占位。

> 本仓库当前为 **Phase 0 脚手架**：可在 Godot 4 中打开、场景可切换；BGM / 完整判定 / 对象池回收等见下方「Phase 0 下一步」。

---

## 如何用 Godot 4 打开

1. 安装 **Godot 4.3+**（推荐与 `project.godot` 中 `config/features` 一致；4.2+ 一般可用）。  
   下载：https://godotengine.org/download  
2. 启动 Godot → **Import** / **导入** → 选择本目录下的 `project.godot`。  
3. 首次打开会生成 `.godot/` 与导入缓存（已在 `.gitignore` 中忽略）。  
4. 按 **F5** 运行；主场景为 `scenes/boot/Boot.tscn`（Boot → Title）。  
5. Title 可进 **校准** 或 **开始游戏**（Game 在无 BGM 时会警告并进入空跑模式）。

### 操作（桌面调试）

| Action | 默认键 |
| --- | --- |
| 左变道 | `A` / `←` |
| 右变道 | `D` / `→` |
| 跳 | `W` / `Space` / `↑` |
| 滑 | `S` / `↓` / `Ctrl` |
| 暂停 | `Esc` / `P` |

触屏分区为 Phase 0 待实现（见 `scripts/input/InputRouter.gd`）。

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

## Phase 0 — 建议下一步实现

对照报告 §5 Phase 0 出口标准：**不听歌也能「跑、躲、跳、滑」30 秒不崩**。

1. **Player 手感**：在 `RunnerController` 调车道间距 / 跳滑时长；加简单动画或占位精灵。  
2. **触屏原型**：`InputRouter.handle_touch` — 左半变道、右半跳/滑。  
3. **场景流**：确认 Boot → Title → Game →（手动）Results → Title；可从 Title 跳过校准。  
4. **Windows 导出试一次**：安装 Export Templates，验证能出可执行文件。  
5. **（可选）** 往 `assets/audio/bgm/` 放 `song_01.ogg`，在 `GameRoot` 取消注释加载 `chart.audio`，再 `GameClock.start()`。

进入 **Phase 1** 时再实现：方案 B 时钟联调日志、完整谱生成、Judge 自动 Miss、Calibration 听拍、HUD/SFX、Android Debug APK。

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
