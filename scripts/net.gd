extends Node
## Multiplayer 1×1 por WebRTC (autoload "Net").
##
## Sala: o anfitrião gera um código; o convidado digita o código. O aperto de mão do WebRTC
## (oferta, resposta e candidatos ICE) passa por um broker MQTT público (MqttSignal); depois
## os dois conversam direto (P2P) e o broker é fechado.
##
## Partida: o anfitrião (time 0) roda a simulação inteira, como no modo contra a IA. O
## convidado (time 1) não simula nada: envia as ordens (_order) e recebe ~15 vezes por segundo
## um retrato do jogo (_snap) que aplica nas suas unidades-espelho, com movimento suavizado.

signal status(text: String)
signal started

const BROKER := "wss://broker.emqx.io:8084/mqtt"
const TOPIC := "starrts/v1/%s/%s"
const ICE := {"iceServers": [{"urls": ["stun:stun.l.google.com:19302", "stun:stun1.l.google.com:19302"]}]}
const CODE_CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const SNAP_RATE := 1.0 / 15.0
## Campos por entidade no snapshot
const F := 12

var role := ""          # "", "host", "guest"
var active := false     # partida multiplayer em andamento
var code := ""
var race := ""
var map_seed := 0
var _sig: MqttSignal
var _pc: WebRTCPeerConnection
var _mp: WebRTCMultiplayerPeer
var _guest_tag := ""
var _snap_t := 0.0
var _ore_t := 0.0
var _connected := false


## Multiplayer disponível? Por enquanto só na versão Web (o navegador já traz o WebRTC).
## No PC precisaria da extensão webrtc-native; o argumento --mp-test liga isso para testes.
static func available() -> bool:
	return OS.has_feature("web") or OS.get_cmdline_user_args().has("--mp-test")


func is_host() -> bool:
	return active and role == "host"


func is_client() -> bool:
	return active and role == "guest"


# ---------------------------------------------------------------- sala

func host(my_race: String) -> void:
	_reset()
	role = "host"
	race = my_race
	code = ""
	for i in 5:
		code += CODE_CHARS[randi() % CODE_CHARS.length()]
	_start_signal(TOPIC % [code, "host"])
	status.emit("Criando sala…")


func join(room: String, my_race: String) -> void:
	_reset()
	role = "guest"
	race = my_race
	code = room.strip_edges().to_upper()
	_guest_tag = str(randi() % 1000000)
	_start_signal(TOPIC % [code, "guest-" + _guest_tag])
	status.emit("Procurando a sala %s…" % code)


func leave() -> void:
	_reset()


func _reset() -> void:
	if _sig != null:
		_sig.close()
	_sig = null
	if _pc != null:
		_pc.close()
	_pc = null
	if _mp != null:
		_mp.close()
	_mp = null
	multiplayer.multiplayer_peer = null
	role = ""
	active = false
	_connected = false
	Game.local_team = Game.PLAYER


func _start_signal(topic: String) -> void:
	_sig = MqttSignal.new()
	_sig.ready.connect(_on_signal_ready)
	_sig.received.connect(_on_signal)
	_sig.failed.connect(func(reason): status.emit(reason))
	_sig.start(BROKER, topic)


func _on_signal_ready() -> void:
	if role == "host":
		status.emit("Sala criada! Código: %s\nPasse o código para o outro jogador e aguarde…" % code)
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
	_connected = true
	if _sig != null:
		_sig.close()   # o broker só serve para o aperto de mão
		_sig = null
	if role == "guest":
		status.emit("Conectado! Aguardando o anfitrião…")
		_hello.rpc_id(1, race)


func _on_peer_disconnected(_id: int) -> void:
	if active and not Game.game_over:
		Game.message.emit("O outro jogador saiu da partida")
		Game.game_over = true
		Game.game_ended.emit(true)
	elif not active:
		status.emit("O outro jogador desconectou")
	_connected = false


func _process(delta: float) -> void:
	if _sig != null:
		_sig.poll(delta)
	if not is_host() or Game.map == null or Game.game_over:
		return
	_snap_t -= delta
	if _snap_t <= 0.0:
		_snap_t = SNAP_RATE
		_ore_t -= SNAP_RATE
		var with_ore := _ore_t <= 0.0
		if with_ore:
			_ore_t = 1.0
		_snap.rpc(_build_snapshot(with_ore))


# ---------------------------------------------------------------- lobby (RPC)

@rpc("any_peer", "call_remote", "reliable")
func _hello(guest_race: String) -> void:
	if role != "host":
		return
	if guest_race == race:
		_reject.rpc_id(2, "O anfitrião já escolheu %s. Escolha outra raça." % Game.FACTIONS[race]["army"])
		return
	_start.rpc(randi(), race, guest_race)


@rpc("authority", "call_remote", "reliable")
func _reject(reason: String) -> void:
	status.emit(reason)
	_reset()


@rpc("authority", "call_local", "reliable")
func _start(seed_value: int, host_race: String, guest_race: String) -> void:
	map_seed = seed_value
	active = true
	Game.player_faction = host_race
	Game.net_factions = [host_race, guest_race]
	Game.local_team = Game.PLAYER if role == "host" else Game.ENEMY
	started.emit()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main.tscn")


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
		"move", "attack_move":
			var ids: Array = args[0]
			var goals: Array = args[1]
			for i in ids.size():
				var u = Game.by_id(int(ids[i]))
				if u is Unit and u.team == T:
					if kind == "move":
						u.command_move(goals[i])
					else:
						u.command_attack_move(goals[i])
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
	return e
