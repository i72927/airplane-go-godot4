extends Node3D

var planes: Array[Dictionary] = []
var airlines: Array[Dictionary] = []
var airports: Array[Dictionary] = []
var builder := AirportBuilder.new()
var audio: AudioSynth

# 3D Scene Nodes
var world_env: WorldEnvironment
var sun: DirectionalLight3D
var airport_root: Node3D
var plane_root: Node3D
var gear_root: Node3D
var nose_gear: Node3D
var main_gear_l: Node3D
var main_gear_r: Node3D
var gear_anim: float = 0.0
var flap_l: MeshInstance3D
var flap_r: MeshInstance3D
var flap_anim: float = 0.0
var smoke_particles: CPUParticles3D
var cruise_root: Node3D
var cloud_root: Node3D
var rain_particles: GPUParticles3D
var chase_cam: Camera3D
var cockpit_cam: Camera3D

# UI Nodes
var ui_layer: CanvasLayer
var overlay: CockpitOverlay
var lbl_time: Label
var lbl_spd: Label
var lbl_alt: Label
var lbl_led: Label
var lbl_pip_title: Label
var btn_atc: Button
var btn_gear: Button
var btn_flaps: Button
var btn_wiper: Button
var btn_cam: Button
var slider_thr: VSlider
var setup_panel: PanelContainer
var result_panel: PanelContainer
var opt_plane: OptionButton
var opt_airline: OptionButton
var opt_dep: OptionButton
var opt_arr: OptionButton
var opt_weather: OptionButton
var lbl_route_desc: Label
var lbl_res_body: Label

# Simulation State
var running: bool = false
var phase: String = "DEMO"
var cur_plane: Dictionary
var cur_airline: Dictionary
var dep_apt: Dictionary
var arr_apt: Dictionary
var weather: String = "day"
var cam_is_cockpit: bool = false
var wiper_mode: int = 0
var wiper_angle: float = -1.0

var time_left: float = 150.0
var throttle: float = 0.0
var brake_held: bool = false
var gear_down: bool = true
var flap_idx: int = 0

var speed: float = 0.0
var alt: float = 0.0
var pitch: float = 0.0
var roll: float = 0.0
var yaw: float = 0.0
var px: float = 0.0
var py: float = 3.5
var pz: float = 0.0

var board_pct: float = 0.0
var push_pct: float = 0.0
var atc_ready: bool = false
var atc_count: int = 0
var clean_bonus: bool = false
var v1_called: bool = false
var vr_called: bool = false
var v2_called: bool = false
var v_callout_cd: float = 0.0
var touchdown_done: bool = false
var ra_flags: Dictionary = {}
var warn_cd: float = 0.0
var landing_vsi: float = 0.0
var landing_offset: float = 0.0
var cruise_gates: Array[Dictionary] = []
var parkour_vy: float = 0.0
var parkour_clouds: Array[Dictionary] = []
var t: float = 0.0

var steer_left: bool = false
var steer_right: bool = false
var steer_up: bool = false
var steer_down: bool = false

func _ready() -> void:
	planes = AirportData.get_planes()
	airlines = AirportData.get_airlines()
	airports = AirportData.get_airports()
	cur_plane = planes[0]
	cur_airline = airlines[0]
	dep_apt = airports[0]
	arr_apt = airports[1]

	_setup_3d_world()
	_setup_audio()
	_setup_ui()
	_apply_weather()
	_load_aircraft_model()
	airport_root.visible = true
	gear_anim = 0.0
	flap_anim = 0.0
	builder.build(airport_root, dep_apt, weather)
	_build_clouds()
	_update_route_preview()

func _setup_3d_world() -> void:
	world_env = WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.65
	env.glow_bloom = 0.18
	env.fog_enabled = true
	world_env.environment = env
	add_child(world_env)

	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-42, -30, 0)
	add_child(sun)

	airport_root = Node3D.new()
	add_child(airport_root)

	plane_root = Node3D.new()
	add_child(plane_root)

	cruise_root = Node3D.new()
	add_child(cruise_root)

	cloud_root = Node3D.new()
	add_child(cloud_root)

	chase_cam = Camera3D.new()
	chase_cam.fov = 56.0
	chase_cam.far = 14000.0
	chase_cam.current = true
	add_child(chase_cam)

	cockpit_cam = Camera3D.new()
	cockpit_cam.fov = 62.0
	cockpit_cam.far = 14000.0
	add_child(cockpit_cam)

	# 3D Rain GPU Particle System
	rain_particles = GPUParticles3D.new()
	rain_particles.amount = 1400
	rain_particles.lifetime = 0.9
	rain_particles.visibility_aabb = AABB(Vector3(-80, -40, -80), Vector3(160, 120, 160))
	var pmat := ParticleProcessMaterial.new()
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pmat.emission_box_extents = Vector3(65, 35, 65)
	pmat.direction = Vector3(-0.15, -1.0, 0.0)
	pmat.initial_velocity_min = 65.0
	pmat.initial_velocity_max = 85.0
	pmat.gravity = Vector3(0, -40, 0)
	rain_particles.process_material = pmat
	var rmesh := BoxMesh.new()
	rmesh.size = Vector3(0.08, 2.2, 0.08)
	var rm_mat := StandardMaterial3D.new()
	rm_mat.albedo_color = Color(0.8, 0.88, 0.98, 0.55)
	rm_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rmesh.material = rm_mat
	rain_particles.draw_pass_1 = rmesh
	rain_particles.emitting = false
	add_child(rain_particles)

func _setup_audio() -> void:
	audio = AudioSynth.new()
	add_child(audio)

