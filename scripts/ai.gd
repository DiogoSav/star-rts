class_name EnemyAI
extends Node
## IA simples: mantém coletores, produz tropas e ataca em ondas cada vez maiores.

const TEAM := 1
const PLAYER := 0
## Pesos na lista da facção: fuzileiro, submetralhadora, metralhadora, antitanque, atirador
const INF_WEIGHTS := [4, 3, 2, 3, 1]
## coletor (só pela regra da economia), batedor, tanque, pesado
const VEH_WEIGHTS := [0, 2, 3, 1]
## caça, nave pesada
const AIR_WEIGHTS := [3, 2]

var think := 3.0
var wave_size := 8
var wave_timer := 180.0
var first_wave_sent := false


func _process(delta: float) -> void:
	if Game.game_over:
		return
	wave_timer -= delta
	think -= delta
	if think > 0.0:
		return
	think = 1.5

	var fac := Game.faction(TEAM)
	var harvesters := 0
	var army: Array = []
	for e in Game.entities:
		if e.team == TEAM and e is Unit:
			if e is Harvester:
				harvesters += 1
			else:
				army.append(e)

	var queue: Dictionary = Game.production[TEAM]
	# Economia primeiro
	if harvesters < 2 and not queue.has("vehicle"):
		Game.start_production(TEAM, fac["harvester"])
	# Exército: não acumula muito além do tamanho da próxima onda
	var army_full := army.size() >= wave_size + 4
	if not queue.has("infantry") and not army_full:
		Game.start_production(TEAM, fac["infantry"][_pick(INF_WEIGHTS)])
	if not queue.has("vehicle") and harvesters >= 1 and not army_full:
		Game.start_production(TEAM, fac["vehicles"][_pick(VEH_WEIGHTS)])
	if not queue.has("air") and harvesters >= 1 and not army_full:
		Game.start_production(TEAM, fac["air"][_pick(AIR_WEIGHTS)])

	# Ataque: a primeira onda só sai pelo tempo, dando ao jogador tempo de montar a base.
	# Depois, ataca quando o exército fica grande o bastante (ou depois de um tempo).
	var ready := first_wave_sent and army.size() >= wave_size
	if ready or (wave_timer <= 0.0 and army.size() >= 3):
		var goal = _player_target()
		if goal != null:
			for u in army.slice(0, wave_size):
				u.command_attack_move(goal.position)
			first_wave_sent = true
			wave_size = mini(wave_size + 2, 16)
			wave_timer = 120.0


func _player_target():
	var base := Vector2(Map.fit(Vector2i(55, 10), Vector2(1, 0))) * Game.TILE
	var best = null
	var best_d := INF
	for e in Game.entities:
		if e.team == PLAYER and e is Building:
			var d: float = base.distance_to(e.position)
			if d < best_d:
				best_d = d
				best = e
	return best


func _pick(weights: Array) -> int:
	var total := 0
	for w in weights:
		total += w
	var r := randi_range(0, total - 1)
	for i in weights.size():
		r -= weights[i]
		if r < 0:
			return i
	return 0
