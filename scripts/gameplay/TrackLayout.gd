extends RefCounted
class_name TrackLayout
## 横版侧视单轨。相机在原点时对应 1280×720 设计坐标：
## screen = world + (640, 360)。赛道 Y 沿用原先的中轨。
## 判定线中心约在画面 x=284（线身从 x=280 起，宽 8）。

const LANE_Y := 30.0
const RUNNER_X := -356.0
const SPAWN_X := 920.0
const HIT_X := -356.0