func _load_aircraft_model() -> void:
	for c in plane_root.get_children():
		c.queue_free()

	var scene_res := load(cur_plane["model"]) as PackedScene
	if scene_res != null:
		var model: Node3D = scene_res.instantiate() as Node3D
		var liv_tex := load(cur_airline["livery"]) as Texture2D
		if liv_tex != null:
			_apply_livery_recursive(model, liv_tex)
		plane_root.add_child(model)

	# Wingtip Navigation Lights (Red Port, Green Starboard) & Forward Landing Light
	var nav_l := MeshInstance3D.new()
	var nav_sm := SphereMesh.new(); nav_sm.radius = 0.35; nav_sm.height = 0.7
	nav_l.mesh = nav_sm
	var nav_mat_l := StandardMaterial3D.new(); nav_mat_l.albedo_color = Color(1.0, 0.15, 0.15); nav_mat_l.emission_enabled = true; nav_mat_l.emission = Color(1.0, 0.15, 0.15); nav_mat_l.emission_energy_multiplier = 4.0
	nav_l.material_override = nav_mat_l; nav_l.position = Vector3(-18.0, 0.6, 2.5)
	plane_root.add_child(nav_l)

	var nav_r := MeshInstance3D.new()
	nav_r.mesh = nav_sm
	var mr := StandardMaterial3D.new(); mr.albedo_color = Color(0.15, 1.0, 0.35); mr.emission_enabled = true; mr.emission = Color(0.15, 1.0, 0.35); mr.emission_energy_multiplier = 4.0
	nav_r.material_override = mr; nav_r.position = Vector3(18.0, 0.6, 2.5)
	plane_root.add_child(nav_r)

	var spot := SpotLight3D.new()
	spot.light_energy = 6.5 if (weather == "night" or weather == "rain") else 1.5
	spot.spot_range = 260.0
	spot.spot_angle = 26.0
	spot.position = Vector3(0.0, -1.2, -14.0)
	plane_root.add_child(spot)

	# Articulated Extending Flaps (Clearly visible when extended/retracted)
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.26, 0.30, 0.36)
	fmat.metallic = 0.35
	var ftrim_mat := StandardMaterial3D.new()
	ftrim_mat.albedo_color = Color(0.95, 0.48, 0.12)
	var fm := BoxMesh.new()
	fm.size = Vector3(10.5, 0.32, 2.1)
	var ftrim_m := BoxMesh.new()
	ftrim_m.size = Vector3(10.5, 0.14, 0.35)

	flap_l = MeshInstance3D.new()
	flap_l.mesh = fm
	flap_l.material_override = fmat
	flap_l.position = Vector3(-8.5, -0.8, 2.2)
	var trim_l := MeshInstance3D.new()
	trim_l.mesh = ftrim_m; trim_l.material_override = ftrim_mat; trim_l.position = Vector3(0.0, 0.08, 1.05)
	flap_l.add_child(trim_l)
	plane_root.add_child(flap_l)

	flap_r = MeshInstance3D.new()
	flap_r.mesh = fm
	flap_r.material_override = fmat
	flap_r.position = Vector3(8.5, -0.8, 2.2)
	var trim_r := MeshInstance3D.new()
	trim_r.mesh = ftrim_m; trim_r.material_override = ftrim_mat; trim_r.position = Vector3(0.0, 0.08, 1.05)
	flap_r.add_child(trim_r)
	plane_root.add_child(flap_r)

	# Retractable 3D Landing Gear Bogies with Individual Pivot Nodes
	gear_root = Node3D.new()
	var gh: float = cur_plane["gear_height"]
	var strut_m := StandardMaterial3D.new()
	strut_m.albedo_color = Color(0.62, 0.66, 0.72)
	strut_m.metallic = 0.7
	var tire_m := StandardMaterial3D.new()
	tire_m.albedo_color = Color(0.08, 0.09, 0.11)

	var gear_pivots := [
		Vector3(0, 0, float(cur_plane["cockpit_z"]) * 0.75),
		Vector3(-4.2, 0, 1.8),
		Vector3(4.2, 0, 1.8)
	]
	var g_nodes: Array[Node3D] = []
	for piv in gear_pivots:
		var gn := Node3D.new()
		gn.position = piv
		var st := MeshInstance3D.new()
		var sm := CylinderMesh.new()
		sm.top_radius = 0.22; sm.bottom_radius = 0.22; sm.height = gh
		st.mesh = sm; st.material_override = strut_m
		st.position = Vector3(0, -gh * 0.5, 0)
		gn.add_child(st)
		for wx in [-0.55, 0.55]:
			var wh := MeshInstance3D.new()
			var wm := CylinderMesh.new()
			wm.top_radius = 0.8; wm.bottom_radius = 0.8; wm.height = 0.42
			wh.mesh = wm; wh.material_override = tire_m
			wh.rotation.z = PI * 0.5
			wh.position = Vector3(wx, -gh * 0.95, 0)
			gn.add_child(wh)
		gear_root.add_child(gn)
		g_nodes.append(gn)
	nose_gear = g_nodes[0]
	main_gear_l = g_nodes[1]
	main_gear_r = g_nodes[2]
	plane_root.add_child(gear_root)

	# Touchdown Tire Friction Smoke Particles
	smoke_particles = CPUParticles3D.new()
	smoke_particles.emitting = false
	smoke_particles.one_shot = true
	smoke_particles.explosiveness = 0.85
	smoke_particles.amount = 42
	smoke_particles.lifetime = 1.4
	smoke_particles.position = Vector3(0.0, -gh + 0.3, 2.2)
	smoke_particles.direction = Vector3(0.0, 0.35, 1.0)
	smoke_particles.spread = 32.0
	smoke_particles.initial_velocity_min = 18.0
	smoke_particles.initial_velocity_max = 36.0
	smoke_particles.gravity = Vector3(0.0, 1.8, 0.0)
	var smk_mesh := SphereMesh.new(); smk_mesh.radius = 1.2; smk_mesh.height = 2.4
	var smk_mat := StandardMaterial3D.new()
	smk_mat.albedo_color = Color(0.90, 0.92, 0.95, 0.65)
	smk_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smk_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smk_mesh.material = smk_mat
	smoke_particles.mesh = smk_mesh
	plane_root.add_child(smoke_particles)

func _build_clouds() -> void:
	for c in cloud_root.get_children():
		c.queue_free()
	var base_col := Color(0.98, 0.76, 0.55) if weather == "dusk" else (Color(0.42, 0.48, 0.56) if weather == "rain" else Color(0.98, 0.99, 1.0))
	var shd_col := Color(0.72, 0.48, 0.46) if weather == "dusk" else (Color(0.28, 0.34, 0.42) if weather == "rain" else Color(0.74, 0.82, 0.92))
	var alpha_val := 0.25 if weather == "night" else 0.88

	var cm_top := StandardMaterial3D.new()
	cm_top.albedo_color = Color(base_col.r, base_col.g, base_col.b, alpha_val)
	cm_top.roughness = 1.0
	cm_top.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var cm_bot := StandardMaterial3D.new()
	cm_bot.albedo_color = Color(shd_col.r, shd_col.g, shd_col.b, alpha_val * 0.9)
	cm_bot.roughness = 1.0
	cm_bot.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var sm := SphereMesh.new(); sm.radius = 58.0; sm.height = 44.0
	# 1. Towering Multi-Lobe Cumulus Clusters
	for i in range(24):
		var grp := Node3D.new()
		grp.position = Vector3(randf_range(-2400, 2400), randf_range(360, 620), randf_range(-4200, 900))
		for lobe in range(4):
			var cl := MeshInstance3D.new()
			cl.mesh = sm
			cl.material_override = cm_bot if lobe == 0 else cm_top
			cl.scale = Vector3(randf_range(1.1, 2.2), randf_range(0.6, 1.5), randf_range(1.0, 1.9))
			cl.position = Vector3(randf_range(-65, 65), lobe * 18.0, randf_range(-55, 55))
			grp.add_child(cl)
		cloud_root.add_child(grp)
	# 2. Flat Layered Stratus Sheets
	for i in range(16):
		var st := MeshInstance3D.new()
		st.mesh = sm; st.material_override = cm_bot
		st.scale = Vector3(randf_range(3.2, 5.5), 0.22, randf_range(2.2, 3.8))
		st.position = Vector3(randf_range(-2600, 2600), randf_range(420, 560), randf_range(-4200, 800))
		cloud_root.add_child(st)
	# 3. High-Altitude Wispy Cirrus Streaks
	for i in range(18):
		var ci := MeshInstance3D.new()
		ci.mesh = sm; ci.material_override = cm_top
		ci.scale = Vector3(randf_range(0.6, 1.1), 0.14, randf_range(4.5, 7.5))
		ci.rotation.y = randf_range(-0.4, 0.4)
		ci.position = Vector3(randf_range(-2600, 2600), randf_range(760, 960), randf_range(-4400, 900))
		cloud_root.add_child(ci)

