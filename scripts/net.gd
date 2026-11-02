extends Node
## Multiplayer 1×1 por WebRTC (autoload "Net").
##
## Sala: o anfitrião gera um código; o convidado digita o código. O aperto de mão do WebRTC
## (oferta, resposta e candidatos ICE) passa por um broker MQTT público (MqttSignal); depois
## os dois conversam direto (P2P) e o broker é fechado.
##
## Sala de espera: com os dois conectados, cada um escolhe nome e raça, conversa no chat e
## aperta PRONTO. O anfitrião guarda o estado da sala (`room`) e o repassa ao convidado; com
## os dois prontos começa uma contagem e a partida. Na partida, os dois carregam o mapa e o
## jogo só começa quando ambos avisam que terminaram (_loaded -> _go).
##
## Partida: o anfitrião (time 0) roda a simulação inteira, como no modo contra a IA. O
## convidado (time 1) não simula nada: envia as ordens (_order) e recebe ~15 vezes por segundo
## um retrato do jogo (_snap) que aplica nas suas unidades-espelho, com movimento suavizado.

signal status(text: String)
signal room_changed           # mudou alguém, raça ou pronto
signal chat(line: String)
signal countdown(seconds: int)   # -1 = contagem cancelada
signal started
signal go                     # os dois carregaram: a partida começa de verdade

const BROKER := "wss://broker.emqx.io:8084/mqtt"
const TOPIC := "starrts/v1/%s/%s"
const ICE := {"iceServers": [{"urls": ["stun:stun.l.google.com:19302", "stun:stun1.l.google.com:19302"]}]}
const CODE_CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const SNAP_RATE := 1.0 / 15.0
const COUNTDOWN := 3
## Campos por entidade no snapshot
const F := 12

var role := ""          # "", "host", "guest"
var active := false     # partida multiplayer em andamento
var connected := false  # os dois estão conectados (sala ou partida)
var waiting := false    # partida carregada, esperando o outro jogador
var code := ""
var map_seed := 0
## Sala: [anfitrião, convidado]; cada um {"name", "race", "ready"} ou {} se vazio
var room: Array = [{}, {}]
var names: Array = ["", ""]
var _sig: MqttSignal
var _pc: WebRTCPeerConnection
var _mp: WebRTCMultiplayerPeer
var _guest_tag := ""
var _snap_t := 0.0
var _ore_t := 0.0
var _count_t := -1.0
var _count_n := 0
var _loaded := [false, false]


## Multiplayer disponível? Por enquanto só na versão Web (o navegador já traz o WebRTC).
## No PC precisaria da extensão webrtc-native; o argumento --mp-test liga isso para testes.
static func available() -> bool:
	return OS.has_feature("web") or OS.get_cmdline_user_args().has("--mp-test")


func is_host() -> bool:
	return active and role == "host"


func is_client() -> bool:
	return active and role == "guest"


## Índice do jogador local na sala (0 anfitrião, 1 convidado).
func me() -> int:
	return 0 if role == "host" else 1


# ---------------------------------------------------------------- conexão

func host(my_name: String, my_race: String) -> void:
	_reset()
	role = "host"
	code = ""
	for i in 5:
		code += CODE_CHARS[randi() % CODE_CHARS.length()]
	room = [{"name": my_name, "race": my_race, "ready": false, "map": Game.map_size}, {}]
	_start_signal(TOPIC % [code, "host"])
	status.emit("Criando sala…")
	room_changed.emit()


func join(room_code: String, my_name: String) -> void:
	_reset()
	role = "guest"
	code = room_code.strip_edges().to_upper()
	room = [{}, {"name": my_name, "race": "", "ready": false}]
	_guest_tag = str(randi() % 1000000)
	_start_signal(TOPIC % [code, "guest-" + _guest_tag])
	status.emit("Procurando a sala %s…" % code)


func leave() -> void:
	_reset()


func _reset() -> void:
	_close_peer()
	if _sig != null:
		_sig.close()
	_sig = null
	role = ""
	active = false
	connected = false
	waiting = false
	_count_t = -1.0
	room = [{}, {}]
	Game.local_team = Game.PLAYER


