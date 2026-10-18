extends Node2D
## F3 画出判定盒。默认关。矮丛是圆，花门和平台是收过的矩形，脚是物理盒。

const Layout = preload("res://scripts/gameplay/TrackLayout.gd")

var enabled: bool = false
var _label: Label


func _ready() -> void:
	z_index = 40
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	_label = Label.new()
	_label.text = "碰撞盒开着（再按 F3 关掉）"
	_label.position = Vector2(40, 120)
	_label.visible = false
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_color_override("font_color", Color("#C23B22"))
	layer.add_child(_label)
	set_process(false)


func toggle() -> void:
	enabled = not enabled
	if _label:
		_label.visible = enabled
	set_process(enabled)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_hitboxes"):
		toggle()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not enabled:
		return
	var park := get_parent()
	if park == null:
		return
	var player := park.get_node_or_null("../Player") as RunnerController
	for h in park._hazards:
		var kind := str(h.get("type", ""))
		if kind == "low":
			draw_circle(Vector2(float(h["cx"]), float(h["cy"])), float(h["r"]), Color(0.2, 0.75, 0.35, 0.35))
			draw_arc(Vector2(float(h["cx"]), float(h["cy"])), float(h["r"]), 0.0, TAU, 24, Color(0.1, 0.45, 0.2, 0.9), 2.0)
		elif kind == "high":
			_fill(h, Color(0.95, 0.55, 0.25, 0.28), Color(0.7, 0.35, 0.05, 0.9))
		elif kind == "platform":
			_fill(h, Color(0.85, 0.35, 0.55, 0.28), Color(0.55, 0.15, 0.35, 0.9))
		elif kind == "pit":
			var y := Layout.GROUND_Y
			draw_line(Vector2(float(h["left"]), y - 8.0), Vector2(float(h["left"]), y + 28.0), Color(0.8, 0.2, 0.35, 0.9), 2.0)
			draw_line(Vector2(float(h["right"]), y - 8.0), Vector2(float(h["right"]), y + 28.0), Color(0.8, 0.2, 0.35, 0.9), 2.0)
			var lip := Layout.PIT_LIP
			draw_line(Vector2(float(h["left"]) + lip, y), Vector2(float(h["right"]) - lip, y), Color(0.8, 0.2, 0.35, 0.7), 2.0)
	if player:
		var physics := player.physics_rect()
		draw_rect(physics, Color(0.25, 0.55, 1.0, 0.35), true)
		draw_rect(player.hurt_rect(), Color(0.9, 0.2, 0.25, 0.9), false, 2.0)
	var catcher := get_node_or_null("../../../BuddyCatch") as BuddyCatch
	if catcher and catcher.catch_debug_visible():
		var center := catcher.catch_center()
		var box := Rect2(
			center.x - BuddyCatch.CATCH_RADIUS_X,
			center.y - BuddyCatch.CATCH_RADIUS_Y,
			BuddyCatch.CATCH_RADIUS_X * 2.0,
			BuddyCatch.CATCH_RADIUS_Y * 2.0
		)
		draw_rect(box, Color(0.9, 0.4, 0.55, 0.85), false, 2.0)


func _fill(h: Dictionary, fill: Color, edge: Color) -> void:
	var rect := Rect2(float(h["left"]), float(h["top"]), float(h["right"]) - float(h["left"]), float(h["bottom"]) - float(h["top"]))
	draw_rect(rect, fill, true)
	draw_rect(rect, edge, false, 2.0)