func _apply_weather() -> void:
	var env := world_env.environment
	var sky_mat := env.sky.sky_material as ProceduralSkyMaterial
	if weather == "dusk":
		sky_mat.sky_top_color = Color(0.12, 0.11, 0.30)
		sky_mat.sky_horizon_color = Color(0.94, 0.44, 0.14)
		sky_mat.ground_horizon_color = Color(0.55, 0.24, 0.12)
		sun.light_color = Color(1.0, 0.62, 0.28)
		sun.light_energy = 1.4
		sun.rotation_degrees = Vector3(-12, -55, 0)
		env.fog_light_color = Color(0.85, 0.42, 0.20)
		env.fog_density = 0.00028
	elif weather == "night":
		sky_mat.sky_top_color = Color(0.01, 0.02, 0.06)
		sky_mat.sky_horizon_color = Color(0.04, 0.08, 0.18)
		sky_mat.ground_horizon_color = Color(0.02, 0.04, 0.09)
		sun.light_color = Color(0.55, 0.72, 1.0)
		sun.light_energy = 0.42
		sun.rotation_degrees = Vector3(-50, 20, 0)
		env.fog_light_color = Color(0.04, 0.08, 0.16)
		env.fog_density = 0.00032
	elif weather == "rain":
		sky_mat.sky_top_color = Color(0.16, 0.21, 0.28)
		sky_mat.sky_horizon_color = Color(0.32, 0.39, 0.47)
		sky_mat.ground_horizon_color = Color(0.22, 0.27, 0.33)
		sun.light_color = Color(0.75, 0.82, 0.90)
		sun.light_energy = 0.65
		sun.rotation_degrees = Vector3(-55, -20, 0)
		env.fog_light_color = Color(0.32, 0.38, 0.45)
		env.fog_density = 0.00062
	else:
		sky_mat.sky_top_color = Color(0.12, 0.42, 0.82)
		sky_mat.sky_horizon_color = Color(0.64, 0.86, 0.98)
		sky_mat.ground_horizon_color = Color(0.52, 0.72, 0.84)
		sun.light_color = Color(1.0, 0.98, 0.92)
		sun.light_energy = 1.5
		sun.rotation_degrees = Vector3(-44, -32, 0)
		env.fog_light_color = Color(0.72, 0.88, 0.98)
		env.fog_density = 0.00016
	rain_particles.emitting = (weather == "rain")

func _setup_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)

	overlay = CockpitOverlay.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(overlay)

	# Top HUD Bar
	var top_bar := HBoxContainer.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_left = 12
	top_bar.offset_right = -12
	top_bar.offset_top = 8
	top_bar.offset_bottom = 48
	top_bar.add_theme_constant_override("separation", 12)
	ui_layer.add_child(top_bar)

	lbl_time = _hud_label("TIME 150.0s", Color(1.0, 0.88, 0.28))
	lbl_spd = _hud_label("SPD 0 KT", Color(0.22, 0.74, 0.97))
	lbl_alt = _hud_label("ALT 0 FT", Color(0.29, 0.87, 0.50))
	lbl_led = _hud_label("飛機GO！Godot 4 3D 航空模擬・請選擇航線出發", Color(1.0, 0.95, 0.65))
	lbl_led.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_led.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_bar.add_child(lbl_time)
	top_bar.add_child(lbl_spd)
	top_bar.add_child(lbl_alt)
	top_bar.add_child(lbl_led)

	var btn_menu := Button.new()
	btn_menu.text = "⚙ 航線選單"
	btn_menu.pressed.connect(_open_menu)
	top_bar.add_child(btn_menu)

	# PiP Title label
	lbl_pip_title = Label.new()
	lbl_pip_title.position = Vector2(24, 72)
	lbl_pip_title.add_theme_color_override("font_color", Color(0.49, 0.83, 0.99))
	lbl_pip_title.visible = false
	ui_layer.add_child(lbl_pip_title)

	# Bottom Touch / Mouse Controls
	var bot := HBoxContainer.new()
	bot.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bot.offset_left = 16
	bot.offset_right = -16
	bot.offset_top = -132
	bot.offset_bottom = -12
	bot.add_theme_constant_override("separation", 12)
	ui_layer.add_child(bot)

	slider_thr = VSlider.new()
	slider_thr.min_value = 0.0
	slider_thr.max_value = 100.0
	slider_thr.custom_minimum_size = Vector2(44, 110)
	slider_thr.value_changed.connect(func(v: float): throttle = v / 100.0)
	bot.add_child(slider_thr)

	var left_col := VBoxContainer.new()
	var btn_toga := Button.new()
	btn_toga.text = "推滿起飛"
	btn_toga.custom_minimum_size = Vector2(92, 48)
	btn_toga.pressed.connect(func():
		throttle = 0.0 if throttle >= 0.95 else 1.0
		slider_thr.value = throttle * 100.0
	)
	var btn_brk := Button.new()
	btn_brk.text = "煞車 / 反推"
	btn_brk.custom_minimum_size = Vector2(92, 54)
	btn_brk.button_down.connect(func(): brake_held = true)
	btn_brk.button_up.connect(func(): brake_held = false)
	left_col.add_child(btn_toga)
	left_col.add_child(btn_brk)
	bot.add_child(left_col)

	var spacer1 := Control.new()
	spacer1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bot.add_child(spacer1)

	btn_atc = Button.new()
	btn_atc.text = "📡 塔台聯絡"
	btn_atc.custom_minimum_size = Vector2(128, 60)
	btn_atc.pressed.connect(_on_atc_pressed)
	bot.add_child(btn_atc)

	btn_gear = Button.new()
	btn_gear.text = "起落架：放下"
	btn_gear.custom_minimum_size = Vector2(118, 60)
	btn_gear.pressed.connect(_on_gear_pressed)
	bot.add_child(btn_gear)

	btn_flaps = Button.new()
	btn_flaps.text = "襟翼：0"
	btn_flaps.custom_minimum_size = Vector2(96, 60)
	btn_flaps.pressed.connect(_on_flaps_pressed)
	bot.add_child(btn_flaps)

	btn_wiper = Button.new()
	btn_wiper.text = "雨刷：關"
	btn_wiper.custom_minimum_size = Vector2(92, 60)
	btn_wiper.pressed.connect(_on_wiper_pressed)
	bot.add_child(btn_wiper)

	btn_cam = Button.new()
	btn_cam.text = "👁 機尾後方"
	btn_cam.custom_minimum_size = Vector2(112, 60)
	btn_cam.pressed.connect(_on_cam_pressed)
	bot.add_child(btn_cam)

	var spacer2 := Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bot.add_child(spacer2)

	# Steering Pad
	var pad := GridContainer.new()
	pad.columns = 3
	pad.add_child(Control.new())
	var b_up := _steer_btn("俯↓", func(d): steer_up = d)
	pad.add_child(b_up)
	pad.add_child(Control.new())
	pad.add_child(_steer_btn("◀", func(d): steer_left = d))
	pad.add_child(Control.new())
	pad.add_child(_steer_btn("▶", func(d): steer_right = d))
	pad.add_child(Control.new())
	pad.add_child(_steer_btn("仰↑", func(d): steer_down = d))
	pad.add_child(Control.new())
	bot.add_child(pad)

	_build_setup_panel()
	_build_result_panel()

