extends Node
## Som do jogo (autoload "Sfx"): três canais com volume próprio, banco de sons por raça,
## sons posicionais no mundo 3D e música que muda entre calma e combate.
##
## Canais (barramentos do AudioServer): "Efeitos" (unidades, combate, interface),
## "Ambiente" (vento, cristais, reatores, fogo, trovões) e "Musica".
##
## Banco: res://sounds/<grupo>/<evento>_<n>.<ogg|wav|mp3> vira a chave "<grupo>/<evento>" com
## todas as variações (sorteadas a cada vez). Grupos: hum, rob, ins (raças), shared, ui,
## ambience, music. Eventos de unidade: select, order, attack, shot_light, shot_pulse,
## shot_heavy, death_inf, death_zap, death_squish, build, move_veh, move_air, alert, lost, kill.

const BUSES := ["Efeitos", "Ambiente", "Musica"]
const DEFAULT_VOLUME := {"Efeitos": 0.8, "Ambiente": 0.6, "Musica": 0.45}
const SETTINGS := "user://settings.cfg"
const DIR := "res://sounds/"
const POOL := 28
## Combate esquenta a música a partir desta intensidade (tiros recentes envolvendo você)
const BATTLE_ON := 7.0
const BATTLE_CALM_TIME := 14.0

var volumes := DEFAULT_VOLUME.duplicate()
var _bank := {}
var _pool: Array = []
var _pool_i := 0
var _last := {}
var _music: Array = []        # dois tocadores para a transição suave
var _music_kind := ""
var _music_i := 0
var _intensity := 0.0
var _calm_t := 0.0
var _alert_t := -100.0
var _lost_t := -100.0
var _base_alert_t := -100.0
## Último prédio atacado (a barra de espaço leva a câmera até ele)
var last_alert_pos := Vector2(-1, -1)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for b in BUSES:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")
	_load_settings()
	_scan()
	for i in POOL:
		var p := AudioStreamPlayer3D.new()
		p.bus = "Efeitos"
		p.unit_size = 14.0
		p.max_distance = 80.0
		p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		p.attenuation_filter_cutoff_hz = 20500.0
		add_child(p)
		_pool.append(p)
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.bus = "Musica"
		m.volume_db = -80.0
		add_child(m)
		_music.append(m)


# ---------------------------------------------------------------- banco

func _scan() -> void:
	var groups := DirAccess.get_directories_at(DIR)
	for g in groups:
		for f in DirAccess.get_files_at(DIR + g):
			# no jogo exportado os arquivos aparecem como "x.ogg.import"
			var file := f.trim_suffix(".import").trim_suffix(".remap")
			var ext := file.get_extension()
			if not ext in ["ogg", "wav", "mp3"]:
				continue
			var base := file.get_basename()
			var key := g + "/" + _event_name(base)
			var stream = load(DIR + g + "/" + file)
			if stream == null:
				continue
			if base.ends_with("_loop") or g == "music" or base.begins_with("reactor"):
				_set_loop(stream)
			if not _bank.has(key):
				_bank[key] = []
			if not _bank[key].has(stream):
				_bank[key].append(stream)


## Eventos conhecidos; o nome do arquivo começa pelo evento ("shot_light_3", "build_eat_01").
const EVENTS := ["shot_light", "shot_pulse", "shot_heavy", "death_inf", "death_zap", "death_squish",
		"select", "order", "attack", "kill", "alert", "lost", "build", "building_ready", "move_veh",
		"move_air", "step_heavy", "wings_flap", "acid_sizzle", "explosion_big", "explosion", "impact",
		"click", "error", "ready", "toggle", "tick", "wind", "crystal_hum", "fire", "thunder",
		"reactor", "menu", "game", "battle"]


## Evento de um arquivo: o mais longo de EVENTS que bate com o começo do nome.
func _event_name(base: String) -> String:
	var best := ""
	for ev in EVENTS:
		if (base == ev or base.begins_with(ev + "_")) and ev.length() > best.length():
			best = ev
	return best if best != "" else base


func _set_loop(stream) -> void:
	if stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
		stream.loop = true
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * stream.mix_rate)


func has(key: String) -> bool:
	return _bank.has(key)


func pick(key: String) -> AudioStream:
	var list: Array = _bank.get(key, [])
	return null if list.is_empty() else list.pick_random()


# ---------------------------------------------------------------- tocar

