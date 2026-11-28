class_name AudioSynth
extends Node

var _eng_player: AudioStreamPlayer
var _real_jet_player: AudioStreamPlayer
var _jet_pitch: float = 0.78
var _jet_vol: float = -22.0
var _eng_gen: AudioStreamGenerator
var _eng_pb: AudioStreamGeneratorPlayback
var _phase: float = 0.0
var _lead_phase: float = 0.0
var _bass_phase: float = 0.0
var _c1_phase: float = 0.0
var _c2_phase: float = 0.0
var _c3_phase: float = 0.0
var _chime_phase: float = 0.0
var _chime_timer: float = 0.0
var _chime_freqs: Array[float] = []
var _bgm_step: int = 0
var _bgm_timer: float = 0.0
var throttle_val: float = 0.0
var speed_val: float = 0.0
var bgm_enabled: bool = true
var active: bool = false

# Relaxing, layered Airline Lounge / Sky Bossa-Nova Groove (~104 BPM, Fmaj7 -> G6 -> Em7 -> Am7)
const STEP_SEC := 0.288
const MELODY := [
	659.25, 0.0, 783.99, 880.00, 783.99, 0.0, 659.25, 587.33,
	523.25, 0.0, 587.33, 659.25, 523.25, 0.0, 440.00, 0.0,
	587.33, 0.0, 659.25, 783.99, 880.00, 0.0, 783.99, 659.25,
	523.25, 587.33, 659.25, 0.0, 523.25, 0.0, 392.00, 0.0
]
const BASSLINE := [
	174.61, 0.0, 174.61, 130.81, 196.00, 0.0, 196.00, 146.83,
	164.81, 0.0, 164.81, 123.47, 110.00, 0.0, 164.81, 130.81,
	146.83, 0.0, 146.83, 110.00, 196.00, 0.0, 196.00, 146.83,
	130.81, 0.0, 196.00, 164.81, 130.81, 0.0, 98.00, 0.0
]
const CHORD_ROOT := [
	349.23, 392.00, 329.63, 220.00,
	293.66, 392.00, 261.63, 261.63
]

func _ready() -> void:
	_eng_player = AudioStreamPlayer.new()
	_eng_gen = AudioStreamGenerator.new()
	_eng_gen.mix_rate = 22050.0
	_eng_gen.buffer_length = 0.16
	_eng_player.stream = _eng_gen
	_eng_player.volume_db = -7.5
	add_child(_eng_player)
	_eng_player.play()
	_eng_pb = _eng_player.get_stream_playback() as AudioStreamGeneratorPlayback

	# Real Turbofan Engine Recording Player (Dynamic Pitch & Volume Spooling)
	_real_jet_player = AudioStreamPlayer.new()
	var jet_stream := load("res://assets/audio/jet_engine_real.wav") as AudioStream
	if jet_stream is AudioStreamWAV:
		var wav_s: AudioStreamWAV = jet_stream as AudioStreamWAV
		wav_s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav_s.loop_begin = 0
		wav_s.loop_end = int(wav_s.get_length() * float(wav_s.mix_rate))
	if jet_stream != null:
		_real_jet_player.stream = jet_stream
	_real_jet_player.volume_db = -24.0
	_real_jet_player.pitch_scale = 0.75
	add_child(_real_jet_player)

func play_chime(kind: String) -> void:
	_chime_timer = 0.48
	if kind == "atc":
		_chime_freqs = [659.25, 783.99, 1046.50]
	elif kind == "ring":
		_chime_freqs = [783.99, 987.77, 1318.51]
	else:
		_chime_freqs = [440.00, 349.23, 440.00]