func _close_peer() -> void:
	if _pc != null:
		_pc.close()
	_pc = null
	if _mp != null:
		_mp.close()
	_mp = null
	multiplayer.multiplayer_peer = null


func _start_signal(topic: String) -> void:
	_sig = MqttSignal.new()
	_sig.ready.connect(_on_signal_ready)
	_sig.received.connect(_on_signal)
	_sig.failed.connect(func(reason): status.emit(reason))
	_sig.start(BROKER, topic)


func _on_signal_ready() -> void:
	if role == "host":
		status.emit("Sala criada! Passe o código %s para o outro jogador." % code)
	else:
		_make_peer()
		_pc.create_offer()


func _send_signal(msg: Dictionary) -> void:
	var to := TOPIC % [code, "host" if role == "guest" else "guest-" + _guest_tag]
	msg["from"] = _guest_tag
	_sig.publish(to, JSON.stringify(msg))


func _on_signal(text: String) -> void:
	var msg = JSON.parse_string(text)
	if not (msg is Dictionary):
		return
	match String(msg.get("t", "")):
		"offer":
			if role != "host" or _pc != null:
				return # só um convidado por sala
			_guest_tag = String(msg.get("from", ""))
			status.emit("Jogador encontrado, conectando…")
			_make_peer()
			_pc.set_remote_description("offer", msg["sdp"])
		"answer":
			if role == "guest" and _pc != null:
				_pc.set_remote_description("answer", msg["sdp"])
		"cand":
			if _pc != null:
				_pc.add_ice_candidate(msg["m"], int(msg["i"]), msg["n"])


func _make_peer() -> void:
	_pc = WebRTCPeerConnection.new()
	if _pc.initialize(ICE) != OK:
		status.emit("WebRTC indisponível nesta plataforma")
		return
	_pc.session_description_created.connect(func(type, sdp):
		_pc.set_local_description(type, sdp)
		_send_signal({"t": type, "sdp": sdp}))
	_pc.ice_candidate_created.connect(func(media, index, cname):
		_send_signal({"t": "cand", "m": media, "i": index, "n": cname}))
	_mp = WebRTCMultiplayerPeer.new()
	if role == "host":
		_mp.create_server()
		_mp.add_peer(_pc, 2)
	else:
		_mp.create_client(2)
		_mp.add_peer(_pc, 1)
	multiplayer.multiplayer_peer = _mp


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)


func _on_peer_connected(_id: int) -> void:
	connected = true
	if _sig != null:
		_sig.close()   # o broker só serve para o aperto de mão
		_sig = null
	if role == "guest":
		status.emit("Conectado! Entrando na sala…")
		_hello.rpc_id(1, room[1]["name"])


func _on_peer_disconnected(_id: int) -> void:
	connected = false
	if active:
		if not Game.game_over:
			Game.message.emit("O outro jogador saiu da partida")
			Game.game_over = true
			Game.game_ended.emit(true)
		if waiting:
			waiting = false
			get_tree().paused = false
		return
	if role == "host":
		# Convidado saiu da sala: ela volta a esperar alguém com o mesmo código
		_add_chat("%s saiu da sala." % room[1].get("name", "O convidado"))
		_cancel_countdown()
		room[1] = {}
		room[0]["ready"] = false
		room_changed.emit()
		_close_peer()
		_start_signal(TOPIC % [code, "host"])
	else:
		status.emit("O anfitrião fechou a sala.")
		_reset()
		room_changed.emit()


func _process(delta: float) -> void:
	if _sig != null:
		_sig.poll(delta)
	if role == "host" and not active and _count_t >= 0.0:
		_count_t -= delta
		if _count_t <= 0.0:
			_count_n -= 1
			if _count_n <= 0:
				_count_t = -1.0
				_start.rpc(randi(), [room[0]["race"], room[1]["race"]], [room[0]["name"], room[1]["name"]], room_map())
			else:
				_count_t = 1.0
				_countdown.rpc(_count_n)
				countdown.emit(_count_n)
	if not is_host() or Game.map == null or Game.game_over or waiting:
		return
	_snap_t -= delta
	if _snap_t <= 0.0:
		_snap_t = SNAP_RATE
		_ore_t -= SNAP_RATE
		var with_ore := _ore_t <= 0.0
		if with_ore:
			_ore_t = 1.0
		_snap.rpc(_build_snapshot(with_ore))