func _hud_label(txt: String, col: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.96))
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_font_size_override("font_size", 18)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.05, 0.09, 0.88)
	sb.border_color = Color(0.28, 0.36, 0.48, 0.85)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(6)
	l.add_theme_stylebox_override("normal", sb)
	return l

func _steer_btn(txt: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(44, 36)
	b.button_down.connect(func(): cb.call(true))
	b.button_up.connect(func(): cb.call(false))
	return b

func _build_setup_panel() -> void:
	setup_panel = PanelContainer.new()
	setup_panel.set_anchors_preset(Control.PRESET_CENTER)
	setup_panel.custom_minimum_size = Vector2(680, 380)
	setup_panel.offset_left = -340
	setup_panel.offset_top = -190
	ui_layer.add_child(setup_panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	setup_panel.add_child(vb)

	var title := Label.new()
	title.text = "✈️ 飛機GO！Godot 4 專屬 3D 航空模擬"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.28))
	vb.add_child(title)

	opt_airline = OptionButton.new()
	for al in airlines:
		opt_airline.add_item("航空公司：" + al["name"])
	opt_airline.item_selected.connect(func(_i): _update_route_preview())
	vb.add_child(opt_airline)

	opt_plane = OptionButton.new()
	for p in planes:
		opt_plane.add_item(p["name"])
	opt_plane.item_selected.connect(func(_i): _update_route_preview())
	vb.add_child(opt_plane)

	var row_apt := HBoxContainer.new()
	opt_dep = OptionButton.new()
	opt_arr = OptionButton.new()
	opt_dep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt_arr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for a in airports:
		var s := "%s (%s・%dm)" % [a["name"], a["code"], a["len"]]
		opt_dep.add_item("出發：" + s)
		opt_arr.add_item("目的：" + s)
	opt_dep.selected = 0
	opt_arr.selected = 1
	opt_dep.item_selected.connect(func(_i): _update_route_preview())
	opt_arr.item_selected.connect(func(_i): _update_route_preview())
	row_apt.add_child(opt_dep)
	row_apt.add_child(opt_arr)
	vb.add_child(row_apt)

	opt_weather = OptionButton.new()
	opt_weather.add_item("☀️ 白天晴空")
	opt_weather.add_item("🌅 黃昏夕陽")
	opt_weather.add_item("🌙 夜晚燈海")
	opt_weather.add_item("🌧️ 雨天（自動啟用駕駛艙雨刷）")
	opt_weather.item_selected.connect(func(_i): _update_route_preview())
	vb.add_child(opt_weather)

	lbl_route_desc = Label.new()
	lbl_route_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(lbl_route_desc)

	var btn_go := Button.new()
	btn_go.text = "✈️ 開始登機整備・執飛本班機"
	btn_go.custom_minimum_size = Vector2(0, 50)
	btn_go.pressed.connect(_start_flight)
	vb.add_child(btn_go)

func _build_result_panel() -> void:
	result_panel = PanelContainer.new()
	result_panel.set_anchors_preset(Control.PRESET_CENTER)
	result_panel.custom_minimum_size = Vector2(540, 280)
	result_panel.offset_left = -270
	result_panel.offset_top = -140
	result_panel.visible = false
	ui_layer.add_child(result_panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	result_panel.add_child(vb)
	var t_lbl := Label.new()
	t_lbl.text = "🏁 航班任務完成・旅客下機完畢"
	t_lbl.add_theme_font_size_override("font_size", 22)
	t_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.28))
	vb.add_child(t_lbl)
	lbl_res_body = Label.new()
	lbl_res_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(lbl_res_body)
	var btn_re := Button.new()
	btn_re.text = "🔄 返回航線選單・再飛一趟"
	btn_re.custom_minimum_size = Vector2(0, 48)
	btn_re.pressed.connect(_open_menu)
	vb.add_child(btn_re)

func _update_route_preview() -> void:
	cur_airline = airlines[opt_airline.selected]
	cur_plane = planes[opt_plane.selected]
	dep_apt = airports[opt_dep.selected]
	var ai := opt_arr.selected
	if ai == opt_dep.selected:
		ai = (ai + 1) % airports.size()
		opt_arr.selected = ai
	arr_apt = airports[ai]
	weather = ["day", "dusk", "night", "rain"][opt_weather.selected]
	lbl_route_desc.text = "執飛：%s・航線：%s (%s 跑道 %s) ➔ %s (%s 跑道 %s・%dm)\n出發實景：%s\n進場實景：%s" % [
		cur_airline["name"],
		dep_apt["name"], dep_apt["code"], dep_apt["rwy"],
		arr_apt["name"], arr_apt["code"], arr_apt["rwy"], arr_apt["len"],
		dep_apt["desc"], arr_apt["desc"]
	]
	if not running:
		_apply_weather()
		_load_aircraft_model()
		airport_root.visible = true
		gear_anim = 0.0
		flap_anim = 0.0
		builder.build(airport_root, dep_apt, weather)
		_build_clouds()

func _open_menu() -> void:
	running = false
	phase = "DEMO"
	audio.active = false
	overlay.show_pip = false
	lbl_pip_title.visible = false
	result_panel.visible = false
	setup_panel.visible = true

func _start_flight() -> void:
	_update_route_preview()
	_apply_weather()
	_load_aircraft_model()
	airport_root.visible = true
	gear_anim = 0.0
	flap_anim = 0.0
	builder.build(airport_root, dep_apt, weather)
	_build_clouds()

	running = true
	audio.active = true
	phase = "GATE_BOARD"
	time_left = 150.0 if (dep_apt["code"] == "KHH" and arr_apt["code"] == "MZG") else 180.0
	throttle = 0.0
	slider_thr.value = 0.0
	brake_held = false
	gear_down = true
	flap_idx = 0
	speed = 0.0
	alt = 0.0
	pitch = 0.0
	roll = 0.0
	px = 146.0
	py = cur_plane["gear_height"]
	pz = 128.0
	yaw = -PI * 0.5
	board_pct = 0.0
	push_pct = 0.0
	atc_ready = false
	atc_count = 0
	clean_bonus = false
	v1_called = false
	vr_called = false
	v2_called = false
	v_callout_cd = 0.0
	touchdown_done = false
	ra_flags.clear()
	wiper_mode = 1 if weather == "rain" else 0

	setup_panel.visible = false
	result_panel.visible = false
	overlay.show_pip = true
	overlay.pip_is_boarding = true
	lbl_pip_title.visible = true
	lbl_pip_title.text = "🚶 旅客登機中 0%"
	lbl_led.text = "%s 停機坪・空橋旅客登機中" % dep_apt["name"]
	_refresh_buttons()
	audio.speak_mandarin("各位旅客您好，歡迎搭乘%s，本班機由%s飛往%s，目前正在登機作業。" % [cur_airline["callsign"], dep_apt["name"], arr_apt["name"]])