func _process(delta: float) -> void:
	if _eng_pb == null:
		return
	_bgm_timer += delta
	if _bgm_timer >= STEP_SEC:
		_bgm_timer = 0.0
		_bgm_step = (_bgm_step + 1) % MELODY.size()

	if _chime_timer > 0.0:
		_chime_timer = maxf(0.0, _chime_timer - delta)

	# Smooth Real Jet Engine Spool-Up / Spool-Down
	if _real_jet_player != null and _real_jet_player.stream != null:
		if active:
			if not _real_jet_player.playing:
				_real_jet_player.play()
			var spd_f: float = clampf(speed_val / 350.0, 0.0, 1.0)
			var target_p: float = 0.72 + throttle_val * 0.52 + spd_f * 0.14
			var target_v: float = lerpf(-13.5, 1.5, clampf(throttle_val * 0.85 + spd_f * 0.25, 0.0, 1.0))
			_jet_pitch = lerpf(_jet_pitch, target_p, minf(1.0, delta * 2.8))
			_jet_vol = lerpf(_jet_vol, target_v, minf(1.0, delta * 3.2))
			_real_jet_player.pitch_scale = _jet_pitch
			_real_jet_player.volume_db = _jet_vol
		else:
			if _real_jet_player.playing:
				_real_jet_player.stop()

	var frames: int = _eng_pb.get_frames_available()
	if frames <= 0:
		return
	var eng_freq: float = 55.0 + throttle_val * 130.0 + minf(speed_val, 450.0) * 0.10
	var mel_freq: float = MELODY[_bgm_step]
	var bass_freq: float = BASSLINE[_bgm_step]
	var bar_idx: int = floori(float(_bgm_step) / 4.0) % CHORD_ROOT.size()
	var c_root: float = CHORD_ROOT[bar_idx]
	var c_third: float = c_root * 1.25
	var c_seventh: float = c_root * 1.78
	var inv_sr: float = 1.0 / 22050.0
	var env: float = exp(-(_bgm_timer / STEP_SEC) * 2.8)
	var pad_env: float = 0.55 + 0.45 * sin((_bgm_timer / STEP_SEC) * PI)
	var shaker_env: float = maxf(0.0, 1.0 - (_bgm_timer / 0.045)) if (_bgm_step % 2 == 1) else 0.0

	for i in range(frames):
		var s_l: float = 0.0
		var s_r: float = 0.0
		# Real turbofan audio is played via _real_jet_player
		if bgm_enabled:
			# Soft warm Rhodes electric piano chord pad (gentle stereo spread)
			_c1_phase = fmod(_c1_phase + c_root * inv_sr, 1.0)
			_c2_phase = fmod(_c2_phase + c_third * inv_sr, 1.0)
			_c3_phase = fmod(_c3_phase + c_seventh * inv_sr, 1.0)
			var pad_l: float = (sin(_c1_phase * TAU) + sin(_c2_phase * TAU) * 0.8) * 0.036 * pad_env
			var pad_r: float = (sin(_c1_phase * TAU) + sin(_c3_phase * TAU) * 0.8) * 0.036 * pad_env
			s_l += pad_l
			s_r += pad_r
			# Warm walking acoustic bass
			if bass_freq > 1.0:
				_bass_phase = fmod(_bass_phase + bass_freq * inv_sr, 1.0)
				var bass_s: float = sin(_bass_phase * TAU) * 0.088 * (0.45 + 0.55 * env)
				s_l += bass_s
				s_r += bass_s
			# Breezy bell / flute sky melody
			if mel_freq > 1.0:
				_lead_phase = fmod(_lead_phase + mel_freq * inv_sr, 1.0)
				var lead_s: float = (sin(_lead_phase * TAU) * 0.82 + sin(_lead_phase * TAU * 2.0) * 0.18) * 0.078 * env
				s_l += lead_s * 0.92
				s_r += lead_s * 1.08
			# Light brushed bossa shaker
			if shaker_env > 0.01:
				var sh: float = (randf() * 2.0 - 1.0) * 0.016 * shaker_env
				s_l += sh
				s_r += sh * 0.8
		if _chime_timer > 0.0 and _chime_freqs.size() >= 3:
			var ci: int = mini(2, floori((0.48 - _chime_timer) / 0.16))
			_chime_phase = fmod(_chime_phase + _chime_freqs[ci] * inv_sr, 1.0)
			var ch_s: float = sin(_chime_phase * TAU) * 0.16 * (_chime_timer / 0.48)
			s_l += ch_s
			s_r += ch_s
		_eng_pb.push_frame(Vector2(clampf(s_l, -0.95, 0.95), clampf(s_r, -0.95, 0.95)))

