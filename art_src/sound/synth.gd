extends SceneTree
## Gera os sons sintetizados do jogo (os que não têm opção CC0 boa): vento, cristais, asas de
## inseto, servo de robô, choque elétrico, ácido, fogo e trovão. Tudo original (CC0).
## Uso: Godot_console --headless -s art_src/sound/synth.gd -- <pasta de saída>

const RATE := 22050
var rng := RandomNumberGenerator.new()


func _initialize() -> void:
	rng.seed = 2026
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "sounds/synth"
	DirAccess.make_dir_recursive_absolute(out)
	_save(out + "/wind_loop.wav", _loopify(_wind(12.0), 1.5))
	_save(out + "/crystal_hum_loop.wav", _loopify(_crystal(8.0), 1.0))
	_save(out + "/insect_wings.wav", _wings(1.1, 185.0))
	_save(out + "/insect_wings_low.wav", _wings(1.4, 95.0))
	_save(out + "/robot_servo_1.wav", _servo(0.35, 900.0, 1500.0))
	_save(out + "/robot_servo_2.wav", _servo(0.45, 700.0, 1200.0))
	_save(out + "/robot_hover_loop.wav", _loopify(_hover(4.0), 0.5))
	_save(out + "/electric_zap_1.wav", _zap(0.5))
	_save(out + "/electric_zap_2.wav", _zap(0.8))
	_save(out + "/acid_sizzle.wav", _sizzle(0.9))
	_save(out + "/fire_loop.wav", _loopify(_fire(5.0), 0.6))
	_save(out + "/thunder_far_1.wav", _thunder(4.0))
	_save(out + "/thunder_far_2.wav", _thunder(5.5))
	print("sons gerados em ", out)
	quit()


# ---------------------------------------------------------------- utilitários

func _noise() -> float:
	return rng.randf_range(-1.0, 1.0)


## Filtro passa-baixa de um polo; k = 0..1 (maior = mais agudo)
func _lowpass(s: PackedFloat32Array, k: float) -> PackedFloat32Array:
	var y := 0.0
	for i in s.size():
		y += (s[i] - y) * k
		s[i] = y
	return s


func _normalize(s: PackedFloat32Array, peak := 0.85) -> PackedFloat32Array:
	var m := 0.0001
	for v in s:
		m = maxf(m, absf(v))
	for i in s.size():
		s[i] = s[i] / m * peak
	return s


## Fade de entrada/saída curto (sem estalos)
func _fade(s: PackedFloat32Array, a := 0.01, b := 0.05) -> PackedFloat32Array:
	var na := int(a * RATE)
	var nb := int(b * RATE)
	for i in mini(na, s.size()):
		s[i] *= float(i) / na
	for i in mini(nb, s.size()):
		s[s.size() - 1 - i] *= float(i) / nb
	return s


## Loop sem emenda: o fim é misturado com o começo (crossfade de `xf` segundos)
func _loopify(s: PackedFloat32Array, xf: float) -> PackedFloat32Array:
	var n := int(xf * RATE)
	var out := s.slice(0, s.size() - n)
	for i in n:
		var t := float(i) / n
		out[i] = s[i] * t + s[s.size() - n + i] * (1.0 - t)
	return out


func _save(path: String, s: PackedFloat32Array) -> void:
	var data := PackedByteArray()
	data.resize(s.size() * 2)
	for i in s.size():
		data.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 32767.0))
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer("RIFF".to_ascii_buffer())
	f.store_32(36 + data.size())
	f.store_buffer("WAVEfmt ".to_ascii_buffer())
	f.store_32(16)
	f.store_16(1)          # PCM
	f.store_16(1)          # mono
	f.store_32(RATE)
	f.store_32(RATE * 2)
	f.store_16(2)
	f.store_16(16)
	f.store_buffer("data".to_ascii_buffer())
	f.store_32(data.size())
	f.store_buffer(data)
	f.close()


func _buf(sec: float) -> PackedFloat32Array:
	var s := PackedFloat32Array()
	s.resize(int(sec * RATE))
	return s


# ---------------------------------------------------------------- sons

## Vento alienígena: ruído filtrado com rajadas lentas e um assobio que sobe e desce
func _wind(sec: float) -> PackedFloat32Array:
	var s := _buf(sec)
	var y1 := 0.0
	var y2 := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var gust := 0.55 + 0.45 * sin(t * 0.7) * sin(t * 0.23 + 1.0)
		var k := 0.02 + 0.03 * gust
		y1 += (_noise() - y1) * k
		y2 += (y1 - y2) * k
		var whistle := sin(TAU * (420.0 + 90.0 * sin(t * 0.5)) * t) * 0.04 * gust
		s[i] = y2 * (0.6 + 0.8 * gust) + whistle
	return _normalize(s, 0.7)