func _on_atc_pressed() -> void:
	if not atc_ready:
		return
	atc_ready = false
	atc_count += 1
	time_left += 3.0
	audio.play_chime("atc")
	if phase == "PUSHBACK_WAIT":
		phase = "PUSHBACK"
		push_pct = 0.0
		lbl_led.text = "塔台許可後推 (+3s)・黃色拖車作業中"
		audio.speak_mandarin("塔台您好，旅客已登機完畢，請求後推。收到，許可後推並啟動發動機。")
	elif phase == "TAXI_WAIT":
		phase = "TAXI_OUT"
		px = 135.0
		pz = 128.0
		yaw = 0.0
		lbl_led.text = "許可滑行 (+3s)！請輕推油門沿綠燈滑行道滑至 %s 跑道頭" % dep_apt["rwy"]
		audio.speak_mandarin("塔台許可滑行至%s跑道頭等待，請注意滑行速限。" % dep_apt["rwy"])
	elif phase == "TAKEOFF_WAIT":
		phase = "TAKEOFF"
		px = 0.0
		pz = -18.0
		yaw = 0.0
		if flap_idx == 0:
			flap_idx = 1
		lbl_led.text = "許可起飛 (+3s)！推滿油門加速至 %d KT 按「仰↑」離地" % int(cur_plane["vr"])
		audio.speak_mandarin("許可進入%s跑道起飛，祝您一路順風。" % dep_apt["rwy"])
	elif phase == "PARKOUR":
		_enter_approach()
		return
	if false:
		airport_root.visible = true
		builder.build(airport_root, arr_apt, weather)
		_spawn_approach_gates()
		for c in cruise_root.get_children():
			c.queue_free()
		px = randf_range(-28.0, 28.0)
		py = 175.0
		alt = 1650.0
		pz = 1850.0
		speed = 185.0
		pitch = -2.0
		roll = 0.0
		yaw = 0.0
		lbl_led.text = "進場 %s %s 跑道・對準黃色 ILS 十字並放起落架與襟翼" % [arr_apt["name"], arr_apt["rwy"]]
		audio.speak_mandarin("已移交%s塔台，許可進場%s跑道降落，請確認放下起落架與襟翼。" % [arr_apt["name"], arr_apt["rwy"]])
	elif phase == "LANDED_WAIT":
		phase = "TAXI_IN"
		px = 110.0
		pz = -10.0
		yaw = PI
		lbl_led.text = "許可滑回 %s 停機坪・請輕推油門滑行" % arr_apt["name"]
		audio.speak_mandarin("歡迎抵達%s，請滑行進入停機坪。" % arr_apt["name"])
	_refresh_buttons()

func _on_gear_pressed() -> void:
	if alt < 35.0 and gear_down:
		return
	gear_down = not gear_down
	_refresh_buttons()

func _on_flaps_pressed() -> void:
	flap_idx = (flap_idx + 1) % cur_plane["flaps"].size()
	_refresh_buttons()

func _on_wiper_pressed() -> void:
	wiper_mode = (wiper_mode + 1) % 3
	_refresh_buttons()

func _on_cam_pressed() -> void:
	cam_is_cockpit = not cam_is_cockpit
	chase_cam.current = not cam_is_cockpit
	cockpit_cam.current = cam_is_cockpit
	_refresh_buttons()

func _refresh_buttons() -> void:
	btn_gear.text = "起落架：" + ("放下🟢🟢🟢" if gear_down else "收起")
	btn_flaps.text = "襟翼：" + str(cur_plane["flaps"][flap_idx])
	btn_wiper.text = "雨刷：" + ["關", "慢速", "高速"][wiper_mode]
	btn_cam.text = "👁 駕駛艙" if cam_is_cockpit else "👁 機尾後方"
	btn_atc.modulate = Color(0.45, 1.0, 0.55) if atc_ready else Color(1, 1, 1)