func _pick_human_voice(prefer_male: bool) -> String:
	var all_voices: Array = DisplayServer.tts_get_voices()
	var natural_zh: Array[String] = []
	var normal_zh: Array[String] = []
	var robotic_zh: Array[String] = []
	var male_hints: Array[String] = ["yunjhe", "yunjian", "yunxi", "kangkang", "zhiwei", "male", "david", "daniel", "guy", "alex"]
	var natural_hints: Array[String] = ["natural", "online", "neural", "hsiaochen", "hsiaoyu", "xiaoxiao", "xiaoyi", "meijia", "ting-ting", "siri", "google"]
	var robotic_hints: Array[String] = ["hanhan", "huihui", "yaoyao", "espeak"]

	for v in all_voices:
		if v is Dictionary:
			var lang: String = str(v.get("language", "")).to_lower()
			var vname: String = str(v.get("name", "")).to_lower()
			var vid: String = str(v.get("id", ""))
			if prefer_male and (lang.begins_with("zh") or lang.begins_with("en")):
				for mh in male_hints:
					if vname.contains(mh):
						return vid
			if lang.begins_with("zh"):
				var is_nat: bool = false
				for nh in natural_hints:
					if vname.contains(nh):
						is_nat = true
				var is_rob: bool = false
				for rh in robotic_hints:
					if vname.contains(rh):
						is_rob = true
				if is_nat:
					natural_zh.append(vid)
				elif is_rob:
					robotic_zh.append(vid)
				else:
					normal_zh.append(vid)
	if natural_zh.size() > 0:
		return natural_zh[0]
	if normal_zh.size() > 0:
		return normal_zh[0]
	if robotic_zh.size() > 0:
		return robotic_zh[0]
	var fallback: PackedStringArray = DisplayServer.tts_get_voices_for_language("zh")
	if fallback.size() > 0:
		return fallback[0]
	return ""

func _web_tts(text: String, lang: String, pitch: float, rate: float) -> void:
	var safe: String = text.replace("\\", "").replace("'", "").replace('"', "").replace("\n", " ")
	var js: String = "try{if(window.speechSynthesis){window.speechSynthesis.cancel();var u=new SpeechSynthesisUtterance('%s');u.lang='%s';u.pitch=%f;u.rate=%f;u.volume=1.0;var vs=window.speechSynthesis.getVoices();for(var i=0;i<vs.length;i++){if(vs[i].lang&&vs[i].lang.toLowerCase().indexOf('%s')===0){u.voice=vs[i];break;}}window.speechSynthesis.speak(u);}}catch(e){}" % [safe, lang, pitch, rate, lang.to_lower().substr(0, 2)]
	JavaScriptBridge.eval(js)

func speak_mandarin(text: String) -> void:
	if OS.has_feature("web"):
		_web_tts(text, "zh-TW", 1.05, 1.05)
		return
	var vid: String = _pick_human_voice(false)
	if vid != "":
		DisplayServer.tts_stop()
		DisplayServer.tts_speak(text, vid, 88, 1.07, 1.06)

func speak_pilot_male(text: String) -> void:
	if OS.has_feature("web"):
		_web_tts(text, "en-US", 0.74, 0.96)
		return
	var vid: String = _pick_human_voice(true)
	if vid == "":
		var en_fb: PackedStringArray = DisplayServer.tts_get_voices_for_language("en")
		if en_fb.size() > 0:
			vid = en_fb[0]
	if vid != "":
		DisplayServer.tts_stop()
		DisplayServer.tts_speak(text, vid, 96, 0.78, 0.96)
