extends RefCounted
class_name TrackLayout
## 恋爱公园侧视。一二在地面上自由跑，相机跟着走。
## 谱面时间 t 对应世界横坐标：x = START_X + t * px_per_sec()。
## 按住右跑且速度等于 px_per_sec 时，会在音符时刻到达该障碍。

const GROUND_Y := 248.0
const FEET_OFFSET := 48.0
const START_X := 160.0
const PX_PER_SEC := 280.0
const KILL_Y := 460.0

## 站立碰撞盒相对角色原点：底 48，顶 -32。滑铲把顶压到 18，底不变。
const STAND_HALF_W := 30.0
const STAND_TOP := -32.0
const STAND_BOTTOM := 48.0
const SLIDE_HALF_W := 36.0
const SLIDE_TOP := 18.0
const SLIDE_BOTTOM := 48.0

## 花门下沿离地高度。必须高于滑铲顶、低于站立顶，跳也穿不过门拱。
const ARCH_CLEARANCE := 40.0
const ARCH_RISE := 230.0
const BUSH_HEIGHT := 46.0

const GRAVITY := 1800.0
const JUMP_VELOCITY := -640.0
const JUMP_CUT := 0.42
const RUN_SPEED := 280.0
const SPRINT_SPEED := 420.0
const MAX_FALL := 1100.0

## 旧三轨常量。滚动障碍脚本仍引用，公园关卡不再用它们摆玩家。
const LANE_Y := [-130.0, 30.0, 190.0]
const RUNNER_X := -356.0
const SPAWN_X := 920.0
const HIT_X := -356.0


static func px_per_sec() -> float:
	var rate := PX_PER_SEC
	if ChartLoader and not ChartLoader.chart.is_empty():
		rate = float(ChartLoader.chart.get("pxPerSec", PX_PER_SEC))
	if rate <= 1.0:
		return PX_PER_SEC
	return rate


static func x_at_time(t: float) -> float:
	return START_X + t * px_per_sec()


static func stand_y() -> float:
	return GROUND_Y - FEET_OFFSET


static func feet_y(origin_y: float) -> float:
	return origin_y + FEET_OFFSET