func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	t += dt
	for h in builder.wind_hubs:
		h.rotation.z -= dt * 1.4

	if wiper_mode > 0:
		wiper_angle = sin(t * (3.5 if wiper_mode == 1 else 6.5))
	else:
		wiper_angle = lerpf(wiper_angle, -1.0, dt * 6.0)

	# Keyboard support
	var kb_l := Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A)
	var kb_r := Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D)
	var kb_u := Input.is_key_pressed(KEY_UP)
	var kb_d := Input.is_key_pressed(KEY_DOWN)
	if running and Input.is_key_pressed(KEY_W):
		throttle = clampf(throttle + dt * 0.5, 0.0, 1.0)
		slider_thr.value = throttle * 100.0
	if running and Input.is_key_pressed(KEY_S):
		throttle = clampf(throttle - dt * 0.5, 0.0, 1.0)
		slider_thr.value = throttle * 100.0
	var is_brk := brake_held or Input.is_key_pressed(KEY_B)

	if not running:
		plane_root.visible = true
		plane_root.position = Vector3(0, 16.0 + sin(t) * 1.2, 260.0 - fmod(t * 45.0, 480.0))
		plane_root.rotation = Vector3(0, 0, sin(t * 0.7) * 0.05)
		chase_cam.position = Vector3(26.0, 26.0, plane_root.position.z + 52.0)
		chase_cam.look_at(Vector3(0, 14.0, plane_root.position.z - 80.0))
		overlay.queue_redraw()
		return

	if phase not in ["GATE_BOARD", "GATE_DEPLANE", "RESULT"]:
		time_left = maxf(0.0, time_left - dt)

	var wet := 0.78 if weather == "rain" else 1.0
	var steer_in := (1.0 if (steer_right or kb_r) else 0.0) - (1.0 if (steer_left or kb_l) else 0.0)
	var pitch_in := (1.0 if (steer_down or kb_d) else 0.0) - (1.0 if (steer_up or kb_u) else 0.0)

	if phase == "GATE_BOARD":
		board_pct = minf(100.0, board_pct + dt * 22.0)
		lbl_pip_title.text = "🚶 旅客登機中 %d%%" % int(board_pct)
		if board_pct >= 100.0:
			overlay.show_pip = false
			lbl_pip_title.visible = false
			phase = "PUSHBACK_WAIT"
			atc_ready = true
			lbl_led.text = "登機完成！請點擊發光的「📡 塔台聯絡」請求後推"
			_refresh_buttons()
	elif phase == "PUSHBACK":
		push_pct = minf(100.0, push_pct + dt * 26.0)
		var f := push_pct / 100.0
		speed = 6.0
		px = 186.0 - f * 51.0
		yaw = -PI * 0.5 * (1.0 - f)
		if builder.jetbridge != null:
			builder.jetbridge.position.x = 172.0 + f * 20.0
		if builder.tug_node != null:
			builder.tug_node.position = Vector3(px + 14.0 * cos(yaw), 0.0, pz - 14.0 * sin(yaw))
		if push_pct >= 100.0:
			phase = "TAXI_OUT"
			px = 135.0
			pz = 128.0
			yaw = 0.0
			speed = 8.0
			lbl_led.text = "後推完成！請沿黃色箭頭滑行進入 %s 跑道起飛" % dep_apt["rwy"]
			audio.speak_mandarin("後推完成，請沿滑行道直接進入跑道起飛。")
			_refresh_buttons()
	elif phase == "TAXI_OUT" or phase == "TAXI_IN":
		var tspd := throttle * 36.0
		speed = maxf(0.0, speed - 25.0 * wet * dt) if is_brk else lerpf(speed, tspd, dt * 1.8)
		yaw -= steer_in * maxf(minf(speed, 18.0), 4.0) * 0.065 * dt
		var mv := speed * 0.514 * dt * 2.2
		px = clampf(px - sin(yaw) * mv, -18.0, 155.0)
		pz = clampf(pz - cos(yaw) * mv, -45.0, 150.0)
		if phase == "TAXI_OUT" and pz <= 8.0 and absf(px) <= 22.0:
			px = 0.0
			pz = -18.0
			yaw = 0.0
			flap_idx = 1
			phase = "TAKEOFF"
			time_left += 5.0
			lbl_led.text = "進入 %s 跑道 (+5s)！推滿油門加速至 %d KT 按「仰↑」離地" % [dep_apt["rwy"], int(cur_plane["vr"])]
			audio.play_chime("atc")
			audio.speak_mandarin("已進入跑道，許可起飛。")
			_refresh_buttons()
		elif phase == "TAXI_IN" and pz >= 115.0 and px >= 120.0:
			speed = 0.0
			throttle = 0.0
			slider_thr.value = 0.0
			phase = "GATE_DEPLANE"
			board_pct = 0.0
			px = 186.0
			pz = 128.0
			yaw = -PI * 0.5
			if builder.jetbridge != null:
				builder.jetbridge.position.x = 172.0
			overlay.show_pip = true
			overlay.pip_is_boarding = false
			lbl_pip_title.visible = true
			lbl_led.text = "已停妥 %s 停機坪・旅客下機中" % arr_apt["name"]
			audio.speak_mandarin("本班機已安全抵達%s停機坪，感謝您的搭乘，請依序下機。" % arr_apt["name"])
	elif phase == "TAKEOFF":
		var acc := throttle * float(cur_plane["accel"]) - (float(flap_idx) * 0.7 + (1.0 if gear_down else 0.0)) - (float(cur_plane["brake_power"]) * wet if is_brk else 0.0)
		speed = clampf(speed + acc * dt, 0.0, 265.0)
		# V1 / Vr / V2 Takeoff Speed Voice Callouts (with 2.3s clear spacing)
		v_callout_cd = maxf(0.0, v_callout_cd - dt)
		if not v1_called and speed >= float(cur_plane["v1"]) and v_callout_cd <= 0.0:
			v1_called = true
			v_callout_cd = 2.3
			lbl_led.text = "V1（%d KT）・已達決斷速度" % int(cur_plane["v1"])
			audio.speak_mandarin("V1")
		if v1_called and not vr_called and speed >= float(cur_plane["vr"]) and v_callout_cd <= 0.0:
			vr_called = true
			v_callout_cd = 2.3
			lbl_led.text = "Vr（%d KT）・可起飛！請按「仰↑」拉桿離地" % int(cur_plane["vr"])
			audio.speak_mandarin("VR，可拉桿起飛")
		if vr_called and not v2_called and speed >= float(cur_plane["v2"]) and v_callout_cd <= 0.0:
			v2_called = true
			v_callout_cd = 2.3
			lbl_led.text = "V2（%d KT）・安全爬升速度" % int(cur_plane["v2"])
			audio.speak_mandarin("V2，安全爬升")

		if alt <= 0.0:
			px = clampf(px + steer_in * minf(speed, 90.0) * 0.14 * dt, -24.0, 24.0)
			pz -= speed * 0.514 * dt * 1.4
			pitch = minf(16.0, pitch + 14.0 * dt) if (speed >= float(cur_plane["vr"]) * 0.9 and pitch_in > 0.0) else maxf(0.0, pitch - 8.0 * dt)
			if speed >= float(cur_plane["vr"]) and pitch > 4.0:
				alt = 20.0
				py = float(cur_plane["gear_height"]) + 3.0
				time_left += 10.0
				lbl_led.text = "✈️ 平順離地 (+10s)！爬升後請收起落架與襟翼"
				audio.speak_mandarin("離地，正爬升，請收起起落架。")
		else:
			roll = lerpf(roll, steer_in * 32.0, dt * 5.5)
			pitch = clampf(pitch + pitch_in * 26.0 * float(cur_plane["pitch_rate"]) * dt, -14.0, 24.0)
			yaw -= sin(deg_to_rad(roll)) * 0.42 * dt
			alt = maxf(10.0, alt + speed * sin(deg_to_rad(pitch)) * 1.75 * dt)
			py = float(cur_plane["gear_height"]) + alt * 0.14
			var climb_mv := speed * 0.514 * dt * 1.65
			px += (sin(deg_to_rad(roll)) * 38.0 * dt) - sin(yaw) * climb_mv
			pz -= cos(yaw) * climb_mv
			if alt > 420.0 and not gear_down and flap_idx == 0 and not clean_bonus:
				clean_bonus = true
				time_left += 5.0
				lbl_led.text = "收輪收襟翼完成 (+5s)！持續爬升進入巡航"
			if alt >= 2200.0:
				phase = "PARKOUR"
				airport_root.visible = false
				alt = 28000.0
				py = 520.0
				px = 0.0
				pz = 0.0
				parkour_vy = 14.0
				speed = float(cur_plane["cruise_spd"])
				pitch = 0.0
				roll = 0.0
				yaw = 0.0
				_spawn_parkour_clouds()
				lbl_led.text = "☁️ 雲朵跑酷！點擊螢幕（或按空白鍵／仰↑）往上飛閃避積雲"
				audio.speak_mandarin("進入雲層跑酷區，點擊畫面往上飛閃避前方雲朵。")
	elif phase == "PARKOUR":
		if Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_SPACE):
			parkour_vy = 28.0
		if steer_up or kb_u:
			parkour_vy = maxf(parkour_vy, 24.0)
		parkour_vy -= 42.0 * dt
		py = clampf(py + parkour_vy * dt, 445.0, 625.0)
		if py <= 445.0 or py >= 625.0:
			parkour_vy = 0.0
		pitch = clampf(parkour_vy * 0.65, -22.0, 22.0)
		roll = lerpf(roll, steer_in * 28.0, dt * 5.0)
		px = clampf(px + sin(deg_to_rad(roll)) * 64.0 * dt, -95.0, 95.0)
		alt = 28000.0 + (py - 520.0) * 30.0
		speed = float(cur_plane["cruise_spd"])
		pz -= 92.0 * dt
		for c in parkour_clouds:
			if not c["passed"] and pz <= float(c["z"]):
				c["passed"] = true
				if absf(py - float(c["y"])) < 26.0 and absf(px - float(c["x"])) < 44.0:
					time_left = maxf(0.0, time_left - 4.0)
					parkour_vy = 14.0
					audio.play_chime("warn")
					lbl_led.text = "☁️ 擦撞積雲 (-4s)！點擊螢幕往上飛閃避"
				else:
					time_left += 2.0
					audio.play_chime("ring")
					lbl_led.text = "✨ 成功閃過積雲 (+2s)！繼續點擊往上飛"
		if pz <= -2250.0:
			_enter_approach()
	elif phase == "APPROACH":
		var gh := float(cur_plane["gear_height"])
		if not touchdown_done:
			var tspd := 122.0 + throttle * 110.0 - float(flap_idx) * 10.0 - (8.0 if gear_down else 0.0)
			speed = lerpf(speed, tspd, dt * 1.2)
			roll = lerpf(roll, steer_in * 20.0, dt * 4.0)
			pitch = clampf(pitch + pitch_in * 14.0 * dt, -10.0, 12.0)
			var vsi := (pitch - 2.3) * 140.0 + float(flap_idx) * 16.0
			py = maxf(gh, py + vsi * dt * 0.045)
			alt = maxf(0.0, (py - gh) * 9.5)
			px = clampf(px + sin(deg_to_rad(roll)) * 34.0 * dt, -75.0, 75.0)
			pz -= speed * 0.514 * dt * 1.45

			var ideal_y := maxf(gh, (pz + 160.0) * 0.085)
			for g in cruise_gates:
				if not g["hit"] and absf(pz - float(g["z"])) < 32.0:
					g["hit"] = true
					g["mesh"].visible = false
					if absf(px - float(g["x"])) < 36.0 and absf(py - float(g["y"])) < 36.0:
						time_left += 5.0
						audio.play_chime("ring")
						lbl_led.text = "🎯 通過進場引導環 (+5s)！"

			for ra in [500, 100, 50, 30, 20, 10]:
				if alt <= float(ra) and not ra_flags.has(ra):
					ra_flags[ra] = true
					audio.speak_mandarin(str(ra))
			overlay.ils_x_err = px
			overlay.ils_y_err = py - ideal_y
			var diff := py - ideal_y
			var reds := 4 if diff < -16.0 else (3 if diff < -5.0 else (2 if diff < 8.0 else (1 if diff < 20.0 else 0)))
			for i in range(builder.papi_mats.size()):
				var col := Color(0.95, 0.22, 0.22) if i < reds else Color(1, 1, 1)
				builder.papi_mats[i].albedo_color = col
				builder.papi_mats[i].emission = col

			if py <= gh + 0.15:
				py = gh
				alt = 0.0
				touchdown_done = true
				if smoke_particles != null:
					smoke_particles.restart()
				landing_vsi = absf(vsi)
				landing_offset = absf(px)
				pitch = 0.0
				roll = 0.0
				if not gear_down:
					time_left = maxf(0.0, time_left - 10.0)
					gear_down = true
					lbl_led.text = "⚠️ 未放起落架緊急展開 (-10s)！請長按「煞車 / 反推」"
				elif landing_vsi < 380.0 and landing_offset < 12.0:
					time_left += 15.0
					lbl_led.text = "🌟 奶油落地 (+15s)！請收油並長按「煞車 / 反推」減速"
				else:
					time_left += 6.0
					lbl_led.text = "✈️ 主輪接地 (+6s)！請長按「煞車 / 反推」減速"
				_refresh_buttons()
		else:
			var decel := (float(cur_plane["brake_power"]) * 1.45 * wet if is_brk else 6.5) + (1.0 - throttle) * 5.0
			speed = maxf(0.0, speed - decel * dt)
			px = clampf(px + steer_in * 10.0 * dt, -24.0, 24.0)
			pz -= speed * 0.514 * dt * 1.3
			if speed <= 22.0:
				phase = "TAXI_IN"
				if landing_offset < 6.0:
					time_left += 10.0
				lbl_led.text = "減速完成！請直接右轉經聯絡道滑回 %s 停機坪 (x=135, z=128)" % arr_apt["name"]
				audio.speak_mandarin("歡迎抵達%s，請直接右轉滑行回停機坪。" % arr_apt["name"])
				_refresh_buttons()
	elif phase == "GATE_DEPLANE":
		board_pct = minf(100.0, board_pct + dt * 24.0)
		lbl_pip_title.text = "🚶 旅客下機中 %d%%" % int(board_pct)
		if board_pct >= 100.0:
			overlay.show_pip = false
			lbl_pip_title.visible = false
			phase = "RESULT"
			running = false
			audio.active = false
			var grade := "S" if time_left >= 165.0 else ("A" if time_left >= 135.0 else ("B" if time_left >= 95.0 else "C"))
			lbl_res_body.text = "綜合評級：%s 級\n執飛航線：%s・%s ➔ %s\n最終剩餘時間：%.1f 秒\n著陸表現：%s（偏離中線 %.1f 公尺）\n塔台中文語音通話：%d 次完成" % [
				grade, cur_plane["name"], dep_apt["name"], arr_apt["name"], time_left,
				("奶油順暢" if landing_vsi < 380.0 else "平穩落地"), landing_offset, atc_count
			]
			result_panel.visible = true

	# Sync 3D Transform, Gear, Flaps & Cameras
	plane_root.position = Vector3(px, py, pz)
	plane_root.rotation = Vector3(deg_to_rad(pitch), yaw, deg_to_rad(-roll))
	gear_anim = lerpf(gear_anim, 0.0 if gear_down else 1.0, dt * 2.2)
	if gear_root != null:
		gear_root.visible = (gear_anim < 0.98)
		if nose_gear != null:
			nose_gear.rotation.x = -gear_anim * 1.45
		if main_gear_l != null and main_gear_r != null:
			main_gear_l.rotation.z = -gear_anim * 1.48
			main_gear_r.rotation.z = gear_anim * 1.48

	flap_anim = lerpf(flap_anim, 1.0 if flap_idx > 0 else 0.0, dt * 3.5)
	if flap_l != null and flap_r != null:
		flap_l.position = Vector3(-8.5, -0.8 - flap_anim * 0.55, 2.2 + flap_anim * 1.75)
		flap_r.position = Vector3(8.5, -0.8 - flap_anim * 0.55, 2.2 + flap_anim * 1.75)
		flap_l.rotation.x = flap_anim * 0.48
		flap_r.rotation.x = flap_anim * 0.48

	if builder.taxi_arrows_root != null:
		builder.taxi_arrows_root.visible = (phase in ["PUSHBACK_WAIT", "PUSHBACK", "TAXI_WAIT", "TAXI_OUT", "TAXI_IN"])

	rain_particles.position = Vector3(px, py + 25.0, pz - 30.0)

	# Dynamic Speed-Sense: FOV expansion + subtle ground roll rumble
	var spd_ratio := clampf(speed / 220.0, 0.0, 1.0)
	chase_cam.fov = 54.0 + spd_ratio * 15.0
	cockpit_cam.fov = 60.0 + spd_ratio * 13.0
	var rumble := (sin(t * 48.0) * 0.14 * spd_ratio) if (alt <= 0.5 and speed > 25.0) else 0.0

	if not cam_is_cockpit:
		plane_root.visible = true
		if phase in ["GATE_BOARD", "PUSHBACK_WAIT", "PUSHBACK", "GATE_DEPLANE"]:
			chase_cam.position = Vector3(px - 44.0, 20.0, pz + 40.0)
			chase_cam.look_at(Vector3(px + 10.0, 6.0, pz - 6.0))
		elif phase == "APPROACH" and touchdown_done and speed < 55.0:
			chase_cam.position = Vector3(px - 32.0, py + 7.5, pz + 24.0)
			chase_cam.look_at(Vector3(px, py + 2.5, pz - 12.0))
		else:
			var db: float = cur_plane["chase_dist"]
			var dh: float = cur_plane["chase_height"]
			chase_cam.position = Vector3(px + sin(yaw) * db, py + dh + rumble, pz + cos(yaw) * db)
			chase_cam.look_at(Vector3(px - sin(yaw) * 120.0, py + sin(deg_to_rad(pitch)) * 60.0, pz - cos(yaw) * 120.0))
	else:
		plane_root.visible = false
		var cz := absf(float(cur_plane["cockpit_z"]))
		cockpit_cam.position = Vector3(px - sin(yaw) * cz, py + float(cur_plane["cockpit_y"]) + rumble * 0.7, pz - cos(yaw) * cz)
		cockpit_cam.rotation = Vector3(deg_to_rad(pitch), yaw, deg_to_rad(-roll))

	# Update HUD & Overlay
	lbl_time.text = "TIME %.1fs" % time_left
	lbl_spd.text = "SPD %d KT" % int(speed)
	lbl_alt.text = "ALT %d FT" % int(alt)
	audio.throttle_val = throttle
	audio.speed_val = speed

	overlay.cam_is_cockpit = cam_is_cockpit
	overlay.is_rain = (weather == "rain")
	overlay.wiper_mode = wiper_mode
	overlay.wiper_angle = wiper_angle
	overlay.pitch_deg = pitch
	overlay.roll_deg = roll
	overlay.show_ils = (phase == "APPROACH" and not touchdown_done)
	overlay.pip_pct = board_pct
	overlay.t = t
	overlay.spd_kt = speed
	overlay.alt_ft = py * 3.28084
	overlay.gear_dn = gear_down
	overlay.hdg_deg = -yaw
	overlay.show_hud = (running and phase in ["TAKEOFF", "PARKOUR", "APPROACH"])
	overlay.target_spd = float(cur_plane["vr"]) if phase == "TAKEOFF" else (float(cur_plane["cruise_spd"]) if phase == "PARKOUR" else float(cur_plane["vref"]))
	overlay.target_alt = 28000.0 if phase == "PARKOUR" else (maxf(0.0, (pz + 160.0) * 0.8) if phase == "APPROACH" else 2200.0)
	overlay.plane_px = px
	overlay.plane_pz = pz
	var w_msg := ""
	if running and alt > 40.0 and speed < float(cur_plane["vref"]) * 0.78:
		w_msg = "WARNING: 失速警告！請推油門"
	elif running and phase == "APPROACH" and not touchdown_done and alt < 500.0 and speed > float(cur_plane["vref"]) * 1.35:
		w_msg = "CAUTION: 速度過快！請減速"
	overlay.warn_text = w_msg
	warn_cd = maxf(0.0, warn_cd - dt)
	if w_msg != "" and warn_cd <= 0.0:
		warn_cd = 2.5
		audio.play_chime("warn")
	overlay.queue_redraw()

