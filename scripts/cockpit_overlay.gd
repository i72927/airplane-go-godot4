class_name CockpitOverlay
extends Control

var cockpit_tex: Texture2D
var cam_is_cockpit: bool = false
var is_rain: bool = false
var wiper_mode: int = 0
var wiper_angle: float = -1.0
var pitch_deg: float = 0.0
var roll_deg: float = 0.0
var show_ils: bool = false
var ils_x_err: float = 0.0
var ils_y_err: float = 0.0
var show_pip: bool = false
var pip_is_boarding: bool = true
var pip_pct: float = 0.0
var t: float = 0.0
var spd_kt: float = 0.0
var alt_ft: float = 0.0
var gear_dn: bool = true
var hdg_deg: float = 0.0
var warn_text: String = ""

# 2D Cute Chibi Side-Scrolling Minigame State (30 seconds)
var scroll_active: bool = false
var scroll_plane_y: float = 0.5
var scroll_invuln: float = 0.0
var scroll_time_left: float = 30.0
var scroll_clouds: Array[Dictionary] = []
var scroll_stars: Array[Dictionary] = []
var airline_id: String = "plum"
var plane_id: String = "b737"
var weather_mode: String = "day"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	cockpit_tex = load("res://assets/textures/cockpit_panel.png") as Texture2D