## Cristais: acorde de senos com batimento lento e brilho cintilante
func _crystal(sec: float) -> PackedFloat32Array:
	var s := _buf(sec)
	var freqs := [220.0, 330.5, 441.0, 662.0, 881.5]
	for i in s.size():
		var t := float(i) / RATE
		var v := 0.0
		for j in freqs.size():
			v += sin(TAU * freqs[j] * t + j) * (0.5 + 0.5 * sin(t * (0.6 + j * 0.37))) / (j + 1.0)
		v += sin(TAU * 1763.0 * t) * 0.05 * maxf(0.0, sin(t * 3.1))
		s[i] = v
	return _normalize(s, 0.6)


## Asas de inseto: dente de serra com modulação rápida (zumbido) e ruído
func _wings(sec: float, f0: float) -> PackedFloat32Array:
	var s := _buf(sec)
	var ph := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var f := f0 * (1.0 + 0.04 * sin(t * 9.0))
		ph = fmod(ph + f / RATE, 1.0)
		var saw := ph * 2.0 - 1.0
		var flutter := 0.6 + 0.4 * sin(TAU * 28.0 * t)
		var env := minf(1.0, t * 8.0) * minf(1.0, (sec - t) * 4.0)
		s[i] = (saw * 0.7 + _noise() * 0.3) * flutter * env
	return _fade(_normalize(_lowpass(s, 0.35)))


## Servo de robô: gemido que sobe de tom com engrenagem
func _servo(sec: float, f0: float, f1: float) -> PackedFloat32Array:
	var s := _buf(sec)
	var ph := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var k := t / sec
		var f := lerpf(f0, f1, smoothstep(0.0, 1.0, k))
		ph += f / RATE
		var tone := sin(TAU * ph) * 0.6 + sin(TAU * ph * 2.01) * 0.25
		var grind := 1.0 if fmod(t * 140.0, 1.0) < 0.5 else 0.7
		s[i] = tone * grind * sin(PI * k)
	return _fade(_normalize(s, 0.6))


## Zumbido de antigravidade (veículos hover dos robôs)
func _hover(sec: float) -> PackedFloat32Array:
	var s := _buf(sec)
	for i in s.size():
		var t := float(i) / RATE
		s[i] = sin(TAU * 62.0 * t) * 0.6 + sin(TAU * 124.5 * t) * 0.25 + sin(TAU * 311.0 * t) * 0.08 * (0.5 + 0.5 * sin(t * 6.0))
	return _normalize(s, 0.6)


## Choque elétrico: estalos aleatórios sobre um zumbido de 50 Hz
func _zap(sec: float) -> PackedFloat32Array:
	var s := _buf(sec)
	var crack := 0.0
	for i in s.size():
		var t := float(i) / RATE
		if rng.randf() < 0.004:
			crack = 1.0
		crack *= 0.995
		var buzz := signf(sin(TAU * 100.0 * t)) * 0.3
		s[i] = (_noise() * crack + buzz * 0.5) * exp(-t * 4.0)
	return _fade(_normalize(s))


## Ácido chiando: ruído agudo com bolhas
func _sizzle(sec: float) -> PackedFloat32Array:
	var s := _buf(sec)
	var prev := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var n := _noise()
		var hp := n - prev
		prev = n
		var bubble := sin(TAU * (300.0 + 200.0 * sin(t * 40.0)) * t) * 0.2 if rng.randf() < 0.3 else 0.0
		s[i] = (hp * 0.7 + bubble) * exp(-t * 3.0) * minf(1.0, t * 40.0)
	return _fade(_normalize(s, 0.7))


## Fogo: chiado grave com estalos
func _fire(sec: float) -> PackedFloat32Array:
	var s := _lowpass(_buf(sec), 0.1)
	var y := 0.0
	var pop := 0.0
	for i in s.size():
		y += (_noise() - y) * 0.05
		if rng.randf() < 0.0012:
			pop = rng.randf_range(0.5, 1.0)
		pop *= 0.985
		s[i] = y * 0.8 + _noise() * pop * 0.6
	return _normalize(s, 0.6)


## Trovão distante: ruído grave com ronco que demora a morrer
func _thunder(sec: float) -> PackedFloat32Array:
	var s := _buf(sec)
	var y1 := 0.0
	var y2 := 0.0
	for i in s.size():
		var t := float(i) / RATE
		y1 += (_noise() - y1) * 0.012
		y2 += (y1 - y2) * 0.012
		var env := minf(1.0, t * 3.0) * exp(-t * 0.9) * (0.7 + 0.3 * sin(t * 5.0))
		s[i] = y2 * env
	return _fade(_normalize(s, 0.8), 0.05, 0.5)