# ---------------------------------------------------------------- sala de espera

## O jogador local escolhe uma raça (a do outro jogador fica bloqueada).
func set_race(r: String) -> void:
	_request(me(), {"race": r, "ready": false})


func set_ready(on: bool) -> void:
	_request(me(), {"ready": on})


## Tamanho do mapa: só o anfitrião escolhe (fica guardado na entrada dele na sala).
func set_map(size: String) -> void:
	if role == "host":
		_request(0, {"map": size})


func room_map() -> String:
	return String(room[0].get("map", "small"))


func send_chat(text: String) -> void:
	text = text.strip_edges().left(200)
	if text == "" or not connected and role != "host":
		return
	if role == "host":
		_say(0, text)
	else:
		_chat_in.rpc_id(1, text)


func _request(who: int, change: Dictionary) -> void:
	if role == "host":
		_apply_change(who, change)
	elif connected:
		_change_in.rpc_id(1, change)


## Só o anfitrião muda a sala; depois repassa a sala inteira ao convidado.
func _apply_change(who: int, change: Dictionary) -> void:
	var p: Dictionary = room[who]
	if p.is_empty():
		return
	var other: Dictionary = room[1 - who]
	if change.has("map") and who == 0 and Game.MAP_SIZES.has(String(change["map"])):
		# Mudou o mapa: os dois precisam confirmar de novo
		p["map"] = String(change["map"])
		p["ready"] = false
		if not other.is_empty():
			other["ready"] = false
		_add_chat("Mapa: %s." % Game.MAP_SIZES[p["map"]]["name"])
		if connected:
			_chat_out.rpc("Mapa: %s." % Game.MAP_SIZES[p["map"]]["name"])
	if change.has("race"):
		var r := String(change["race"])
		if Game.FACTIONS.has(r) and other.get("race", "") != r:
			p["race"] = r
		p["ready"] = false
	if change.has("ready"):
		p["ready"] = bool(change["ready"]) and Game.FACTIONS.has(p.get("race", ""))
	_broadcast_room()
	var all_ready: bool = not other.is_empty() and p["ready"] and other.get("ready", false)
	if all_ready and _count_t < 0.0:
		_count_n = COUNTDOWN
		_count_t = 1.0
		_countdown.rpc(_count_n)
		countdown.emit(_count_n)
	elif not all_ready:
		_cancel_countdown()


func _cancel_countdown() -> void:
	if _count_t >= 0.0:
		_count_t = -1.0
		if connected:
			_countdown.rpc(-1)
		countdown.emit(-1)


func _broadcast_room() -> void:
	room_changed.emit()
	if connected:
		_room.rpc(room)


func _say(who: int, text: String) -> void:
	var line := "%s: %s" % [room[who].get("name", "?"), text]
	_add_chat(line)
	if connected:
		_chat_out.rpc(line)


func _add_chat(line: String) -> void:
	chat.emit(line)


@rpc("any_peer", "call_remote", "reliable")
func _hello(guest_name: String) -> void:
	if role != "host" or active:
		return
	var taken: String = room[0]["race"]
	var free: String = Game.FACTIONS.keys().filter(func(k): return k != taken)[0]
	room[1] = {"name": guest_name.strip_edges().left(20), "race": free, "ready": false}
	room[0]["ready"] = false
	status.emit("%s entrou na sala!" % room[1]["name"])
	_add_chat("%s entrou na sala." % room[1]["name"])
	_broadcast_room()


@rpc("any_peer", "call_remote", "reliable")
func _change_in(change: Dictionary) -> void:
	if role == "host" and not active:
		_apply_change(1, change)


@rpc("any_peer", "call_remote", "reliable")
func _chat_in(text: String) -> void:
	if role == "host":
		_say(1, text.strip_edges().left(200))


@rpc("authority", "call_remote", "reliable")
func _room(state: Array) -> void:
	if role == "guest":
		if room[0].is_empty():
			status.emit("Você entrou na sala de %s." % state[0].get("name", "?"))
		room = state
		room_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _chat_out(line: String) -> void:
	_add_chat(line)


