class_name AudioSynth
extends Node

var _eng_player: AudioStreamPlayer
var _eng_gen: AudioStreamGenerator
var _eng_pb: AudioStreamGeneratorPlayback
var _phase: float = 0.0
var _bgm_phase: float = 0.0
var _bass_phase: float = 0.0
var _chord_phase: float = 0.0
var _chime_phase: float = 0.0
var _chime_timer: float = 0.0
var _chime_freqs: Array[float] = []
var _bgm_step: int = 0
var _bgm_timer: float = 0.0
var throttle_val: float = 0.0
var speed_val: float = 0.0
var bgm_enabled: bool = true
var active: bool = false

# Upbeat PS2 Jet de GO! 2 style 32-step Jazz-Fusion / Arcade Synth-Pop Groove (128 BPM)
const MELODY := [
	523.25, 659.25, 783.99, 659.25, 880.00, 783.99, 659.25, 587.33,
	523.25, 587.33, 659.25, 783.99, 659.25, 523.25, 493.88, 392.00,
	440.00, 523.25, 659.25, 587.33, 698.46, 659.25, 587.33, 523.25,
	587.33, 659.25, 783.99, 880.00, 987.77, 880.00, 783.99, 659.25
]
const BASSLINE := [
	130.81, 130.81, 196.00, 130.81, 110.00, 110.00, 164.81, 110.00,
	87.31,  87.31,  130.81, 87.31,  98.00,  98.00,  146.83, 196.00,
	110.00, 110.00, 164.81, 110.00, 87.31,  87.31,  130.81, 87.31,
	98.00,  98.00,  146.83, 98.00,  130.81, 196.00, 146.83, 98.00
]

func _ready() -> void:
	_eng_player = AudioStreamPlayer.new()
	_eng_gen = AudioStreamGenerator.new()
	_eng_gen.mix_rate = 22050.0
	_eng_gen.buffer_length = 0.15
	_eng_player.stream = _eng_gen
	_eng_player.volume_db = -7.0
	add_child(_eng_player)
	_eng_player.play()
	_eng_pb = _eng_player.get_stream_playback() as AudioStreamGeneratorPlayback

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
	var step_len := 0.234
	_bgm_timer += delta
	if _bgm_timer >= step_len:
		_bgm_timer = 0.0
		_bgm_step = (_bgm_step + 1) % MELODY.size()

	if _chime_timer > 0.0:
		_chime_timer = maxf(0.0, _chime_timer - delta)

	var frames := _eng_pb.get_frames_available()
	if frames <= 0:
		return
	var eng_freq := 58.0 + throttle_val * 140.0 + minf(speed_val, 450.0) * 0.12
	var mel_freq: float = MELODY[_bgm_step]
	var bass_freq: float = BASSLINE[_bgm_step]
	var chord_freq: float = mel_freq * 0.5
	var inv_sr := 1.0 / 22050.0
	var env := maxf(0.0, 1.0 - (_bgm_timer / step_len))
	var hat_env := maxf(0.0, 1.0 - (_bgm_timer / 0.055)) if (_bgm_step % 2 == 1) else 0.0

	for i in range(frames):
		var s := 0.0
		if active:
			_phase = fmod(_phase + eng_freq * inv_sr, 1.0)
			var saw := (_phase * 2.0 - 1.0) * (0.06 + throttle_val * 0.14)
			var noise := (randf() * 2.0 - 1.0) * (0.02 + throttle_val * 0.07)
			s += (saw + noise) * 0.50
		if bgm_enabled:
			_bgm_phase = fmod(_bgm_phase + mel_freq * inv_sr, 1.0)
			_bass_phase = fmod(_bass_phase + bass_freq * inv_sr, 1.0)
			_chord_phase = fmod(_chord_phase + chord_freq * inv_sr, 1.0)
			var lead := (sin(_bgm_phase * TAU) * 0.7 + sin(_bgm_phase * TAU * 2.0) * 0.25) * 0.095 * env
			var bass := sin(_bass_phase * TAU) * 0.095 * (0.35 + 0.65 * env)
			var stab := sin(_chord_phase * TAU) * 0.045 * (env if (_bgm_step % 2 == 0) else 0.0)
			var hat := (randf() * 2.0 - 1.0) * 0.025 * hat_env
			s += lead + bass + stab + hat
		if _chime_timer > 0.0 and _chime_freqs.size() >= 3:
			var ci := mini(2, int((0.48 - _chime_timer) / 0.16))
			_chime_phase = fmod(_chime_phase + _chime_freqs[ci] * inv_sr, 1.0)
			s += sin(_chime_phase * TAU) * 0.18 * (_chime_timer / 0.48)
		_eng_pb.push_frame(Vector2(s, s))

func speak_mandarin(text: String) -> void:
	var voices := DisplayServer.tts_get_voices_for_language("zh")
	if voices.size() > 0:
		DisplayServer.tts_stop()
		DisplayServer.tts_speak(text, voices[0], 92, 1.04, 1.08)
