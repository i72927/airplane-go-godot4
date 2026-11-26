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
var show_hud: bool = false
var ils_x_err: float = 0.0
var ils_y_err: float = 0.0
var show_pip: bool = false
var pip_is_boarding: bool = true
var pip_pct: float = 0.0
var t: float = 0.0
var spd_kt: float = 0.0
var target_spd: float = 150.0
var alt_ft: float = 0.0
var target_alt: float = 0.0
var gear_dn: bool = true
var hdg_deg: float = 0.0
var warn_text: String = ""
var plane_px: float = 0.0
var plane_pz: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	cockpit_tex = load("res://assets/textures/cockpit_panel.png") as Texture2D

func _draw() -> void:
	var sz := size
	var W := sz.x
	var H := sz.y

	# 1. Jet de GO! 2 Green Arcade Flight HUD (Pitch Ladder, Speed/Alt Brackets, ILS Crosshair)
	if false:
		var cx := W * 0.5
		var cy := H * 0.42
		var gcol := Color(0.28, 0.96, 0.46, 0.85)
		var r_rad := deg_to_rad(-roll_deg)

		# Green Pitch Ladder (-10, -5, 0, +5, +10)
		for p_step in [-10, -5, 0, 5, 10]:
			var py_off := (float(p_step) - pitch_deg) * -4.2
			if absf(py_off) < 110.0:
				var half_w := 56.0 if p_step == 0 else 32.0
				var p1 := Vector2(cx, cy + py_off) + Vector2(-half_w, 0).rotated(r_rad)
				var p2 := Vector2(cx, cy + py_off) + Vector2(-10.0, 0).rotated(r_rad)
				var p3 := Vector2(cx, cy + py_off) + Vector2(10.0, 0).rotated(r_rad)
				var p4 := Vector2(cx, cy + py_off) + Vector2(half_w, 0).rotated(r_rad)
				draw_line(p1, p2, gcol, 2.2)
				draw_line(p3, p4, gcol, 2.2)

		# Left Speed Bracket & Right Altitude Bracket
		draw_rect(Rect2(cx - 190.0, cy - 36.0, 82.0, 72.0), Color(0.05, 0.14, 0.08, 0.55))
		draw_rect(Rect2(cx - 190.0, cy - 36.0, 82.0, 72.0), gcol, false, 2.0)
		draw_rect(Rect2(cx + 108.0, cy - 36.0, 92.0, 72.0), Color(0.05, 0.14, 0.08, 0.55))
		draw_rect(Rect2(cx + 108.0, cy - 36.0, 92.0, 72.0), gcol, false, 2.0)

		# Target Speed & Target Alt Indicators
		var spd_diff := clampf((target_spd - spd_kt) * 0.9, -30.0, 30.0)
		draw_circle(Vector2(cx - 112.0, cy - spd_diff), 4.5, Color(0.99, 0.35, 0.65))
		var alt_diff := clampf((target_alt - alt_ft) * 0.08, -30.0, 30.0)
		draw_circle(Vector2(cx + 112.0, cy - alt_diff), 4.5, Color(0.99, 0.35, 0.65))

	# Pink/Yellow ILS Localizer & Glideslope Crosshair during Approach
	if show_ils:
		var cx := W * 0.5
		var cy := H * 0.42 if not cam_is_cockpit else H * 0.30
		var box := 56.0
		draw_rect(Rect2(cx - box, cy - box, box * 2.0, box * 2.0), Color(0.28, 0.96, 0.46, 0.72), false, 2.0)
		var lx := cx + clampf(-ils_x_err * 0.7, -box + 5.0, box - 5.0)
		var gy := cy + clampf(ils_y_err * 0.5, -box + 5.0, box - 5.0)
		draw_line(Vector2(lx, cy - box + 4), Vector2(lx, cy + box - 4), Color(0.99, 0.35, 0.68), 3.2)
		draw_line(Vector2(cx - box + 4, gy), Vector2(cx + box - 4, gy), Color(0.99, 0.35, 0.68), 3.2)

	# 2. 3D Cockpit Glareshield, AAA Panel Texture, Live PFD & Animated Rain Wipers
	if cam_is_cockpit:
		var p_col := Color(0.05, 0.08, 0.13)
		draw_rect(Rect2(0, 0, W, 12), p_col)
		draw_colored_polygon(PackedVector2Array([Vector2(0, H * 0.62), Vector2(W * 0.12, 0), Vector2(W * 0.16, 0), Vector2(W * 0.04, H * 0.62)]), p_col)
		draw_colored_polygon(PackedVector2Array([Vector2(W, H * 0.62), Vector2(W * 0.88, 0), Vector2(W * 0.84, 0), Vector2(W * 0.96, H * 0.62)]), p_col)

		if is_rain:
			for ri in range(28):
				var rx := fposmod(float(ri * 97) + t * 180.0, W)
				var ry := fposmod(float(ri * 131) + t * 760.0, H * 0.62)
				draw_line(Vector2(rx, ry), Vector2(rx - 8.0, ry + 26.0), Color(0.75, 0.88, 0.98, 0.42), 1.6)

		if is_rain or wiper_mode > 0:
			var ang := wiper_angle * 0.72
			for wx in [W * 0.34, W * 0.66]:
				var wy := H * 0.62
				var tip := Vector2(wx + sin(ang) * H * 0.38, wy - cos(ang) * H * 0.38)
				draw_line(Vector2(wx, wy), tip, Color(0.02, 0.03, 0.06), 10.0)
				draw_line(Vector2(wx, wy), tip, Color(0.45, 0.52, 0.62), 3.0)

		var panel_y := H * 0.58
		var panel_h := H * 0.42
		if cockpit_tex != null:
			draw_texture_rect(cockpit_tex, Rect2(0, panel_y, W, panel_h), false)
		else:
			draw_rect(Rect2(0, panel_y, W, panel_h), Color(0.08, 0.12, 0.18))

		var hx := W * 0.5
		var hy := panel_y + panel_h * 0.44
		var hr := minf(56.0, panel_h * 0.22)
		var sky_h := clampf(hr + pitch_deg * 2.0, 4.0, hr * 2.0 - 4.0)
		draw_rect(Rect2(hx - hr, hy - hr, hr * 2.0, sky_h), Color(0.02, 0.52, 0.78))
		draw_rect(Rect2(hx - hr, hy - hr + sky_h, hr * 2.0, hr * 2.0 - sky_h), Color(0.57, 0.26, 0.06))
		var r_rad := deg_to_rad(-roll_deg)
		var hl := Vector2(-hr * 0.85, 0).rotated(r_rad)
		var hr_v := Vector2(hr * 0.85, 0).rotated(r_rad)
		var h_cen := Vector2(hx, hy - hr + sky_h)
		draw_line(h_cen + hl, h_cen + hr_v, Color.WHITE, 2.0)
		draw_rect(Rect2(hx - hr, hy - hr, hr * 2.0, hr * 2.0), Color(0.22, 0.74, 0.97), false, 2.5)
		draw_line(Vector2(hx - 16, hy), Vector2(hx - 5, hy), Color(0.99, 0.88, 0.28), 3.0)
		draw_line(Vector2(hx + 5, hy), Vector2(hx + 16, hy), Color(0.99, 0.88, 0.28), 3.0)

		var gr := minf(44.0, panel_h * 0.18)
		for g_cfg in [[W * 0.34, spd_kt / 500.0, Color(0.22, 0.85, 0.55)], [W * 0.66, fposmod(alt_ft, 1000.0) / 1000.0, Color(0.98, 0.78, 0.22)]]:
			var gx: float = g_cfg[0]
			var frac: float = clampf(g_cfg[1], 0.0, 1.0)
			var ncol: Color = g_cfg[2]
			draw_circle(Vector2(gx, hy), gr, Color(0.05, 0.08, 0.14))
			draw_arc(Vector2(gx, hy), gr, 0.0, TAU, 32, Color(0.35, 0.48, 0.64), 2.0)
			var nang := -PI * 0.5 + frac * TAU
			draw_line(Vector2(gx, hy), Vector2(gx + cos(nang) * gr * 0.78, hy + sin(nang) * gr * 0.78), ncol, 2.6)

		for gi in range(3):
			var lcol := Color(0.18, 0.94, 0.44) if gear_dn else Color(0.25, 0.28, 0.32)
			draw_circle(Vector2(W * 0.5 + float(gi - 1) * 18.0, panel_y + 16.0), 5.5, lcol)

	# 3. Boarding / Deplaning Mini-Window (Top-Left PiP)
	if show_pip:
		var px := 16.0
		var py := 68.0
		var pw := 230.0
		var ph := 118.0
		draw_rect(Rect2(px, py, pw, ph), Color(0.06, 0.12, 0.22, 0.94))
		draw_rect(Rect2(px, py, pw, ph), Color(0.22, 0.74, 0.97), false, 2.5)
		var ix := px + 8.0
		var iy := py + 26.0
		var iw := pw - 16.0
		var ih := 68.0
		draw_rect(Rect2(ix, iy, iw, ih), Color(0.78, 0.84, 0.90))
		draw_rect(Rect2(ix, iy, iw - 34, 14), Color(0.38, 0.45, 0.54))
		draw_rect(Rect2(ix, iy + ih - 14, iw - 34, 14), Color(0.20, 0.26, 0.34))
		for wx in range(int(ix + 6), int(ix + iw - 42), 26):
			draw_rect(Rect2(wx, iy + 18, 18, 16), Color(0.49, 0.83, 0.99))
		draw_rect(Rect2(ix + iw - 34, iy, 34, ih), Color(0.97, 0.98, 1.0))
		draw_rect(Rect2(ix + iw - 32, iy + 20, 14, 34), Color(0.06, 0.09, 0.16))
		var dir := 1.0 if pip_is_boarding else -1.0
		var cols := [Color(0.93, 0.27, 0.27), Color(0.23, 0.51, 0.96), Color(0.66, 0.33, 0.97), Color(0.06, 0.72, 0.51), Color(0.96, 0.62, 0.04)]
		for i in range(5):
			var span := iw - 44.0
			var ox := fposmod(t * 42.0 * dir + float(i) * 34.0, span)
			var bob := sin(t * 14.0 + float(i)) * 2.0
			draw_rect(Rect2(ix + ox + 2, iy + 32 + bob, 6, 6), Color(0.99, 0.90, 0.54))
			draw_rect(Rect2(ix + ox, iy + 38 + bob, 10, 10), cols[i])
			draw_rect(Rect2(ix + ox - 7 * dir, iy + 41, 6, 9), cols[(i + 2) % 5])
		draw_rect(Rect2(ix, py + ph - 16, iw, 10), Color(0.10, 0.16, 0.26))
		draw_rect(Rect2(ix, py + ph - 16, iw * (pip_pct / 100.0), 10), Color(0.29, 0.87, 0.50))

	# 4. Jet de GO! 2 Style Mini-Map Radar (Bottom-Right above D-Pad) & Top-Right Heading Compass
	if false:
		var rcx := W - 46.0
		var rcy := 88.0
		var rr := 28.0
		draw_circle(Vector2(rcx, rcy), rr, Color(0.06, 0.11, 0.18, 0.78))
		draw_arc(Vector2(rcx, rcy), rr, 0.0, TAU, 32, Color(0.35, 0.68, 0.92, 0.85), 2.0)
		var ha := deg_to_rad(-90.0 + hdg_deg)
		draw_line(Vector2(rcx, rcy), Vector2(rcx + cos(ha) * rr * 0.75, rcy + sin(ha) * rr * 0.75), Color(0.99, 0.86, 0.25), 2.5)

		# Mini-Map Runway & Aircraft Position
		var mx := W - 120.0
		var my := 64.0
		var mw := 58.0
		var mh := 52.0
		draw_rect(Rect2(mx, my, mw, mh), Color(0.04, 0.12, 0.08, 0.76))
		draw_rect(Rect2(mx, my, mw, mh), Color(0.28, 0.96, 0.46, 0.75), false, 1.5)
		draw_line(Vector2(mx + mw * 0.5, my + 8.0), Vector2(mx + mw * 0.5, my + mh - 8.0), Color(0.85, 0.90, 0.95), 3.0)
		var ap_x := clampf(mx + mw * 0.5 + plane_px * 0.12, mx + 6.0, mx + mw - 6.0)
		var ap_y := clampf(my + mh * 0.5 + plane_pz * 0.015, my + 6.0, my + mh - 6.0)
		draw_circle(Vector2(ap_x, ap_y), 3.5, Color(0.28, 0.96, 0.46))

	# 5. Flashing Caution / Stall Warning Box
	if warn_text != "" and int(t * 4.0) % 2 == 0:
		draw_rect(Rect2(W * 0.5 - 140.0, 68.0, 280.0, 32.0), Color(0.88, 0.16, 0.16, 0.92))
		draw_rect(Rect2(W * 0.5 - 140.0, 68.0, 280.0, 32.0), Color(0.99, 0.88, 0.22), false, 2.0)
