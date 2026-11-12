class_name Sfx
extends Node
## All sound is synthesised at start-up, so the game ships no audio files.

const RATE := 22050
var _players := {}
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = 99
	_add("bat", _make(0.22, func(t: float) -> float:
		return (_noise() * exp(-t * 60.0) + sin(TAU * 310.0 * t) * exp(-t * 28.0) * 0.8 + sin(TAU * 900.0 * t) * exp(-t * 55.0) * 0.4) * 0.8))
	_add("edge", _make(0.12, func(t: float) -> float:
		return (_noise() * exp(-t * 90.0) + sin(TAU * 1400.0 * t) * exp(-t * 70.0) * 0.5) * 0.6))
	_add("bounce", _make(0.14, func(t: float) -> float:
		return (sin(TAU * (150.0 - 300.0 * t) * t) * exp(-t * 35.0) + _noise() * exp(-t * 120.0) * 0.3) * 0.7))
	_add("stumps", _make(0.45, func(t: float) -> float:
		var s := 0.0
		for k in [0.0, 0.05, 0.11, 0.19]:
			if t > k:
				s += (sin(TAU * (700.0 + k * 3000.0) * (t - k)) + _noise() * 0.6) * exp(-(t - k) * 45.0)
		return s * 0.45))
	_add("whoosh", _make(0.25, func(t: float) -> float:
		return _noise() * sin(PI * t / 0.25) * 0.18))
	_add("cheer", _make(2.2, func(t: float) -> float:
		var env := minf(t / 0.25, 1.0) * exp(-maxf(t - 0.6, 0.0) * 1.6)
		return _crowd() * env * 0.9))
	_add("groan", _make(1.2, func(t: float) -> float:
		return _crowd() * minf(t / 0.15, 1.0) * exp(-t * 3.0) * 0.5))

var _lp := 0.0
var _lp2 := 0.0

func _noise() -> float:
	return _rng.randf_range(-1.0, 1.0)

func _crowd() -> float:
	# Band-limited noise reads as a distant roar.
	_lp = lerpf(_lp, _noise(), 0.18)
	_lp2 = lerpf(_lp2, _lp, 0.35)
	return (_lp - _lp2 * 0.6) * 3.0

func _make(length: float, f: Callable) -> AudioStreamWAV:
	var n := int(length * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var v := clampf(f.call(float(i) / RATE), -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	return w

func _add(key: String, stream: AudioStream) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	add_child(p)
	_players[key] = p

func play(key: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var p: AudioStreamPlayer = _players[key]
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()