## Som posicional no mundo. `cooldown` evita o mesmo som repetido no mesmo instante.
func play3d(key: String, pos: Vector3, vol_db := 0.0, cooldown := 0.06, pitch_var := 0.07) -> void:
	var s := pick(key)
	if s == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last.get(key, -10.0)) < cooldown:
		return
	_last[key] = now
	var p: AudioStreamPlayer3D = _pool[_pool_i]
	_pool_i = (_pool_i + 1) % POOL
	p.stop()
	p.stream = s
	p.global_position = pos
	p.volume_db = vol_db
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.play()


## Som sem posição (interface, falas, alertas).
func play2d(key: String, vol_db := 0.0, bus := "Efeitos", cooldown := 0.08) -> void:
	var s := pick(key)
	if s == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last.get(key, -10.0)) < cooldown:
		return
	_last[key] = now
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.bus = bus
	p.volume_db = vol_db
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


func ui(event: String) -> void:
	play2d("ui/" + event, -4.0)


## Tocador em loop preso a um nó do mundo (cristais, reatores, fogo, motores).
func loop3d(key: String, parent: Node3D, vol_db := 0.0, bus := "Ambiente", reach := 24.0) -> AudioStreamPlayer3D:
	var s := pick(key)
	if s == null:
		return null
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.bus = bus
	p.volume_db = vol_db
	p.unit_size = reach * 0.35
	p.max_distance = reach
	p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
	parent.add_child(p)
	p.play(randf() * maxf(s.get_length() - 0.1, 0.0))
	return p


# ---------------------------------------------------------------- eventos do jogo

func _race(e) -> String:
	return String(Game.factions[e.team])


## Som da raça; se a raça não tiver esse evento, usa o comum (shared).
func _race_key(race: String, event: String) -> String:
	return race + "/" + event if _bank.has(race + "/" + event) else "shared/" + event


func weapon(e) -> void:
	if not e.visible:
		return
	var w := String(e.weapon.get("type", ""))
	var ev := "shot_light"
	if w == "mg":
		ev = "shot_pulse"
	elif w in Game.PROJECTILE_WEAPONS:
		ev = "shot_heavy"
	var vol := -9.0 if ev == "shot_pulse" else (-5.0 if ev == "shot_heavy" else -8.0)
	play3d(_race_key(_race(e), ev), e.muzzle_point(), vol, 0.05)
	if e.team == Game.local_team or (e.has_target and is_instance_valid(e.target) and e.target.team == Game.local_team):
		_intensity += 1.0 if ev != "shot_pulse" else 0.35


func explosion(pos: Vector3, size: float) -> void:
	if size >= 40.0:
		play3d("shared/explosion_big", pos, 0.0, 0.08)
	elif size >= 16.0:
		play3d("shared/explosion", pos, -3.0, 0.05)
	else:
		play3d("shared/impact", pos, -10.0, 0.05)


func death(e) -> void:
	if not e.visible:
		return
	var race := _race(e)
	var pos: Vector3 = e.center3d()
	if e is Unit and e.is_infantry:
		play3d(_race_key(race, "death_inf"), pos, -4.0, 0.1)
	elif race == "rob":
		play3d("rob/death_zap", pos, -6.0, 0.1)
	elif race == "ins":
		play3d("ins/death_squish", pos, -2.0, 0.1)
	if e.team == Game.local_team and e is Unit:
		var now := Time.get_ticks_msec() / 1000.0
		if now - _lost_t > 9.0 and _bank.has(race + "/lost"):
			_lost_t = now
			play2d(race + "/lost", -2.0)


## O jogador selecionou unidades suas: a raça responde.
func selected(e) -> void:
	play2d(_race_key(_race(e), "select"), -3.0, "Efeitos", 0.35)


## Ordem dada: resposta da raça (ataque tem fala própria quando existe).
func ordered(e, attack: bool) -> void:
	var race := _race(e)
	var ev := "attack" if attack and _bank.has(race + "/attack") else "order"
	play2d(_race_key(race, ev), -3.0, "Efeitos", 0.3)
	# veículos e naves: ronco do motor ao partir
	if e is Unit and not e.is_infantry:
		var mv := "move_air" if e.flying else "move_veh"
		if _bank.has(race + "/" + mv):
			play3d(race + "/" + mv, e.center3d(), -10.0, 0.4)
		elif e.flying and race == "ins":
			play3d("ins/move_air", e.center3d(), -8.0, 0.4)


