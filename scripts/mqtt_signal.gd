class_name MqttSignal
extends RefCounted
## Cliente MQTT 3.1.1 mínimo sobre WebSocket, usado só para a "sinalização" do multiplayer:
## os dois jogadores trocam o aperto de mão do WebRTC (oferta, resposta, candidatos) por um
## broker público. Depois que o WebRTC conecta, o broker não é mais usado.

signal ready                         # conectado e inscrito no tópico
signal received(text: String)
signal failed(reason: String)

var ws := WebSocketPeer.new()
var _topic := ""
var _state := 0      # 0 desligado, 1 abrindo, 2 aguardando CONNACK, 3 aguardando SUBACK, 4 pronto
var _ping := 0.0


## Conecta ao broker e se inscreve em `topic` (onde chegam as mensagens para este jogador).
func start(url: String, topic: String) -> void:
	_topic = topic
	ws.supported_protocols = PackedStringArray(["mqtt"])
	if ws.connect_to_url(url) != OK:
		failed.emit("Não foi possível abrir a conexão com o servidor de salas")
		return
	_state = 1


func publish(topic: String, text: String) -> void:
	if _state != 4:
		return
	var body := _str(topic)
	body.append_array(text.to_utf8_buffer())
	_packet(0x30, body)


func close() -> void:
	if _state > 0:
		ws.put_packet(PackedByteArray([0xE0, 0]))   # DISCONNECT
		ws.close()
	_state = 0


func poll(delta: float) -> void:
	if _state == 0:
		return
	ws.poll()
	var st := ws.get_ready_state()
	if st == WebSocketPeer.STATE_CLOSED:
		_state = 0
		failed.emit("Conexão com o servidor de salas fechada (%d)" % ws.get_close_code())
		return
	if st != WebSocketPeer.STATE_OPEN:
		return
	if _state == 1:
		var body := _str("MQTT")
		body.append_array(PackedByteArray([4, 2, 0, 60]))   # nível 4, sessão limpa, keepalive 60 s
		body.append_array(_str("starrts-%d" % randi()))
		_packet(0x10, body)
		_state = 2
	_ping -= delta
	if _state == 4 and _ping <= 0.0:
		_ping = 25.0
		ws.put_packet(PackedByteArray([0xC0, 0]))   # PINGREQ
	while ws.get_available_packet_count() > 0:
		_handle(ws.get_packet())


func _handle(p: PackedByteArray) -> void:
	var type := p[0] >> 4
	if type == 2 and _state == 2:          # CONNACK
		if p[3] != 0:
			failed.emit("Servidor de salas recusou a conexão")
			return
		var body := PackedByteArray([0, 1])
		body.append_array(_str(_topic))
		body.append(0)
		_packet(0x82, body)
		_state = 3
	elif type == 9 and _state == 3:        # SUBACK
		_state = 4
		ready.emit()
	elif type == 3:                        # PUBLISH (QoS 0)
		var i := 1
		while p[i] & 128 != 0:
			i += 1
		i += 1
		var tl := (p[i] << 8) | p[i + 1]
		received.emit(p.slice(i + 2 + tl).get_string_from_utf8())


func _packet(header: int, body: PackedByteArray) -> void:
	var p := PackedByteArray([header])
	var n := body.size()
	while true:
		var b := n % 128
		n /= 128
		if n > 0:
			b |= 128
		p.append(b)
		if n == 0:
			break
	p.append_array(body)
	ws.put_packet(p)


static func _str(s: String) -> PackedByteArray:
	var b := s.to_utf8_buffer()
	var out := PackedByteArray([b.size() >> 8, b.size() & 255])
	out.append_array(b)
	return out
