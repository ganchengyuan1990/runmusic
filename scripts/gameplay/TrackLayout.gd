extends RefCounted
class_name TrackLayout
## 恋爱公园侧视。相机跟着一二走。
## 谱面时间 t 对应世界横坐标：x = START_X + t * px_per_sec()。
## 公园局不靠按住右：人的横坐标锁在 x_at_time(歌曲时间) 上，速度就是 px_per_sec。

const GROUND_Y := 248.0
const FEET_OFFSET := 48.0
const START_X := 160.0
const PX_PER_SEC := 280.0
const KILL_Y := 460.0

## 物理碰撞只包住脚，用来站地、落平台。矮丛和花门不是墙，不拿这只盒子去挡人。
## 相对角色原点：底 48 贴地，顶 32，身高 16。滑铲同样贴地，只是略宽。
const STAND_HALF_W := 16.0
const STAND_TOP := 32.0
const STAND_BOTTOM := 48.0
const SLIDE_HALF_W := 22.0
const SLIDE_TOP := 32.0
const SLIDE_BOTTOM := 48.0
const SLIDE_SHIFT_X := 4.0

## 碰到障碍时用的判定盒，比立绘小一圈：耳尖、尾巴和方盒子的空角都不算。
## 站立含头；跳跃是收腿后的身体；滑铲是贴地的身子，不含竖起来的耳尖。
const HURT_STAND := Rect2(-20, -50, 40, 86)
const HURT_JUMP := Rect2(-14, -44, 42, 60)
const HURT_SLIDE := Rect2(-36, 12, 80, 30)

## 花门开口离地 80px。滑铲立绘头顶大约在离地 68px，能从梁下过去。
## 判定盒再往梁里收 ARCH_HURT_INSET，贴着梁的下沿擦过去不算碰到。
const ARCH_CLEARANCE := 80.0
const ARCH_RISE := 230.0
const ARCH_HURT_INSET := 8.0
## 矮丛画面大约高 44。判定是圆，比那三团叶子小一圈。
const BUSH_HEIGHT := 44.0
const BUSH_HURT_R := 22.0
const BUSH_CENTER_LIFT := 20.0
## 坑的两侧各留一窄条草地，脚尖擦到水边还不掉下去。
const PIT_LIP := 12.0

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


static func hurt_local(sliding: bool, airborne: bool) -> Rect2:
	if sliding:
		return HURT_SLIDE
	if airborne:
		return HURT_JUMP
	return HURT_STAND