func _draw() -> void:
	var sz: Vector2 = size
	var W: float = sz.x
	var H: float = sz.y

	# 0. Cute Chibi 2D Side-Scrolling Cloud-Dodge Minigame (30 Seconds)
	if scroll_active:
		_draw_chibi_scroller(W, H)
		return

	# 1. Pink ILS Localizer & Glideslope Crosshair during Approach
	if show_ils:
		var cx: float = W * 0.5
		var cy: float = H * 0.42 if not cam_is_cockpit else H * 0.30
		var box: float = 56.0
		draw_rect(Rect2(cx - box, cy - box, box * 2.0, box * 2.0), Color(0.28, 0.96, 0.46, 0.72), false, 2.0)
		var lx: float = cx + clampf(-ils_x_err * 0.7, -box + 5.0, box - 5.0)
		var gy: float = cy + clampf(ils_y_err * 0.5, -box + 5.0, box - 5.0)
		draw_line(Vector2(lx, cy - box + 4), Vector2(lx, cy + box - 4), Color(0.99, 0.35, 0.68), 3.2)
		draw_line(Vector2(cx - box + 4, gy), Vector2(cx + box - 4, gy), Color(0.99, 0.35, 0.68), 3.2)

	# 2. 3D Cockpit Glareshield, AAA Panel Texture, Live PFD & Realistic Articulated Wipers
	if cam_is_cockpit:
		var p_col: Color = Color(0.05, 0.08, 0.13)
		draw_rect(Rect2(0, 0, W, 12), p_col)
		draw_colored_polygon(PackedVector2Array([Vector2(0, H * 0.62), Vector2(W * 0.12, 0), Vector2(W * 0.16, 0), Vector2(W * 0.04, H * 0.62)]), p_col)
		draw_colored_polygon(PackedVector2Array([Vector2(W, H * 0.62), Vector2(W * 0.88, 0), Vector2(W * 0.84, 0), Vector2(W * 0.96, H * 0.62)]), p_col)

		if is_rain:
			for ri in range(32):
				var rx: float = fposmod(float(ri * 97) + t * 180.0, W)
				var ry: float = fposmod(float(ri * 131) + t * 760.0, H * 0.62)
				draw_line(Vector2(rx, ry), Vector2(rx - 8.0, ry + 26.0), Color(0.75, 0.88, 0.98, 0.42), 1.6)

		# Realistic Multi-Segment Pantograph Aircraft Windshield Wipers
		if is_rain or wiper_mode > 0:
			var ang: float = wiper_angle * 0.70
			var arm_len: float = H * 0.36
			for side_idx in range(2):
				var wx: float = W * (0.31 if side_idx == 0 else 0.69)
				var wy: float = H * 0.61
				var base_pt: Vector2 = Vector2(wx, wy)
				var dir_v: Vector2 = Vector2(sin(ang), -cos(ang))
				var perp_v: Vector2 = Vector2(cos(ang), sin(ang))
				var mid_pt: Vector2 = base_pt + dir_v * (arm_len * 0.56)
				var tip_pt: Vector2 = base_pt + dir_v * arm_len

				# Subtle cleared rain arc glass highlight
				if is_rain:
					draw_arc(base_pt, arm_len * 0.88, -PI * 0.5 - 0.72, -PI * 0.5 + 0.72, 24, Color(0.85, 0.94, 1.0, 0.14), 18.0)

				# Mounting housing at bottom sill
				draw_circle(base_pt, 11.0, Color(0.08, 0.10, 0.14))
				draw_arc(base_pt, 11.0, 0.0, TAU, 16, Color(0.45, 0.52, 0.60), 2.0)

				# Dual pantograph steel linkage arms
				draw_line(base_pt - perp_v * 4.0, mid_pt - perp_v * 2.5, Color(0.06, 0.08, 0.11), 5.0)
				draw_line(base_pt + perp_v * 4.0, mid_pt + perp_v * 2.5, Color(0.18, 0.22, 0.28), 3.5)
				draw_line(mid_pt, tip_pt, Color(0.08, 0.10, 0.14), 4.0)
				draw_circle(mid_pt, 4.5, Color(0.55, 0.62, 0.70))

				# Curved rubber squeegee blade + pressure claws
				var blade_half: float = H * 0.15
				var b_dir: Vector2 = Vector2(sin(ang * 0.75), -cos(ang * 0.75))
				var b1: Vector2 = tip_pt - b_dir * blade_half
				var b2: Vector2 = tip_pt + b_dir * (blade_half * 0.72)
				draw_line(b1, b2, Color(0.02, 0.03, 0.05), 7.5)
				draw_line(b1 + perp_v * 1.5, b2 + perp_v * 1.5, Color(0.42, 0.48, 0.56), 2.0)
				draw_circle(tip_pt, 4.0, Color(0.35, 0.40, 0.48))

		var panel_y: float = H * 0.58
		var panel_h: float = H * 0.42
		if cockpit_tex != null:
			draw_texture_rect(cockpit_tex, Rect2(0, panel_y, W, panel_h), false)
		else:
			draw_rect(Rect2(0, panel_y, W, panel_h), Color(0.08, 0.12, 0.18))

		var hx: float = W * 0.5
		var hy: float = panel_y + panel_h * 0.44
		var hr: float = minf(56.0, panel_h * 0.22)
		var sky_h: float = clampf(hr + pitch_deg * 2.0, 4.0, hr * 2.0 - 4.0)
		draw_rect(Rect2(hx - hr, hy - hr, hr * 2.0, sky_h), Color(0.02, 0.52, 0.78))
		draw_rect(Rect2(hx - hr, hy - hr + sky_h, hr * 2.0, hr * 2.0 - sky_h), Color(0.57, 0.26, 0.06))
		var r_rad: float = deg_to_rad(-roll_deg)
		var hl: Vector2 = Vector2(-hr * 0.85, 0).rotated(r_rad)
		var hr_v: Vector2 = Vector2(hr * 0.85, 0).rotated(r_rad)
		var h_cen: Vector2 = Vector2(hx, hy - hr + sky_h)
		draw_line(h_cen + hl, h_cen + hr_v, Color.WHITE, 2.0)
		draw_rect(Rect2(hx - hr, hy - hr, hr * 2.0, hr * 2.0), Color(0.22, 0.74, 0.97), false, 2.5)
		draw_line(Vector2(hx - 16, hy), Vector2(hx - 5, hy), Color(0.99, 0.88, 0.28), 3.0)
		draw_line(Vector2(hx + 5, hy), Vector2(hx + 16, hy), Color(0.99, 0.88, 0.28), 3.0)

		var gr: float = minf(44.0, panel_h * 0.18)
		for g_cfg in [[W * 0.34, spd_kt / 500.0, Color(0.22, 0.85, 0.55)], [W * 0.66, fposmod(alt_ft, 1000.0) / 1000.0, Color(0.98, 0.78, 0.22)]]:
			var gx: float = g_cfg[0]
			var frac: float = clampf(g_cfg[1], 0.0, 1.0)
			var ncol: Color = g_cfg[2]
			draw_circle(Vector2(gx, hy), gr, Color(0.05, 0.08, 0.14))
			draw_arc(Vector2(gx, hy), gr, 0.0, TAU, 32, Color(0.35, 0.48, 0.64), 2.0)
			var nang: float = -PI * 0.5 + frac * TAU
			draw_line(Vector2(gx, hy), Vector2(gx + cos(nang) * gr * 0.78, hy + sin(nang) * gr * 0.78), ncol, 2.6)

		for gi in range(3):
			var lcol: Color = Color(0.18, 0.94, 0.44) if gear_dn else Color(0.25, 0.28, 0.32)
			draw_circle(Vector2(W * 0.5 + float(gi - 1) * 18.0, panel_y + 16.0), 5.5, lcol)

	# 3. Boarding / Deplaning Mini-Window (Top-Left PiP)
	if show_pip:
		var px: float = 16.0
		var py: float = 68.0
		var pw: float = 230.0
		var ph: float = 118.0
		draw_rect(Rect2(px, py, pw, ph), Color(0.06, 0.12, 0.22, 0.94))
		draw_rect(Rect2(px, py, pw, ph), Color(0.22, 0.74, 0.97), false, 2.5)
		var ix: float = px + 8.0
		var iy: float = py + 26.0
		var iw: float = pw - 16.0
		var ih: float = 68.0
		draw_rect(Rect2(ix, iy, iw, ih), Color(0.78, 0.84, 0.90))
		draw_rect(Rect2(ix, iy, iw - 34, 14), Color(0.38, 0.45, 0.54))
		draw_rect(Rect2(ix, iy + ih - 14, iw - 34, 14), Color(0.20, 0.26, 0.34))
		for wx in range(int(ix + 6), int(ix + iw - 42), 26):
			draw_rect(Rect2(wx, iy + 18, 18, 16), Color(0.49, 0.83, 0.99))
		draw_rect(Rect2(ix + iw - 34, iy, 34, ih), Color(0.97, 0.98, 1.0))
		draw_rect(Rect2(ix + iw - 32, iy + 20, 14, 34), Color(0.06, 0.09, 0.16))
		var dir: float = 1.0 if pip_is_boarding else -1.0
		var cols: Array[Color] = [Color(0.93, 0.27, 0.27), Color(0.23, 0.51, 0.96), Color(0.66, 0.33, 0.97), Color(0.06, 0.72, 0.51), Color(0.96, 0.62, 0.04)]
		for i in range(5):
			var span: float = iw - 44.0
			var ox: float = fposmod(t * 42.0 * dir + float(i) * 34.0, span)
			var bob: float = sin(t * 14.0 + float(i)) * 2.0
			draw_rect(Rect2(ix + ox + 2, iy + 32 + bob, 6, 6), Color(0.99, 0.90, 0.54))
			draw_rect(Rect2(ix + ox, iy + 38 + bob, 10, 10), cols[i])
			draw_rect(Rect2(ix + ox - 7 * dir, iy + 41, 6, 9), cols[(i + 2) % 5])
		draw_rect(Rect2(ix, py + ph - 16, iw, 10), Color(0.10, 0.16, 0.26))
		draw_rect(Rect2(ix, py + ph - 16, iw * (pip_pct / 100.0), 10), Color(0.29, 0.87, 0.50))

	# 4. Flashing Caution / Stall Warning Box
	if warn_text != "" and int(t * 4.0) % 2 == 0:
		draw_rect(Rect2(W * 0.5 - 140.0, 68.0, 280.0, 32.0), Color(0.88, 0.16, 0.16, 0.92))
		draw_rect(Rect2(W * 0.5 - 140.0, 68.0, 280.0, 32.0), Color(0.99, 0.88, 0.22), false, 2.0)