@rpc("authority", "call_remote", "reliable")
func _countdown(n: int) -> void:
	countdown.emit(n)


@rpc("authority", "call_local", "reliable")
func _start(seed_value: int, races: Array, player_names: Array, map_size: String) -> void:
	map_seed = seed_value
	Game.map_size = map_size
	active = true
	waiting = true
	_loaded = [false, false]
	names = player_names
	Game.player_faction = races[0]
	Game.net_factions = races
	Game.local_team = Game.PLAYER if role == "host" else Game.ENEMY
	started.emit()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main.tscn")


# ---------------------------------------------------------------- início sincronizado

## Chamado pela cena da partida quando terminou de carregar.
func scene_loaded() -> void:
	if not active:
		return
	# Deixa a névoa e a barra lateral desenharem uma vez; depois congela até os dois carregarem
	await get_tree().process_frame
	await get_tree().process_frame
	if waiting:
		get_tree().paused = true
	if role == "host":
		_mark_loaded(0)
	else:
		_loaded_in.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _loaded_in() -> void:
	if role == "host":
		_mark_loaded(1)


func _mark_loaded(who: int) -> void:
	_loaded[who] = true
	if _loaded[0] and _loaded[1]:
		_go.rpc()


@rpc("authority", "call_local", "reliable")
func _go() -> void:
	waiting = false
	get_tree().paused = false
	go.emit()


# ---------------------------------------------------------------- ordens do convidado

## Envia uma ordem ao anfitrião (chamado pelo convidado).
func order(kind: String, args: Array) -> void:
	if is_client():
		_order.rpc_id(1, kind, args)


@rpc("any_peer", "call_remote", "reliable")
func _order(kind: String, args: Array) -> void:
	if not is_host() or Game.game_over:
		return
	var T := Game.ENEMY
	match kind:
		"move", "attack_move", "patrol":
			var ids: Array = args[0]
			var goals: Array = args[1]
			for i in ids.size():
				var u = Game.by_id(int(ids[i]))
				if u is Unit and u.team == T:
					if kind == "move":
						u.command_move(goals[i])
					elif kind == "patrol":
						u.command_patrol(goals[i])
					else:
						u.command_attack_move(goals[i])
		"stop", "stance":
			for id in args[0]:
				var u = Game.by_id(int(id))
				if u is Unit and u.team == T:
					if kind == "stop":
						u.command_stop()
					else:
						u.set_stance(String(args[1]))
		"rally":
			var b = Game.by_id(int(args[0]))
			if b is Building and b.team == T:
				b.set_rally(args[1])
		"recycle":
			var b = Game.by_id(int(args[0]))
			if b is Building and b.team == T:
				b.recycle()
		"attack":
			var target = Game.by_id(int(args[1]))
			if target == null:
				return
			for id in args[0]:
				var u = Game.by_id(int(id))
				if u is Unit and u.team == T:
					u.command_attack(target)
		"produce":
			Game.start_production(T, String(args[0]))
		"cancel":
			Game.cancel_production(T, String(args[0]), String(args[1]))
		"place":
			Game.place_building(String(args[0]), T, args[1])
		"repair":
			var b = Game.by_id(int(args[0]))
			if b is Building and b.team == T:
				b.set_repairing(bool(args[1]))


# ---------------------------------------------------------------- eventos do anfitrião

## Prédio reciclado: o convidado o remove sem explosão (antes de o snapshot sumir com ele).
func send_recycled(id: int) -> void:
	if is_host():
		_recycled.rpc(id)


@rpc("authority", "call_remote", "reliable")
func _recycled(id: int) -> void:
	var b = Game.by_id(id)
	if b is Building and not b.dead:
		b.recycle()

func send_message(text: String) -> void:
	if is_host():
		_message.rpc(text)


@rpc("authority", "call_remote", "reliable")
func _message(text: String) -> void:
	Game.message.emit(text)


## Fim de partida: vai junto o retrato final (os snapshots param quando o jogo acaba).
func send_game_over(loser: int) -> void:
	if is_host():
		_game_over.rpc(loser, _build_snapshot(false))


@rpc("authority", "call_remote", "reliable")
func _game_over(loser: int, final_snap: PackedByteArray) -> void:
	_apply_snapshot(final_snap)
	Game.game_over = true
	Game.game_ended.emit(loser != Game.local_team)