func _spawn_cruise_rings() -> void:
	for c in cruise_root.get_children():
		c.queue_free()
	cruise_gates.clear()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.74, 0.97)
	mat.emission_enabled = true
	mat.emission = Color(0.22, 0.74, 0.97)
	mat.emission_energy_multiplier = 2.8
	var tm := TorusMesh.new()
	tm.inner_radius = 24.0
	tm.outer_radius = 27.0
	for cfg in [[-35.0, 530.0, -550.0], [40.0, 545.0, -1150.0], [0.0, 515.0, -1750.0]]:
		var m := MeshInstance3D.new()
		m.mesh = tm
		m.material_override = mat
		m.rotation.x = PI * 0.5
		m.position = Vector3(cfg[0], cfg[1], cfg[2])
		cruise_root.add_child(m)
		cruise_gates.append({"x": cfg[0], "y": cfg[1], "z": cfg[2], "hit": false, "mesh": m})


func _apply_livery_recursive(node: Node, tex: Texture2D) -> void:
	if node is MeshInstance3D:
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = tex
		mat.metallic = 0.25
		mat.roughness = 0.32
		node.material_override = mat
	for ch in node.get_children():
		_apply_livery_recursive(ch, tex)

func _spawn_approach_gates() -> void:
	for c in cruise_root.get_children():
		c.queue_free()
	cruise_gates.clear()
	var tm := TorusMesh.new()
	tm.inner_radius = 22.0
	tm.outer_radius = 24.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.28, 0.96, 0.46)
	mat.emission_enabled = true
	mat.emission = Color(0.28, 0.96, 0.46)
	mat.emission_energy_multiplier = 2.6
	for gz in [1350.0, 900.0, 450.0]:
		var gy := maxf(18.0, (gz + 160.0) * 0.085)
		var m := MeshInstance3D.new()
		m.mesh = tm
		m.material_override = mat
		m.rotation.x = PI * 0.5
		m.position = Vector3(0.0, gy, gz)
		cruise_root.add_child(m)
		cruise_gates.append({"x": 0.0, "y": gy, "z": gz, "hit": false, "mesh": m})

