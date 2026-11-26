class_name AirportData
extends RefCounted

static func get_planes() -> Array[Dictionary]:
	return [
		{
			"id": "b737",
			"name": "波音 737-800（短中程靈活）",
			"model": "res://assets/models/b737_800.glb",
			"v1": 116.0,
			"vr": 142.0,
			"v2": 168.0,
			"vref": 138.0,
			"cruise_spd": 440.0,
			"accel": 10.5,
			"turn_rate": 1.25,
			"pitch_rate": 1.2,
			"brake_power": 27.0,
			"flaps": ["收起", "開啟"],
			"cockpit_z": -16.5,
			"cockpit_y": 1.8,
			"chase_dist": 48.0,
			"chase_height": 13.0,
			"gear_height": 3.2
		},
		{
			"id": "a321",
			"name": "空中巴士 A321neo（中程主力）",
			"model": "res://assets/models/a321_neo.glb",
			"v1": 120.0,
			"vr": 146.0,
			"v2": 172.0,
			"vref": 142.0,
			"cruise_spd": 455.0,
			"accel": 10.0,
			"turn_rate": 1.15,
			"pitch_rate": 1.12,
			"brake_power": 25.0,
			"flaps": ["收起", "開啟"],
			"cockpit_z": -18.5,
			"cockpit_y": 1.9,
			"chase_dist": 52.0,
			"chase_height": 14.0,
			"gear_height": 3.4
		},
		{
			"id": "a330",
			"name": "空中巴士 A330-300（沉穩寬體）",
			"model": "res://assets/models/a330_300.glb",
			"v1": 124.0,
			"vr": 150.0,
			"v2": 176.0,
			"vref": 145.0,
			"cruise_spd": 475.0,
			"accel": 9.4,
			"turn_rate": 0.95,
			"pitch_rate": 0.96,
			"brake_power": 22.0,
			"flaps": ["收起", "開啟"],
			"cockpit_z": -24.5,
			"cockpit_y": 2.6,
			"chase_dist": 68.0,
			"chase_height": 18.0,
			"gear_height": 4.4
		},
		{
			"id": "b787",
			"name": "波音 787-9 夢幻客機（高速寬體）",
			"model": "res://assets/models/b787_9.glb",
			"v1": 126.0,
			"vr": 152.0,
			"v2": 178.0,
			"vref": 148.0,
			"cruise_spd": 490.0,
			"accel": 15.5,
			"turn_rate": 1.02,
			"pitch_rate": 1.02,
			"brake_power": 23.0,
			"flaps": ["0", "5", "15", "25", "30"],
			"cockpit_z": -25.5,
			"cockpit_y": 2.7,
			"chase_dist": 70.0,
			"chase_height": 18.5,
			"gear_height": 4.5
		}
	]

static func get_airports() -> Array[Dictionary]:
	return [
		{"code": "KHH", "name": "高雄小港機場", "rwy": "09", "len": 3150, "theme": "khh", "sea": false, "desc": "旗津海岸、高雄港紅橘貨櫃起重機與彩色貨櫃、夢時代摩天輪、85大樓與壽山"},
		{"code": "TSA", "name": "台北松山機場", "rwy": "10", "len": 2605, "theme": "tsa", "sea": false, "desc": "左側紅柱金瓦圓山大飯店、基隆河與紅色大直拱橋、右側台北101、濱江街圍牆"},
		{"code": "TPE", "name": "桃園國際機場", "rwy": "05R", "len": 3800, "theme": "tpe", "sea": false, "desc": "桃園濱海旋轉風力發電機列、竹圍海岸線、桃園高聳塔台與雙航廈"},
		{"code": "MZG", "name": "澎湖馬公機場", "rwy": "02", "len": 3000, "theme": "mzg", "sea": true, "desc": "隘門金黃沙灘、翡翠澎湖海灣、漁船與遠方澎湖跨海大橋"},
		{"code": "NRT", "name": "日本成田機場", "rwy": "16R", "len": 4000, "theme": "nrt", "sea": false, "desc": "千葉大片綠意農田、櫻之山丘陵、成田塔台與雙排日系大型機棚"},
		{"code": "FUK", "name": "日本福岡機場", "rwy": "16", "len": 2800, "theme": "fuk", "sea": false, "desc": "博多灣海岸線、都市高架道路與超近距離博多市區密集公寓大樓群"},
		{"code": "KIX", "name": "日本關西機場", "rwy": "06L", "len": 4000, "theme": "kix", "sea": true, "desc": "大阪灣海上人工島跑道、跨海懸索聯絡橋與對岸臨空城摩天輪"},
		{"code": "OKA", "name": "沖繩那霸機場", "rwy": "36R", "len": 3000, "theme": "oka", "sea": true, "desc": "跑道南端瀨長島白色階梯聚落、翡翠珊瑚礁淺海與海上第二跑道"},
		{"code": "CAN", "name": "廣州白雲機場", "rwy": "02L", "len": 3800, "theme": "can", "sea": false, "desc": "白雲山稜線、珠江水系、遠景廣州塔（小蠻腰）與弧形大型航廈"},
		{"code": "SZX", "name": "深圳寶安機場", "rwy": "16", "len": 3800, "theme": "szx", "sea": true, "desc": "珠江口海面、深中通道跨海大橋遠景、前海高樓群與蜂巢航廈"}
	]


static func get_airlines() -> Array[Dictionary]:
	return [
		{"id": "plum", "name": "梅花航空（經典梅花塗裝）", "callsign": "梅花航空 101", "livery": "res://assets/textures/livery_plum.png"},
		{"id": "tiger", "name": "老虎航空（亮橘虎紋塗裝）", "callsign": "老虎航空 208", "livery": "res://assets/textures/livery_tiger.png"},
		{"id": "star", "name": "星光航空（曜石金星塗裝）", "callsign": "星光航空 801", "livery": "res://assets/textures/livery_star.png"},
		{"id": "cnc", "name": "CNC 航空（海天雙藍塗裝）", "callsign": "CNC 航空 852", "livery": "res://assets/textures/livery_cnc.png"},
		{"id": "peach", "name": "桃子航空（桃紫漸層塗裝）", "callsign": "桃子航空 902", "livery": "res://assets/textures/livery_peach.png"},
		{"id": "ever", "name": "長帆航空（翠綠金橘塗裝）", "callsign": "長帆航空 198", "livery": "res://assets/textures/livery_ever.png"}
	]