# ---------------------------------------------------------------- snapshots

func _build_snapshot(with_ore: bool) -> PackedByteArray:
	var ents := PackedFloat32Array()
	ents.resize(Game.entities.size() * F)
	var k := 0
	for e in Game.entities:
		if e.dead:
			continue
		var flags := 0
		if e.has_target and e.valid_target(e.target):
			flags |= 1
		if e._fired:
			flags |= 2
			e._fired = false
		var x: float = e.position.x
		var y: float = e.position.y
		var ang := 0.0
		var extra := 0.0
		var aim := 0.0
		if e is Building:
			x = e.cell.x
			y = e.cell.y
			if e.repairing:
				flags |= 4
			if e.built:
				flags |= 8
			extra = e.build_t
			aim = e.aim.angle()
		else:
			ang = e.facing
			aim = e.aim_angle
			if e is Harvester:
				extra = e.cargo
		var tid: int = e.target.net_id if flags & 1 else 0
		var vals := [e.net_id, Game.type_index(e.type), e.team, x, y, e.hp, ang, flags, extra, tid, aim, 0.0]
		for j in F:
			ents[k + j] = vals[j]
		k += F
	ents.resize(k)
	var snap := {
		"e": ents, "c": Game.credits[Game.ENEMY],
		"p": Game.production[Game.ENEMY], "q": Game.queues[Game.ENEMY],
	}
	if with_ore:
		snap["o"] = Game.map.ore_bytes()
	return var_to_bytes(snap)


@rpc("authority", "call_remote", "unreliable_ordered")
func _snap(data: PackedByteArray) -> void:
	_apply_snapshot(data)


func _apply_snapshot(data: PackedByteArray) -> void:
	if not is_client() or Game.map == null or Game.world == null:
		return
	var snap = bytes_to_var(data)
	if not (snap is Dictionary):
		return
	var T := Game.local_team
	Game.credits[T] = snap["c"]
	Game.production[T] = snap["p"]
	Game.queues[T] = snap["q"]
	if snap.has("o"):
		Game.map.apply_ore_bytes(snap["o"])
	var ents: PackedFloat32Array = snap["e"]
	var seen := {}
	var fired: Array = []
	for k in range(0, ents.size(), F):
		var id := int(ents[k])
		seen[id] = true
		var e = Game.by_id(id)
		var type: String = Game.type_name(int(ents[k + 1]))
		var team := int(ents[k + 2])
		var flags := int(ents[k + 7])
		if e == null:
			e = _spawn_mirror(id, type, team, ents, k)
			if e == null:
				continue
		e.hp = ents[k + 5]
		var tid := int(ents[k + 9])
		e.set_target(Game.by_id(tid) if flags & 1 and tid != 0 else null)
		if e is Building:
			e.build_t = ents[k + 8]
			e.aim = Vector2.RIGHT.rotated(ents[k + 10])
			if bool(flags & 4) != e.repairing:
				e.set_repairing(bool(flags & 4))
		else:
			e.net_pos = Vector2(ents[k + 3], ents[k + 4])
			e.facing = ents[k + 6]
			e.aim_angle = ents[k + 10]
			if e is Harvester:
				e.cargo = ents[k + 8]
		if flags & 2 and e.has_target:
			fired.append(e)
	for e in fired:
		e.mirror_fire()
	# Quem sumiu do retrato foi destruído
	for e in Game.entities.duplicate():
		if not seen.has(e.net_id) and not e.dead:
			e.die()


func _spawn_mirror(id: int, type: String, team: int, ents: PackedFloat32Array, k: int):
	var e
	if Game.BUILDINGS.has(type):
		var built := int(ents[k + 7]) & 8 != 0
		e = Game.spawn_building(type, team, Vector2i(int(ents[k + 3]), int(ents[k + 4])), not built)
	elif Game.UNITS.has(type):
		e = Game.spawn_unit(type, team, Vector2(ents[k + 3], ents[k + 4]))
		e.net_pos = e.position
	else:
		return null
	Game.set_net_id(e, id)
	if e is Unit and team == Game.local_team and not waiting:
		Sfx.ui("ready")
	return e
