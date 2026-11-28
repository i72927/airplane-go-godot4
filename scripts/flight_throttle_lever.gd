extends Control

signal throttle_changed(val: float)

var throttle_val: float = 0.0
var _touch_idx: int = -1
var _mouse_down: bool = false

func _ready() -> void:
	custom_minimum_size = Vector2(124, 248)
	mouse_filter = Control.MOUSE_FILTER_STOP

func set_throttle_visual(val: float) -> void:
	throttle_val = clampf(val, 0.0, 1.0)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event as InputEventScreenTouch
		if st.pressed and _touch_idx == -1:
			_touch_idx = st.index
			_update_from_y(st.position.y)
			accept_event()
		elif not st.pressed and st.index == _touch_idx:
			_touch_idx = -1
			accept_event()
	elif event is InputEventScreenDrag:
		var sd: InputEventScreenDrag = event as InputEventScreenDrag
		if sd.index == _touch_idx:
			_update_from_y(sd.position.y)
			accept_event()
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_mouse_down = true
				_update_from_y(mb.position.y)
				accept_event()
			else:
				_mouse_down = false
				accept_event()
	elif event is InputEventMouseMotion and _mouse_down:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		_update_from_y(mm.position.y)
		accept_event()

func _update_from_y(py: float) -> void:
	var top_pad: float = 34.0
	var bot_pad: float = size.y - 34.0
	var frac: float = clampf(1.0 - ((py - top_pad) / maxf(1.0, bot_pad - top_pad)), 0.0, 1.0)
	throttle_val = frac
	emit_signal("throttle_changed", throttle_val)
	queue_redraw()

func _draw() -> void:
	var W: float = size.x
	var H: float = size.y
	var cx: float = W * 0.5

	# Quadrant dark metallic housing with crisp black border
	draw_rect(Rect2(2, 2, W - 4, H - 4), Color(0.11, 0.14, 0.19, 0.92))
	draw_rect(Rect2(2, 2, W - 4, H - 4), Color(0.03, 0.03, 0.05, 1.0), false, 3.0)
	draw_rect(Rect2(6, 6, W - 12, H - 12), Color(0.24, 0.29, 0.36, 0.55), false, 1.5)

	# Dual slotted tracks for twin-engine thrust levers
	var top_y: float = 34.0
	var bot_y: float = H - 34.0
	for sx in [cx - 22.0, cx + 22.0]:
		draw_rect(Rect2(sx - 6.0, top_y, 12.0, bot_y - top_y), Color(0.03, 0.04, 0.06))
		draw_rect(Rect2(sx - 6.0, top_y, 12.0, bot_y - top_y), Color(0.35, 0.42, 0.50), false, 1.0)

	# Detent tick marks (TOGA / CLB / 50% / IDLE)
	for ti in range(5):
		var ty: float = lerpf(bot_y, top_y, float(ti) / 4.0)
		var tcol: Color = Color(0.96, 0.28, 0.22) if ti == 4 else (Color(0.98, 0.84, 0.18) if ti == 3 else Color(0.75, 0.82, 0.90))
		draw_line(Vector2(9.0, ty), Vector2(18.0, ty), tcol, 2.2)
		draw_line(Vector2(W - 18.0, ty), Vector2(W - 9.0, ty), tcol, 2.2)

	# Live power fill bar on left edge
	var bar_h: float = (bot_y - top_y) * throttle_val
	var pcol: Color = Color(0.96, 0.30, 0.20) if throttle_val > 0.88 else (Color(0.98, 0.82, 0.16) if throttle_val > 0.45 else Color(0.24, 0.86, 0.50))
	if bar_h > 1.0:
		draw_rect(Rect2(6.0, bot_y - bar_h, 4.0, bar_h), pcol)

	# Sculpted Twin-Engine T-Bar Aircraft Thrust Lever Handle
	var hy: float = lerpf(bot_y, top_y, throttle_val)
	# Metallic stalks from quadrant bottom to handle
	for sx in [cx - 22.0, cx + 22.0]:
		draw_line(Vector2(sx, bot_y), Vector2(sx, hy), Color(0.62, 0.68, 0.76), 5.0)
		draw_line(Vector2(sx - 1.5, bot_y), Vector2(sx - 1.5, hy), Color(0.88, 0.92, 0.96), 1.8)

	# Handle shadow + ergonomic T-bar grip
	draw_rect(Rect2(10.0, hy - 14.0, W - 20.0, 36.0), Color(0.0, 0.0, 0.0, 0.48))
	draw_rect(Rect2(8.0, hy - 18.0, W - 16.0, 36.0), Color(0.20, 0.24, 0.30))
	draw_rect(Rect2(8.0, hy - 18.0, W - 16.0, 12.0), Color(0.36, 0.42, 0.50))
	draw_rect(Rect2(8.0, hy - 18.0, W - 16.0, 36.0), Color(0.04, 0.04, 0.06), false, 2.5)
	# Grip center yellow/white thrust indicator band & twin handle divider
	draw_line(Vector2(14.0, hy), Vector2(W - 14.0, hy), Color(1.0, 0.88, 0.18), 3.0)
	draw_line(Vector2(cx, hy - 18.0), Vector2(cx, hy + 18.0), Color(0.05, 0.06, 0.08), 3.0)