## Algo seu levou dano: alerta de ataque (no máximo a cada 25 s).
func hit(e) -> void:
	if e.team != Game.local_team or e is Building:
		return   # prédios têm o alerta próprio (building_attacked)
	var now := Time.get_ticks_msec() / 1000.0
	if now - _alert_t < 25.0:
		return
	_alert_t = now
	var race := _race(e)
	play2d(race + "/alert" if _bank.has(race + "/alert") else "ui/alert", -1.0)
	Game.message.emit("Estamos sob ataque!")


## Prédio do jogador perdendo vida: alerta com o nome dele (no máximo um a cada 12 s).
func building_attacked(b) -> void:
	last_alert_pos = b.position
	var now := Time.get_ticks_msec() / 1000.0
	if now - _base_alert_t < 12.0:
		return
	_base_alert_t = now
	var race := _race(b)
	play2d(race + "/alert" if _bank.has(race + "/alert") else "ui/alert", 0.0)
	Game.message.emit("ALERTA: %s sob ataque!  (Espaço: ir até lá)" % Game.item_name(b.type, b.team))


func build(b) -> void:
	if b.visible:
		play3d(_race_key(_race(b), "build"), b.center3d(), -4.0, 0.2)


# ---------------------------------------------------------------- música

## "menu", "game" ou "battle". Troca com transição suave.
func music(kind: String) -> void:
	if kind == _music_kind:
		return
	_music_kind = kind
	var key: String = {"menu": "music/menu", "game": "music/game", "battle": "music/battle"}.get(kind, "")
	var s := pick(key)
	var old: AudioStreamPlayer = _music[_music_i]
	_music_i = 1 - _music_i
	var nu: AudioStreamPlayer = _music[_music_i]
	var tw := create_tween().set_parallel(true)
	tw.tween_property(old, "volume_db", -80.0, 2.5)
	tw.chain().tween_callback(old.stop)
	if s != null:
		nu.stream = s
		nu.volume_db = -40.0
		nu.play()
		create_tween().tween_property(nu, "volume_db", 0.0, 2.5)


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	_intensity = maxf(0.0, _intensity - delta * 0.6)
	if _music_kind == "game" and _intensity >= BATTLE_ON:
		music("battle")
		_calm_t = 0.0
	elif _music_kind == "battle":
		_calm_t = _calm_t + delta if _intensity < 1.0 else 0.0
		if _calm_t > BATTLE_CALM_TIME:
			music("game")


# ---------------------------------------------------------------- volume

func set_volume(bus: String, v: float) -> void:
	volumes[bus] = clampf(v, 0.0, 1.0)
	var i := AudioServer.get_bus_index(bus)
	if i >= 0:
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(volumes[bus], 0.0001)))
		AudioServer.set_bus_mute(i, volumes[bus] <= 0.001)
	_save_settings()


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS) == OK:
		for b in BUSES:
			volumes[b] = float(cfg.get_value("audio", b, volumes[b]))
	for b in BUSES:
		var i := AudioServer.get_bus_index(b)
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(volumes[b], 0.0001)))
		AudioServer.set_bus_mute(i, volumes[b] <= 0.001)


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	for b in BUSES:
		cfg.set_value("audio", b, volumes[b])
	cfg.save(SETTINGS)


## Painel com os três controles (menu principal e pausa).
func make_volume_panel(font_size := 22) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	var names := {"Efeitos": "Efeitos (unidades e combate)", "Ambiente": "Ambiente (mapa)", "Musica": "Música"}
	for b in BUSES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var l := Label.new()
		l.text = names[b]
		l.custom_minimum_size = Vector2(380, 0)
		l.add_theme_font_size_override("font_size", font_size)
		row.add_child(l)
		var sl := HSlider.new()
		sl.min_value = 0.0
		sl.max_value = 100.0
		sl.step = 5.0
		sl.value = volumes[b] * 100.0
		sl.custom_minimum_size = Vector2(320, 30)
		sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sl.focus_mode = Control.FOCUS_NONE
		row.add_child(sl)
		var pct := Label.new()
		pct.text = "%d%%" % int(sl.value)
		pct.custom_minimum_size = Vector2(70, 0)
		pct.add_theme_font_size_override("font_size", font_size)
		row.add_child(pct)
		sl.value_changed.connect(func(v):
			pct.text = "%d%%" % int(v)
			set_volume(b, v / 100.0)
			if b == "Efeitos":
				ui("tick"))
		box.add_child(row)
	return box
