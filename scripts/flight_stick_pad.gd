extends Control

var stick_vec: Vector2 = Vector2.ZERO
var _touch_idx: int = -1
var _mouse_down: bool = false
var _knob_offset: Vector2 = Vector2.ZERO
var max_radius: float = 86.0

func _ready() -> void:
	custom_minimum_size = Vector2(260, 260)
	mouse_filter = Control.MOUSE_FILTER_STOP

func get_stick_vec() -> Vector2:
	return stick_vec

func _gui_input(event: InputEvent) -> void:
	var center: Vector2 = size * 0.5
	if event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event as InputEventScreenTouch
		if st.pressed and _touch_idx == -1:
			_touch_idx = st.index
			_update_knob(st.position - center)
			accept_event()
		elif not st.pressed and st.index == _touch_idx:
			_reset_knob()
			accept_event()
	elif event is InputEventScreenDrag:
		var sd: InputEventScreenDrag = event as InputEventScreenDrag
		if sd.index == _touch_idx:
			_update_knob(sd.position - center)
			accept_event()
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_mouse_down = true
				_update_knob(mb.position - center)
				accept_event()
			else:
				_reset_knob()
				accept_event()
	elif event is InputEventMouseMotion and _mouse_down:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		_update_knob(mm.position - center)
		accept_event()

func _update_knob(vec: Vector2) -> void:
	if vec.length() > max_radius:
		vec = vec.normalized() * max_radius
	_knob_offset = vec
	stick_vec = vec / max_radius
	queue_redraw()

func _reset_knob() -> void:
	_touch_idx = -1
	_mouse_down = false
	_knob_offset = Vector2.ZERO
	stick_vec = Vector2.ZERO
	queue_redraw()

func _draw() -> void:
	var c: Vector2 = size * 0.5
	var base_r: float = minf(size.x, size.y) * 0.46
	draw_circle(c, base_r, Color(0.06, 0.10, 0.16, 0.68))
	draw_arc(c, base_r, 0.0, TAU, 48, Color(0.85, 0.92, 1.0, 0.72), 3.0)
	draw_arc(c, base_r * 0.52, 0.0, TAU, 36, Color(0.55, 0.72, 0.90, 0.28), 1.5)

	var dcol: Color = Color(1.0, 0.92, 0.45, 0.75)
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -base_r + 8), c + Vector2(-13, -base_r + 28), c + Vector2(13, -base_r + 28)]), dcol)
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, base_r - 8), c + Vector2(-13, base_r - 28), c + Vector2(13, base_r - 28)]), dcol)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-base_r + 8, 0), c + Vector2(-base_r + 28, -13), c + Vector2(-base_r + 28, 13)]), dcol)
	draw_colored_polygon(PackedVector2Array([c + Vector2(base_r - 8, 0), c + Vector2(base_r - 28, -13), c + Vector2(base_r - 28, 13)]), dcol)

	var kp: Vector2 = c + _knob_offset
	draw_line(c, kp, Color(0.25, 0.30, 0.38, 0.85), 18.0)
	draw_circle(kp + Vector2(0, 5), 48.0, Color(0.0, 0.0, 0.0, 0.45))
	draw_circle(kp, 46.0, Color(0.96, 0.82, 0.18, 0.96))
	draw_arc(kp, 46.0, 0.0, TAU, 36, Color(0.06, 0.06, 0.06, 0.95), 4.5)
	draw_circle(kp + Vector2(-12, -12), 14.0, Color(1.0, 0.96, 0.72, 0.70))
