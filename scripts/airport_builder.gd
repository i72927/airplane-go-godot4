class_name AirportBuilder
extends RefCounted

var jetbridge: Node3D
var taxi_arrows_root: Node3D
var tug_node: Node3D
var wind_hubs: Array[Node3D] = []
var papi_mats: Array[StandardMaterial3D] = []

func build(root: Node3D, airport: Dictionary, weather: String) -> void:
	for c in root.get_children():
		c.queue_free()
	wind_hubs.clear()
	papi_mats.clear()

	var is_night := (weather == "night")
	var is_rain := (weather == "rain")
	var is_dusk := (weather == "dusk")
	var rwy_len := minf(2900.0, float(airport["len"]) * 0.80)
	var rwy_w := 68.0 # Includes 45-60m runway + paved shoulders

	var tex_rwy := load("res://assets/textures/runway_asphalt.png") as Texture2D
	var tex_taxi := load("res://assets/textures/taxiway_asphalt.png") as Texture2D
	var tex_apron := load("res://assets/textures/apron_concrete.png") as Texture2D
	var tex_grass := load("res://assets/textures/terrain_grass.png") as Texture2D
	var tex_urban := load("res://assets/textures/urban_ground.png") as Texture2D
	var tex_term := load("res://assets/textures/terminal_glass.png") as Texture2D
	var tex_city := load("res://assets/textures/city_facade.png") as Texture2D
	var tex_city_em := load("res://assets/textures/city_night_emissive.png") as Texture2D

	# 1. Surrounding Terrain / Sea Base
	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = Vector2(20000, 20000)
	var ground_mat := StandardMaterial3D.new()
	if airport["sea"]:
		ground_mat.albedo_color = Color(0.03, 0.11, 0.22) if is_night else (Color(0.10, 0.23, 0.38) if is_dusk else Color(0.04, 0.44, 0.70))
		ground_mat.roughness = 0.18
		ground_mat.metallic = 0.30
	else:
		ground_mat.albedo_texture = tex_urban
		ground_mat.uv1_scale = Vector3(85, 85, 1)
		ground_mat.roughness = 0.92
		if is_night:
			ground_mat.albedo_color = Color(0.22, 0.30, 0.26)
	var ground := MeshInstance3D.new()
	ground.mesh = ground_mesh
	ground.material_override = ground_mat
	ground.position = Vector3(0, -0.55, -rwy_len * 0.45)
	root.add_child(ground)

	# 2. Wide Realistic Airport Grounds (760m wide manicured airfield clearway)
	var field_mat := StandardMaterial3D.new()
	field_mat.albedo_texture = tex_grass
	field_mat.uv1_scale = Vector3(24, 65, 1)
	field_mat.roughness = 0.90
	if is_night:
		field_mat.albedo_color = Color(0.24, 0.34, 0.28)
	root.add_child(_make_plane(Vector2(760, rwy_len + 640), Vector3(120, -0.18, -rwy_len * 0.5), field_mat))

	# 3. High-Detail PBR Runway with Paved Shoulders & Blast-Pad Chevrons
	var rwy_mat := StandardMaterial3D.new()
	rwy_mat.albedo_texture = tex_rwy
	rwy_mat.roughness = 0.16 if is_rain else 0.78
	rwy_mat.metallic = 0.32 if is_rain else 0.05
	root.add_child(_make_plane(Vector2(rwy_w, rwy_len), Vector3(0, 0.08, -rwy_len * 0.5), rwy_mat))

	# Runway Edge Lights on 3D Pedestals
	var edge_mat := _emissive_mat(Color(1.0, 0.94, 0.65) if (is_night or is_rain) else Color(1, 1, 1), 2.5 if (is_night or is_rain) else 0.8)
	var edge_sphere := SphereMesh.new()
	edge_sphere.radius = 0.55
	edge_sphere.height = 1.1
	var z := -120.0
	while z >= -rwy_len + 120.0:
		for sx in [-27.0, 27.0]:
			var l := MeshInstance3D.new()
			l.mesh = edge_sphere
			l.material_override = edge_mat
			l.position = Vector3(sx, 0.65, z)
			root.add_child(l)
		z -= 85.0

	# Runway Distance Remaining Signs (left side every 300m for strong ground speed reference)
	var sign_mat := _emissive_mat(Color(0.95, 0.78, 0.15), 1.4)
	for dz in range(-280, int(-rwy_len + 200), -300):
		root.add_child(_make_box_mat(Vector3(3.6, 2.6, 0.6), Vector3(-40.0, 1.4, float(dz)), sign_mat))

	# ALSF-2 Approach Light Gantries (+Z side before threshold)
	var app_mat := _emissive_mat(Color(1.0, 0.92, 0.48), 3.0)
	var red_mat := _emissive_mat(Color(0.96, 0.22, 0.22), 3.0)
	for az in range(60, 540, 60):
		var gw := 30.0 if az == 300 else 12.0
		root.add_child(_make_box(Vector3(gw, 0.6, 0.8), Vector3(0, 1.8, float(az)), Color(0.35, 0.38, 0.42)))
		var bar := _make_box_mat(Vector3(gw, 0.5, 0.7), Vector3(0, 2.2, float(az)), app_mat if az > 120 else red_mat)
		root.add_child(bar)

	# 4 Live 3D PAPI Glideslope Lights
	for i in range(4):
		var pm := _emissive_mat(Color(0.95, 0.25, 0.25) if i < 2 else Color(1, 1, 1), 3.2)
		root.add_child(_make_box_mat(Vector3(2.4, 1.4, 1.4), Vector3(-34.0 - i * 4.5, 1.2, -320.0), pm))
		papi_mats.append(pm)

	# 4. Continuous Paved Parallel Taxiway + Wide South Connector + Apron (Zero Grass Gaps!)
	var taxi_mat := StandardMaterial3D.new()
	taxi_mat.albedo_texture = tex_taxi
	taxi_mat.uv1_scale = Vector3(1, 36, 1)
	taxi_mat.roughness = 0.22 if is_rain else 0.82
	root.add_child(_make_plane(Vector2(38, rwy_len + 260.0), Vector3(135, 0.04, -rwy_len * 0.5 + 110.0), taxi_mat))

	# Wide South Runway Entry & High-Speed Angled Exit Connectors
	for cz in [-20.0, -rwy_len * 0.35, -rwy_len * 0.68, -rwy_len + 80.0]:
		var cw := 168.0 if cz == -20.0 else 148.0
		var conn := _make_plane(Vector2(cw, 34.0 if cz == -20.0 else 28.0), Vector3(72.0, 0.035, cz), taxi_mat)
		if cz < -100.0 and cz > -rwy_len + 150.0:
			conn.rotation.y = 0.35
		root.add_child(conn)

	# Glowing 3D Dashed Taxiway Guide Arrows (Gate -> Taxiway -> South Connector -> Runway)
	taxi_arrows_root = Node3D.new()
	var arrow_mat := _emissive_mat(Color(0.98, 0.85, 0.16), 2.4)
	# Gate pushback to taxiway (z=128 -> x=135)
	for ax in [115.0, 125.0]:
		var a1 := _make_box_mat(Vector3(3.2, 0.18, 1.4), Vector3(ax, 0.12, 128.0), arrow_mat)
		taxi_arrows_root.add_child(a1)
	# Northbound along taxiway (x=135, z=120 -> -15)
	for az in range(115, -18, -18):
		var a2 := _make_box_mat(Vector3(1.8, 0.18, 4.2), Vector3(135.0, 0.12, float(az)), arrow_mat)
		taxi_arrows_root.add_child(a2)
	# Westbound along south connector onto runway (z=-20, x=122 -> 10)
	for ax2 in range(120, 8, -16):
		var a3 := _make_box_mat(Vector3(4.2, 0.18, 1.8), Vector3(float(ax2), 0.12, -20.0), arrow_mat)
		taxi_arrows_root.add_child(a3)
	# Northbound alignment arrows on runway threshold
	for az2 in [-28.0, -44.0, -60.0]:
		var a4 := _make_box_mat(Vector3(2.0, 0.18, 4.6), Vector3(0.0, 0.14, az2), arrow_mat)
		taxi_arrows_root.add_child(a4)
	root.add_child(taxi_arrows_root)

	# Green Centerline + Blue Edge Taxiway Lights
	var green_mat := _emissive_mat(Color(0.25, 0.95, 0.45), 2.8)
	var blue_mat := _emissive_mat(Color(0.22, 0.72, 1.0), 2.6)
	var tl_mesh := SphereMesh.new()
	tl_mesh.radius = 0.45
	tl_mesh.height = 0.9
	for tz in range(145, int(-rwy_len + 120), -28):
		for cfg in [[135.0, green_mat], [121.0, blue_mat], [149.0, blue_mat]]:
			var tl := MeshInstance3D.new()
			tl.mesh = tl_mesh
			tl.material_override = cfg[1]
			tl.position = Vector3(cfg[0], 0.45, float(tz))
			root.add_child(tl)

	# Concrete Apron & Terminal Complex (x = 225..360)
	var apron_mat := StandardMaterial3D.new()
	apron_mat.albedo_texture = tex_apron
	apron_mat.uv1_scale = Vector3(16, 28, 1)
	apron_mat.roughness = 0.25 if is_rain else 0.85
	root.add_child(_make_plane(Vector2(290, 780), Vector3(220, 0.02, 45), apron_mat))

	var term_mat := StandardMaterial3D.new()
	term_mat.albedo_texture = tex_term
	term_mat.uv1_scale = Vector3(8, 1.5, 1)
	term_mat.roughness = 0.22
	term_mat.metallic = 0.35
	if is_night:
		term_mat.emission_enabled = true
		term_mat.emission_texture = tex_term
		term_mat.emission_energy_multiplier = 0.85
	root.add_child(_make_box_mat(Vector3(64, 26, 320), Vector3(310, 13, 30), term_mat))

	# Hangar Complex on North Apron
	for hz in [-320.0, -440.0]:
		root.add_child(_make_box(Vector3(75, 22, 85), Vector3(295, 11, hz), Color(0.55, 0.60, 0.66)))

	# Realistic Multi-Part Articulated Jetbridge (Rotunda + Glass Tunnel + Bogie Wheels + Rubber Seal)
	jetbridge = Node3D.new()
	jetbridge.position = Vector3(172.0, 0.0, 128.0)
	jetbridge.add_child(_make_cyl(3.2, 3.2, 8.2, Vector3(32.0, 4.1, 0.0), Color(0.68, 0.72, 0.78)))
	jetbridge.add_child(_make_box(Vector3(34.0, 3.8, 4.2), Vector3(15.0, 5.2, 0.0), Color(0.84, 0.87, 0.92)))
	jetbridge.add_child(_make_box_mat(Vector3(28.0, 1.8, 4.35), Vector3(15.0, 5.4, 0.0), term_mat))
	for rib_x in [2.0, 10.0, 18.0, 26.0]:
		jetbridge.add_child(_make_box(Vector3(0.6, 4.1, 4.5), Vector3(rib_x, 5.2, 0.0), Color(0.55, 0.60, 0.68)))
	jetbridge.add_child(_make_box(Vector3(1.2, 3.6, 1.2), Vector3(4.0, 1.8, 0.0), Color(0.92, 0.74, 0.14)))
	jetbridge.add_child(_make_cyl(0.85, 0.85, 2.2, Vector3(4.0, 0.85, 0.0), Color(0.12, 0.14, 0.18)))
	jetbridge.add_child(_make_box(Vector3(2.8, 4.1, 4.6), Vector3(-2.6, 5.2, 0.0), Color(0.14, 0.16, 0.20)))
	root.add_child(jetbridge)

	var tug_res := load("res://assets/models/pushback_tug.glb") as PackedScene
	if tug_res != null:
		tug_node = tug_res.instantiate() as Node3D
		tug_node.position = Vector3(175, 0, 112)
		root.add_child(tug_node)

	# Control Tower
	root.add_child(_make_cyl(5.5, 8.0, 56.0, Vector3(315, 28, -190), Color(0.84, 0.87, 0.91)))
	root.add_child(_make_cyl_mat(13.0, 8.8, 11.0, Vector3(315, 60, -190), term_mat))

	# 4B. 20x Dense Airfield Props (Parked Neighboring AI Jets, GSE Trucks, Hangars, Perimeter Trees)
	var b737_res := load("res://assets/models/b737_800.glb") as PackedScene
	if b737_res != null:
		for gz in [-180.0, -90.0, 240.0, 330.0]:
			var ai_jet: Node3D = b737_res.instantiate() as Node3D
			ai_jet.position = Vector3(235.0, 3.3, gz)
			ai_jet.rotation.y = -PI * 0.5
			root.add_child(ai_jet)
			root.add_child(_make_box(Vector3(44, 4.4, 4.8), Vector3(268, 5.4, gz), Color(0.82, 0.85, 0.90)))
	# Ground Support Equipment (Fuel Trucks & Baggage Carts on Apron)
	for gz in [-160.0, -70.0, 145.0, 260.0]:
		root.add_child(_make_box(Vector3(7.5, 2.8, 3.2), Vector3(205.0, 1.4, gz), Color(0.95, 0.78, 0.14)))
		root.add_child(_make_box(Vector3(4.2, 1.8, 2.4), Vector3(214.0, 0.9, gz + 8.0), Color(0.92, 0.94, 0.97)))

	# 4C. 20x Dense Urban Surroundings via MultiMeshInstance3D (440+ multi-tier buildings in 1 draw call!)
	var mm_city := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var b_mesh := BoxMesh.new()
	b_mesh.size = Vector3(1, 1, 1)
	mm.mesh = b_mesh
	var b_mats := StandardMaterial3D.new()
	b_mats.albedo_texture = tex_city
	b_mats.uv1_scale = Vector3(2, 3, 1)
	b_mats.roughness = 0.65
	if is_night:
		b_mats.albedo_color = Color(0.32, 0.38, 0.48)
		b_mats.emission_enabled = true
		b_mats.emission_texture = tex_city_em
		b_mats.emission_energy_multiplier = 1.65
	mm_city.material_override = b_mats
	var th_city: String = airport["theme"]
	var min_bh := 22.0
	var max_bh := 115.0
	var step_gz := -95
	if th_city in ["mzg", "nrt", "oka"]:
		min_bh = 10.0; max_bh = 34.0; step_gz = -180
		b_mats.albedo_color = Color(0.95, 0.88, 0.82) if not is_night else Color(0.32, 0.34, 0.42)
	elif th_city == "tpe":
		min_bh = 16.0; max_bh = 52.0; step_gz = -140
		b_mats.albedo_color = Color(0.84, 0.88, 0.92) if not is_night else Color(0.30, 0.36, 0.44)
	elif th_city in ["szx", "can"]:
		min_bh = 48.0; max_bh = 175.0; step_gz = -90
		b_mats.albedo_color = Color(0.76, 0.88, 0.98) if not is_night else Color(0.28, 0.40, 0.56)
	elif th_city == "kix":
		min_bh = 18.0; max_bh = 42.0; step_gz = -240

	var rng := RandomNumberGenerator.new()
	rng.seed = 2026 + th_city.hash()
	var transforms: Array[Transform3D] = []
	for gz in range(1100, -3600, step_gz):
		for side_x in [-450.0, -540.0, -640.0, -760.0, -900.0, -1060.0, 470.0, 560.0, 660.0, 780.0, 920.0, 1080.0]:
			if airport["sea"] and side_x < 0.0:
				continue
			if th_city == "kix" and side_x < 880.0:
				continue
			if th_city == "mzg" and absf(float(side_x)) < 620.0:
				continue
			var bw := rng.randf_range(30.0, 58.0)
			var bh := rng.randf_range(min_bh, max_bh)
			var bd := rng.randf_range(30.0, 58.0)
			var bx: float = float(side_x) + rng.randf_range(-24.0, 24.0)
			var bz := float(gz) + rng.randf_range(-28.0, 28.0)
			transforms.append(Transform3D(Basis().scaled(Vector3(bw, bh, bd)), Vector3(bx, bh * 0.5, bz)))
			transforms.append(Transform3D(Basis().scaled(Vector3(bw * 1.18, bh * 0.22, bd * 1.18)), Vector3(bx, bh * 0.11, bz)))
	mm.instance_count = transforms.size()
	for idx in range(transforms.size()):
		mm.set_instance_transform(idx, transforms[idx])
	mm_city.multimesh = mm
	root.add_child(mm_city)

	# 4D. Elevated Urban Expressway Viaducts Outside Airport Fence (Strong Parallax Speed Reference)
	var exp_col := Color(0.46, 0.49, 0.54) if not is_night else Color(0.18, 0.21, 0.26)
	var pier_col := Color(0.55, 0.58, 0.62) if not is_night else Color(0.22, 0.25, 0.30)
	for side_ex in [-415.0, 445.0]:
		if airport["sea"] and side_ex < 0.0:
			continue
		root.add_child(_make_box(Vector3(18.0, 2.4, 4200.0), Vector3(side_ex, 16.0, -1200.0), exp_col))
		for pz in range(700, -3200, -140):
			root.add_child(_make_box(Vector3(4.5, 16.0, 4.5), Vector3(side_ex, 8.0, float(pz)), pier_col))

	# 4E. Multi-Layered 3D Volumetric Cloud Deck (240+ Tinted Cumulus Puffs)
	var mm_clouds := MultiMeshInstance3D.new()
	var mc := MultiMesh.new()
	mc.transform_format = MultiMesh.TRANSFORM_3D
	mc.use_colors = true
	var cm := SphereMesh.new(); cm.radius = 1.0; cm.height = 1.0; cm.radial_segments = 10; cm.rings = 6
	mc.mesh = cm
	var c_mat := StandardMaterial3D.new()
	c_mat.vertex_color_use_as_albedo = true
	c_mat.roughness = 0.95
	c_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mm_clouds.material_override = c_mat
	var crng := RandomNumberGenerator.new(); crng.seed = 404
	var c_count := 240
	mc.instance_count = c_count
	for ci in range(c_count):
		var cx := crng.randf_range(-2800.0, 2800.0)
		var cy := crng.randf_range(340.0, 560.0)
		var cz := crng.randf_range(-3400.0, 1200.0)
		var sx := crng.randf_range(95.0, 240.0)
		var sy := crng.randf_range(24.0, 58.0)
		var sz := crng.randf_range(95.0, 240.0)
		mc.set_instance_transform(ci, Transform3D(Basis().scaled(Vector3(sx, sy, sz)), Vector3(cx, cy, cz)))
		var shade := clampf((cy - 340.0) / 220.0, 0.0, 1.0)
		var col := Color(0.58 + 0.38 * shade, 0.66 + 0.30 * shade, 0.78 + 0.20 * shade) if not is_night else Color(0.12 + 0.10 * shade, 0.15 + 0.10 * shade, 0.24 + 0.12 * shade)
		if is_dusk:
			col = Color(0.62 + 0.34 * shade, 0.48 + 0.28 * shade, 0.56 + 0.14 * shade)
		mc.set_instance_color(ci, col)
	mm_clouds.multimesh = mc
	root.add_child(mm_clouds)

	# 5. Distant Real-World Landmarks & City Skylines OUTSIDE the Wide Airport Perimeter (|x| >= 440m!)
	var city_mat := StandardMaterial3D.new()
	city_mat.albedo_texture = tex_city
	city_mat.uv1_scale = Vector3(2, 3, 1)
	city_mat.roughness = 0.65
	if is_night:
		city_mat.albedo_color = Color(0.32, 0.38, 0.48)
		city_mat.emission_enabled = true
		city_mat.emission_texture = tex_city_em
		city_mat.emission_energy_multiplier = 1.65

	var th: String = airport["theme"]
	if th == "khh":
		var h_mat := StandardMaterial3D.new()
		h_mat.albedo_color = Color(0.03, 0.14, 0.28) if is_night else Color(0.05, 0.48, 0.72)
		h_mat.roughness = 0.18
		root.add_child(_make_plane(Vector2(1800, 3800), Vector3(-1250, -0.08, -600), h_mat))
		for i in range(4):
			var cz := 180.0 - i * 190.0
			root.add_child(_make_box(Vector3(5, 52, 5), Vector3(-440, 26, cz), Color(0.92, 0.35, 0.06)))
			root.add_child(_make_box(Vector3(68, 5, 6), Vector3(-465, 46, cz), Color(0.96, 0.42, 0.10)))
		root.add_child(_make_box_mat(Vector3(34, 145, 38), Vector3(-680, 72.5, -1550), city_mat))
		root.add_child(_make_box_mat(Vector3(34, 145, 38), Vector3(-610, 72.5, -1550), city_mat))
		root.add_child(_make_box_mat(Vector3(104, 135, 40), Vector3(-645, 195, -1550), city_mat))
		root.add_child(_make_box_mat(Vector3(58, 125, 36), Vector3(-645, 315, -1550), city_mat))
		root.add_child(_make_cyl(25.0, 420.0, 185.0, Vector3(-960, 90, -1950), Color(0.08, 0.36, 0.18) if not is_night else Color(0.05, 0.14, 0.10)))
		# Kaohsiung Port Colorful Stacked Shipping Containers & Cargo Ships
		var cont_cols := [Color(0.82, 0.20, 0.18), Color(0.14, 0.44, 0.78), Color(0.16, 0.62, 0.34), Color(0.90, 0.52, 0.12)]
		for ci in range(18):
			var cz := 260.0 - float(ci) * 38.0
			for tier in range(3):
				root.add_child(_make_box(Vector3(16, 4.5, 28), Vector3(-475 - (ci % 2) * 22, 2.25 + tier * 4.6, cz), cont_cols[(ci + tier) % 4]))
		for sz in [-80.0, -480.0]:
			root.add_child(_make_box(Vector3(34, 12, 160), Vector3(-565, 6, sz), Color(0.45, 0.14, 0.14)))
			root.add_child(_make_box(Vector3(24, 18, 28), Vector3(-565, 18, sz + 56), Color(0.92, 0.94, 0.97)))
		# Dream Mall Ferris Wheel in Distance
		var fw_mat := _emissive_mat(Color(0.95, 0.62, 0.85), 1.4 if is_night else 0.5)
		var fw := MeshInstance3D.new()
		var tm := TorusMesh.new(); tm.inner_radius = 48.0; tm.outer_radius = 54.0
		fw.mesh = tm; fw.material_override = fw_mat
		fw.position = Vector3(-510, 88, -1180)
		root.add_child(fw)
		for i in range(24):
			var bh := 46.0 + float((i * 23) % 90)
			root.add_child(_make_box_mat(Vector3(42, bh, 42), Vector3(520 + (i % 5) * 76, bh * 0.5, -240 - floori(float(i) / 5.0) * 290), city_mat))
	elif th == "tsa":
		root.add_child(_make_cyl(35.0, 320.0, 120.0, Vector3(-560, 56, -420), Color(0.10, 0.44, 0.22) if not is_night else Color(0.05, 0.14, 0.10)))
		root.add_child(_make_box(Vector3(120, 46, 50), Vector3(-535, 102, -410), Color(0.75, 0.12, 0.12)))
		root.add_child(_make_cyl(8.0, 86.0, 30.0, Vector3(-535, 138, -410), Color(0.92, 0.72, 0.08)))
		var rv_mat := StandardMaterial3D.new()
		rv_mat.albedo_color = Color(0.05, 0.16, 0.32) if is_night else Color(0.12, 0.42, 0.85)
		rv_mat.roughness = 0.2
		var rv := _make_plane(Vector2(150, 3000), Vector3(-360, -0.05, -260), rv_mat)
		rv.rotation.y = 0.24
		root.add_child(rv)
		# Dazhi Bridge Red Cable-Stayed Arch over Keelung River
		var br_deck := _make_box(Vector3(280, 4.0, 22.0), Vector3(-360, 14.0, -340), Color(0.84, 0.86, 0.90))
		br_deck.rotation.y = 0.24
		root.add_child(br_deck)
		root.add_child(_make_box(Vector3(12, 72, 10), Vector3(-360, 48, -340), Color(0.86, 0.16, 0.16)))
		var t101_mat := StandardMaterial3D.new()
		t101_mat.albedo_color = Color(0.08, 0.55, 0.54) if not is_night else Color(0.06, 0.36, 0.38)
		if is_night:
			t101_mat.emission_enabled = true; t101_mat.emission = Color(0.12, 0.75, 0.68); t101_mat.emission_energy_multiplier = 0.55
		for s in range(8):
			var seg := _make_cyl_mat(36.0 - s * 1.1, 28.0 - s * 0.9, 44.0, Vector3(680, 24.0 + s * 44.0, -1320), t101_mat)
			seg.rotation.y = PI * 0.25
			root.add_child(seg)
		root.add_child(_make_cyl(2.0, 6.0, 95.0, Vector3(680, 420, -1320), Color(0.85, 0.9, 0.95)))
		for i in range(22):
			var bh := 48.0 + float((i * 27) % 96)
			root.add_child(_make_box_mat(Vector3(46, bh, 46), Vector3(490 + (i % 4) * 78, bh * 0.5, 120 - floori(float(i) / 4.0) * 280), city_mat))
	elif th == "fuk":
		# Hakata City Skyline cleanly OUTSIDE the wide airport perimeter (x <= -420m or x >= +480m, plus approach blocks before z > 720m)
		for fz in range(520, -1900, -145):
			for k in range(3):
				var h1 := 32.0 + float((abs(fz) + k * 31) % 58)
				var h2 := 34.0 + float((abs(fz) + k * 19) % 62)
				root.add_child(_make_box_mat(Vector3(52, h1, 52), Vector3(-430 - k * 82, h1 * 0.5, float(fz)), city_mat))
				root.add_child(_make_box_mat(Vector3(52, h2, 52), Vector3(480 + k * 82, h2 * 0.5, float(fz)), city_mat))
	elif th in ["kix", "oka", "mzg", "szx"]:
		var br := _make_box(Vector3(26, 5, 2400), Vector3(520, 30, -320), Color(0.68, 0.72, 0.78))
		br.rotation.y = 0.22
		root.add_child(br)
		for bz in [-640.0, -120.0, 420.0]:
			root.add_child(_make_box(Vector3(11, 102, 11), Vector3(520, 51, bz), Color(0.88, 0.90, 0.94)))
	elif th == "can":
		var ct_mat := StandardMaterial3D.new()
		ct_mat.albedo_color = Color(0.85, 0.25, 0.58) if is_night else Color(0.65, 0.72, 0.80)
		if is_night:
			ct_mat.emission_enabled = true; ct_mat.emission = Color(0.95, 0.25, 0.62); ct_mat.emission_energy_multiplier = 0.9
		root.add_child(_make_cyl_mat(15.0, 36.0, 200.0, Vector3(640, 100.0, -1500), ct_mat))
		root.add_child(_make_cyl_mat(30.0, 15.0, 190.0, Vector3(640, 290.0, -1500), ct_mat))
		root.add_child(_make_cyl(2.0, 5.0, 120.0, Vector3(640, 440.0, -1500), Color(0.95, 0.97, 1.0)))
	else:
		for i in range(5):
			var wz := 200.0 - i * 350.0
			root.add_child(_make_cyl(2.2, 3.8, 78.0, Vector3(-440, 39, wz), Color(0.95, 0.97, 0.99)))
			var hub := Node3D.new()
			hub.position = Vector3(-440, 78, wz)
			for b in range(3):
				var blade_wrap := Node3D.new()
				blade_wrap.rotation.z = b * (TAU / 3.0)
				blade_wrap.add_child(_make_box(Vector3(2.6, 34.0, 0.8), Vector3(0, 17.0, 0), Color(0.96, 0.98, 1.0)))
				hub.add_child(blade_wrap)
			root.add_child(hub)
			wind_hubs.append(hub)

func _make_box(sz: Vector3, pos: Vector3, col: Color) -> MeshInstance3D:
	var m := StandardMaterial3D.new(); m.albedo_color = col; m.roughness = 0.72
	return _make_box_mat(sz, pos, m)

func _make_box_mat(sz: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = sz; mi.mesh = bm; mi.material_override = mat; mi.position = pos; return mi

func _make_cyl(top_r: float, bot_r: float, h: float, pos: Vector3, col: Color) -> MeshInstance3D:
	var m := StandardMaterial3D.new(); m.albedo_color = col; m.roughness = 0.65
	return _make_cyl_mat(top_r, bot_r, h, pos, m)

func _make_cyl_mat(top_r: float, bot_r: float, h: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = top_r; cm.bottom_radius = bot_r; cm.height = h; mi.mesh = cm; mi.material_override = mat; mi.position = pos; return mi

func _make_plane(sz: Vector2, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = sz; mi.mesh = pm; mi.material_override = mat; mi.position = pos; return mi

func _emissive_mat(col: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = col; m.emission_enabled = true; m.emission = col; m.emission_energy_multiplier = energy; return m