func _unhandled_input(event: InputEvent) -> void:
	if running and phase == "PARKOUR":
		if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed):
			parkour_vy = 30.0
			audio.play_chime("ring")

func _enter_approach() -> void:
	phase = "APPROACH"
	airport_root.visible = true
	builder.build(airport_root, arr_apt, weather)
	_spawn_approach_gates()
	px = randf_range(-24.0, 24.0)
	py = 175.0
	alt = 1650.0
	pz = 1850.0
	speed = 185.0
	pitch = -2.0
	roll = 0.0
	yaw = 0.0
	lbl_led.text = "進場 %s %s 跑道・對準粉紅 ILS 十字並放起落架與襟翼" % [arr_apt["name"], arr_apt["rwy"]]
	audio.play_chime("atc")
	audio.speak_mandarin("已進入%s進場航道，請確認放下起落架與襟翼準備降落。" % arr_apt["name"])
	_refresh_buttons()

func _spawn_parkour_clouds() -> void:
	for c in cruise_root.get_children():
		c.queue_free()
	parkour_clouds.clear()
	var sm := SphereMesh.new(); sm.radius = 22.0; sm.height = 18.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.96, 0.98, 1.0)
	mat.roughness = 0.95
	for i in range(12):
		var cz := -280.0 - float(i) * 165.0
		var cy := 475.0 + float((i * 53) % 115)
		var cx := -42.0 + float((i * 37) % 84)
		var grp := Node3D.new()
		grp.position = Vector3(cx, cy, cz)
		for off in [Vector3(-14, -2, 0), Vector3(0, 4, 0), Vector3(14, -1, 0)]:
			var m := MeshInstance3D.new()
			m.mesh = sm; m.material_override = mat
			m.scale = Vector3(1.1, 0.85, 0.95)
			m.position = off
			grp.add_child(m)
		cruise_root.add_child(grp)
		parkour_clouds.append({"x": cx, "y": cy, "z": cz, "passed": false, "node": grp})