func _draw_chibi_scroller(W: float, H: float) -> void:
	# 1. Pastel Sky Background Bands
	var top_c: Color = Color(0.22, 0.62, 0.96)
	var bot_c: Color = Color(0.76, 0.92, 1.0)
	if weather_mode == "dusk":
		top_c = Color(0.26, 0.22, 0.52); bot_c = Color(0.98, 0.62, 0.36)
	elif weather_mode == "night":
		top_c = Color(0.05, 0.09, 0.22); bot_c = Color(0.16, 0.26, 0.45)
	elif weather_mode == "rain":
		top_c = Color(0.28, 0.36, 0.48); bot_c = Color(0.56, 0.64, 0.72)

	for band in range(12):
		var bf: float = float(band) / 12.0
		var col: Color = top_c.lerp(bot_c, bf)
		draw_rect(Rect2(0, bf * H, W, H / 12.0 + 2.0), col)

	# 2. Parallax Distant Decorative Clouds & Fluffy Cloud Floor
	for bi in range(8):
		var bx: float = fposmod(float(bi) * 230.0 - t * 65.0, W + 240.0) - 120.0
		var by: float = H * (0.18 + float(bi % 3) * 0.24)
		draw_circle(Vector2(bx, by), 36.0, Color(1, 1, 1, 0.30))
		draw_circle(Vector2(bx + 28.0, by + 6.0), 28.0, Color(1, 1, 1, 0.30))
		draw_circle(Vector2(bx - 26.0, by + 8.0), 26.0, Color(1, 1, 1, 0.30))

	for fi in range(14):
		var fx: float = fposmod(float(fi) * 140.0 - t * 140.0, W + 180.0) - 90.0
		draw_circle(Vector2(fx, H - 10.0), 54.0, Color(0.92, 0.96, 1.0, 0.55))

	# 3. Golden Bonus Stars
	for st in scroll_stars:
		var sx: float = float(st["x"]) * W
		var sy: float = float(st["y"]) * H
		var sr: float = 16.0 + sin(t * 8.0) * 2.5
		draw_circle(Vector2(sx, sy), sr + 4.0, Color(1.0, 0.92, 0.35, 0.35))
		draw_circle(Vector2(sx, sy), sr, Color(1.0, 0.85, 0.12))
		draw_arc(Vector2(sx, sy), sr, 0.0, TAU, 16, Color(0.12, 0.08, 0.02), 2.5)
		draw_circle(Vector2(sx - 4.0, sy - 4.0), 4.0, Color(1.0, 1.0, 0.85))

	# 4. Fluffy Obstacle Clouds
	for cl in scroll_clouds:
		var cx: float = float(cl["x"]) * W
		var cy: float = float(cl["y"]) * H
		var cr: float = float(cl["r"]) * H
		var c_shd: Color = Color(0.66, 0.75, 0.88)
		var c_body: Color = Color(0.95, 0.97, 1.0)
		var c_out: Color = Color(0.18, 0.24, 0.34)
		for off in [Vector2(-cr * 0.65, cr * 0.18), Vector2(cr * 0.65, cr * 0.18), Vector2(0, -cr * 0.28), Vector2(0, cr * 0.15)]:
			draw_circle(Vector2(cx, cy) + off + Vector2(0, 5), cr * 0.68, c_shd)
		for off in [Vector2(-cr * 0.65, cr * 0.12), Vector2(cr * 0.65, cr * 0.12), Vector2(0, -cr * 0.32), Vector2(0, cr * 0.10)]:
			draw_circle(Vector2(cx, cy) + off, cr * 0.66, c_body)
			draw_arc(Vector2(cx, cy) + off, cr * 0.66, 0.0, TAU, 24, c_out, 2.5)
		draw_circle(Vector2(cx - 12.0, cy - 2.0), 4.2, c_out)
		draw_circle(Vector2(cx + 12.0, cy - 2.0), 4.2, c_out)
		draw_line(Vector2(cx - 18.0, cy - 10.0), Vector2(cx - 6.0, cy - 6.0), c_out, 2.6)
		draw_line(Vector2(cx + 18.0, cy - 10.0), Vector2(cx + 6.0, cy - 6.0), c_out, 2.6)

	# 5. Cute Q-Version Chibi Airplane (Body color & wing accent vary by Aircraft Model + Airline Livery)
	if scroll_invuln <= 0.0 or int(t * 14.0) % 2 == 0:
		var px: float = W * 0.22
		var py: float = scroll_plane_y * H + sin(t * 9.0) * 4.0

		# Body tint varies by selected aircraft model
		var body_col: Color = Color(0.98, 0.99, 1.0)
		var wing_col: Color = Color(0.84, 0.92, 0.99)
		var body_len: float = 56.0
		if plane_id == "b737":
			body_col = Color(0.95, 0.98, 1.0); wing_col = Color(0.56, 0.84, 0.98); body_len = 50.0
		elif plane_id == "a321":
			body_col = Color(0.94, 1.0, 0.97); wing_col = Color(0.52, 0.90, 0.76); body_len = 56.0
		elif plane_id == "a330":
			body_col = Color(1.0, 0.96, 0.97); wing_col = Color(0.96, 0.72, 0.82); body_len = 64.0
		elif plane_id == "b787":
			body_col = Color(0.94, 0.97, 1.0); wing_col = Color(0.62, 0.78, 0.99); body_len = 66.0

		# Tail & belly stripe vary by selected airline
		var tail_col: Color = Color(0.98, 0.98, 1.0)
		var accent_col: Color = Color(0.84, 0.20, 0.42)
		if airline_id == "tiger":
			tail_col = Color(0.96, 0.62, 0.06); accent_col = Color(0.14, 0.14, 0.18)
		elif airline_id == "star":
			tail_col = Color(0.16, 0.15, 0.14); accent_col = Color(0.82, 0.68, 0.44)
		elif airline_id == "cnc":
			tail_col = Color(0.06, 0.24, 0.56); accent_col = Color(0.12, 0.62, 0.90)
		elif airline_id == "peach":
			tail_col = Color(0.78, 0.16, 0.54); accent_col = Color(0.48, 0.14, 0.58)
		elif airline_id == "ever":
			tail_col = Color(0.0, 0.44, 0.28); accent_col = Color(0.95, 0.48, 0.10)

		var half_l: float = body_len * 0.5
		for pi in range(4):
			var puff_x: float = px - half_l - 30.0 - float(pi) * 22.0 - fposmod(t * 90.0, 22.0)
			var puff_r: float = maxf(3.0, 12.0 - float(pi) * 2.5)
			draw_circle(Vector2(puff_x, py + 4.0 + sin(t * 10.0 + float(pi)) * 3.0), puff_r, Color(1, 1, 1, 0.72 - float(pi) * 0.15))

		var ink: Color = Color(0.08, 0.10, 0.14)
		var tail_poly := PackedVector2Array([
			Vector2(px - half_l - 18.0, py - 4.0), Vector2(px - half_l - 30.0, py - 42.0),
			Vector2(px - half_l - 6.0, py - 42.0), Vector2(px - half_l + 10.0, py - 8.0)
		])
		draw_colored_polygon(tail_poly, tail_col)
		draw_polyline(PackedVector2Array([tail_poly[0], tail_poly[1], tail_poly[2], tail_poly[3], tail_poly[0]]), ink, 3.0)
		draw_circle(Vector2(px - half_l - 14.0, py - 24.0), 8.5, accent_col)

		draw_circle(Vector2(px - half_l, py), 24.0, body_col)
		draw_circle(Vector2(px + half_l, py), 25.0, body_col)
		draw_rect(Rect2(px - half_l, py - 24.0, body_len, 48.0), body_col)
		draw_rect(Rect2(px - half_l + 2.0, py + 12.0, body_len - 2.0, 9.0), accent_col)
		draw_arc(Vector2(px - half_l, py), 24.0, PI * 0.5, PI * 1.5, 20, ink, 3.0)
		draw_arc(Vector2(px + half_l, py), 25.0, -PI * 0.5, PI * 0.5, 20, ink, 3.0)
		draw_line(Vector2(px - half_l, py - 24.0), Vector2(px + half_l, py - 24.0), ink, 3.0)
		draw_line(Vector2(px - half_l, py + 24.0), Vector2(px + half_l, py + 24.0), ink, 3.0)

		draw_circle(Vector2(px + half_l + 6.0, py - 6.0), 10.5, Color(0.18, 0.32, 0.48))
		draw_arc(Vector2(px + half_l + 6.0, py - 6.0), 10.5, 0.0, TAU, 16, ink, 2.5)
		draw_circle(Vector2(px + half_l + 9.0, py - 8.0), 4.0, Color.WHITE)
		draw_circle(Vector2(px + half_l + 10.0, py + 7.0), 5.5, Color(1.0, 0.56, 0.68, 0.85))
		for wi in range(4):
			draw_circle(Vector2(px - 14.0 + float(wi) * 12.0, py - 2.0), 4.2, Color(0.24, 0.54, 0.82))
			draw_arc(Vector2(px - 14.0 + float(wi) * 12.0, py - 2.0), 4.2, 0.0, TAU, 12, ink, 1.8)

		var wing_poly := PackedVector2Array([
			Vector2(px - 12.0, py + 4.0), Vector2(px + 14.0, py + 4.0),
			Vector2(px - 2.0, py + 32.0), Vector2(px - 22.0, py + 30.0)
		])
		draw_colored_polygon(wing_poly, wing_col)
		draw_polyline(PackedVector2Array([wing_poly[0], wing_poly[1], wing_poly[2], wing_poly[3], wing_poly[0]]), ink, 3.0)
		draw_circle(Vector2(px + 4.0, py + 22.0), 9.0, Color(0.32, 0.38, 0.46))
		draw_arc(Vector2(px + 4.0, py + 22.0), 9.0, 0.0, TAU, 16, ink, 2.5)

	# 6. Top-Center 30-Second Countdown Progress Bar
	var bw: float = 320.0
	var bx0: float = W * 0.5 - bw * 0.5
	var by0: float = 58.0
	draw_rect(Rect2(bx0, by0, bw, 14.0), Color(0.05, 0.08, 0.14, 0.85))
	var frac: float = clampf(1.0 - (scroll_time_left / 30.0), 0.0, 1.0)
	draw_rect(Rect2(bx0 + 2.0, by0 + 2.0, (bw - 4.0) * frac, 10.0), Color(1.0, 0.86, 0.18))
	draw_rect(Rect2(bx0, by0, bw, 14.0), Color(0.05, 0.05, 0.05), false, 2.5)
