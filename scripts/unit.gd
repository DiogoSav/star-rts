class_name Unit
extends Entity
## Unidade móvel: segue caminho do A* (naves voam em linha reta), procura inimigos e ataca.

var speed := 50.0
var path := PackedVector2Array()
var path_index := 0
var facing := 0.0
var forced_target := false   # ataque ordenado diretamente
var attack_move := false     # andar atacando o que encontrar
var attack_goal := Vector2.ZERO
var guarding := false         # perseguindo por conta própria; volta para guard_pos depois
var guard_pos := Vector2.ZERO
var repath_timer := 0.0
var scan_timer := 0.0
var is_infantry := true
var hover := false
var moving := false
var anim_t := 0.0
var _last_pos := Vector2.ZERO
var stuck_t := 0.0
var _stuck_ref := Vector2.ZERO
var body_angle := 0.0        # rotação visual do casco (segue `facing` suavemente)
var aim_angle := 0.0         # direção do alvo
var turret_angle := 0.0      # rotação da torre no mundo
var _bank := 0.0             # inclinação das naves nas curvas
var _lift := 0.0             # decolagem (0..1) das naves recém-construídas
var turret: Node3D
var legs: Array = []
var limbs: Array = []
var stride := 0.3            # comprimento do passo (unidades do mundo)
var gait := 0.0              # fase da marcha: avança com a distância andada (pés não deslizam)
var walk_w := 0.0            # peso da marcha (0 parado .. 1 andando), com transição suave
var _moved := 0.0
var wheels: Array = []
var treads: Array = []
var segs: Array = []
var _roll := 0.0             # distância total rodada (rodas e esteiras)
var _speed := 0.0            # velocidade suavizada (unidades/s)
var _accel := 0.0
var _pitch := 0.0
var _lean := 0.0
var _steer := 0.0
var _recoil := 0.0
var net_pos := Vector2.ZERO    # posição recebida do anfitrião (multiplayer, convidado)
var wings: Array = []
var spins: Array = []
var torso: Node3D
var _torso_y := 0.0
var _turret_y := 0.0
var _trails: Array = []


func setup(t: String, tm: int) -> void:
	type = t
	team = tm
	data = Game.UNITS[t]
	max_hp = float(data["hp"])
	hp = max_hp
	speed = float(data["speed"])
	radius = float(data["radius"])
	sight = int(data["sight"])
	armor = String(data["armor"])
	weapon = data["weapon"]
	is_infantry = data["kind"] == "inf"
	flying = data["kind"] == "air"
	hover = data.get("hover", false)
	altitude = 0.0
	scan_timer = randf() * 0.4
	facing = PI / 2.0 if tm == Game.PLAYER else -PI / 2.0
	anim_t = randf() * 10.0
	make_visuals(t)
	_make_parts()


# ---------------------------------------------------------------- comandos

func command_move(goal: Vector2) -> void:
	set_target(null)
	forced_target = false
	attack_move = false
	guarding = false
	_set_path(goal)


func command_attack(t: Entity) -> void:
	if weapon.is_empty() or not can_hit(t):
		command_move(t.position)
		return
	attack_move = false
	guarding = false
	set_target(t)
	forced_target = true
	_set_path(t.position)


func command_attack_move(goal: Vector2) -> void:
	set_target(null)
	forced_target = false
	guarding = false
	attack_move = not weapon.is_empty()
	attack_goal = goal
	_set_path(goal)


func _set_path(goal: Vector2) -> void:
	if flying:
		var lim := Vector2(Map.W, Map.H) * Game.TILE
		path = PackedVector2Array([goal.clamp(Vector2.ONE * 8.0, lim - Vector2.ONE * 8.0)])
		path_index = 0
		return
	path = Game.map.find_path(position, goal)
	path_index = 1 if path.size() > 1 else path.size()


func stop() -> void:
	path = PackedVector2Array()
	path_index = 0


## Recalcula o caminho até o mesmo destino (ex.: um prédio novo bloqueou a rota).
func repath() -> void:
	if not is_idle() and not flying:
		_set_path(path[path.size() - 1])


func _return_to_guard() -> void:
	if guarding:
		guarding = false
		_set_path(guard_pos)
	else:
		stop()


func is_idle() -> bool:
	return path_index >= path.size()


# ---------------------------------------------------------------- lógica

func _process(delta: float) -> void:
	if Game.game_over:
		return
	cooldown -= delta
	shot_timer -= delta
	if Net.is_client():
		_follow_net(delta)   # convidado: só segue a posição que vem do anfitrião
	else:
		if not weapon.is_empty():
			_update_combat(delta)
		_follow_path(delta)
		_separate(delta)
		if not flying:
			_check_stuck(delta)
	_update_visuals(delta)


## Multiplayer (convidado): desliza até a última posição recebida, sem trancos.
func _follow_net(delta: float) -> void:
	if position.distance_to(net_pos) > Game.TILE * 3.0:
		position = net_pos
	else:
		position = position.lerp(net_pos, 1.0 - exp(-12.0 * delta))


## Se a unidade quer andar mas quase não sai do lugar (ex.: dois veículos de frente num
## corredor), dá um passo para o lado e recalcula a rota até o mesmo destino.
func _check_stuck(delta: float) -> void:
	if is_idle():
		stuck_t = 0.0
		_stuck_ref = position
		return
	stuck_t += delta
	if stuck_t < 1.2:
		return
	var goal: Vector2 = path[path.size() - 1]
	if position.distance_to(goal) < Game.TILE * 1.5:
		stop() # o destino está ocupado por outras unidades: chegou perto o bastante
	elif position.distance_to(_stuck_ref) < 4.0:
		var here := Game.map.world_to_cell(position)
		var options: Array = []
		for y in range(-2, 3):
			for x in range(-2, 3):
				var c := here + Vector2i(x, y)
				if c != here and Game.map.is_walkable(c):
					options.append(c)
		if not options.is_empty():
			var side: Vector2 = Game.map.cell_center(options.pick_random())
			var rest := Game.map.find_path(side, goal)
			path = PackedVector2Array([side]) + rest
			path_index = 0
	stuck_t = 0.0
	_stuck_ref = position


func _update_combat(delta: float) -> void:
	if has_target and not valid_target(target):
		set_target(null)
		forced_target = false
		if attack_move:
			_set_path(attack_goal)
		else:
			_return_to_guard()

	if not has_target:
		scan_timer -= delta
		if scan_timer <= 0.0 and (attack_move or is_idle()):
			scan_timer = 0.4
			var e := Game.nearest_enemy(position, team, sight * Game.TILE, self)
			if e != null:
				set_target(e)
				if not attack_move and not guarding:
					guarding = true
					guard_pos = position

	if not has_target:
		return
	if in_range(target):
		stop()
		aim_angle = (target.position - position).angle()
		if turret == null:
			facing = aim_angle
			if absf(angle_difference(body_angle, aim_angle)) < (0.5 if flying else 0.6):
				fire()
		elif absf(angle_difference(turret_angle, aim_angle)) < 0.3:
			fire()   # tanques giram a torre antes de atirar
	elif forced_target or attack_move or (guarding and guard_pos.distance_to(target.position) < sight * Game.TILE * 1.5):
		repath_timer -= delta
		if repath_timer <= 0.0:
			repath_timer = 0.7
			_set_path(target.position)
	else:
		set_target(null)
		_return_to_guard()


func _follow_path(delta: float) -> void:
	if path_index >= path.size():
		return
	var next: Vector2 = path[path_index]
	var to := next - position
	var step := speed * delta
	if flying:
		# Naves fazem curvas: avançam na direção do nariz enquanto viram
		facing = to.angle()
		var turn := absf(angle_difference(body_angle, facing))
		step *= clampf(1.2 - turn / PI, 0.35, 1.0)
	if to.length() <= step:
		position = next
		path_index += 1
	else:
		facing = to.angle()
		position += to.normalized() * step


## Empurra unidades sobrepostas (da mesma camada: solo ou ar) para não ficarem empilhadas.
func _separate(delta: float) -> void:
	var old := position
	for e in Game.entities:
		if e == self or not (e is Unit) or e.flying != flying:
			continue
		var d: Vector2 = position - e.position
		var min_d: float = radius + e.radius
		if flying:
			min_d *= 0.8
		var l := d.length()
		if l < min_d:
			if l < 0.01:
				d = Vector2.RIGHT.rotated(randf() * TAU)
				l = 1.0
			position += d / l * (min_d - l) * minf(1.0, delta * (3.0 if flying else 8.0))
	if not flying and not Game.map.is_walkable_world(position):
		position = old


# ---------------------------------------------------------------- visual 3D

func _make_parts() -> void:
	model_scale = 1.0
	turret = model.find_child("turret", true, false)
	torso = model.find_child("torso", true, false)
	# Pernas de bípede: [quadril, joelho, fase]; patas: [nó, lado (+1 esq / -1 dir), fase]
	for n in model.find_children("leg_*", "Node3D", true, false):
		var left := String(n.name).ends_with("l")
		legs.append([n, n.find_child("knee_*", true, false), 0.0 if left else PI])
	for n in model.find_children("limb_*", "Node3D", true, false):
		var nm := String(n.name)
		var left := nm.substr(5, 1) == "l"
		var i := int(nm.substr(6))
		# tripé alternado: pata i de um lado anda junto com a pata i+1 do outro
		var group := i % 2 if left else (i + 1) % 2
		limbs.append([n, 1.0 if left else -1.0, group * PI])
	stride = maxf(0.26, radius * Game.UNIT * (1.6 if limbs.is_empty() else 1.3))
	# Rodas: [nó, raio, esterça?]; esteiras: [nó, x de repouso, +1 frente / -1 trás];
	# segmentos da larva: [nó, posição de repouso, índice]
	var tracked := not model.find_children("tread*", "Node3D", true, false).is_empty()
	for n in model.find_children("wheel_*", "Node3D", true, false):
		var r := 0.1
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			r = maxf(mi.mesh.get_aabb().size.y * 0.5, 0.02)
			break
		wheels.append([n, r, not tracked and String(n.name).ends_with("0")])
	for n in model.find_children("tread*", "Node3D", true, false):
		treads.append([n, n.position.x, 1.0 if String(n.name).begins_with("treadf") else -1.0])
	for n in model.find_children("seg_*", "Node3D", true, false):
		segs.append([n, n.position, int(String(n.name).substr(4))])
	for n in model.find_children("wing_*", "Node3D", true, false):
		wings.append(n)
	for n in model.find_children("spin", "Node3D", true, false):
		spins.append(n)
	if torso != null:
		_torso_y = torso.position.y
	if turret != null:
		_turret_y = turret.position.y
	var r := (radius + (2.0 if is_infantry else 3.0)) * Game.UNIT
	var half := Vector2.ONE * r
	sel_ring = Fx3D.ring(half + Vector2.ONE * 0.06, 0.05, Color(0.75, 0.95, 1.0, 0.95))
	sel_ring.visible = selected
	if flying:
		# Naves: o anel de seleção fica projetado no chão, sob a nave
		var ground := Node3D.new()
		ground.name = "ground"
		add_child(ground)
		ground.add_child(sel_ring)
		for loc in Models.locators_named(model, "engine"):
			var tr := Fx3D.engine_trail(Game.faction(team)["shot"])
			loc.add_child(tr)
			_trails.append(tr)
	else:
		root.add_child(sel_ring)
	body_angle = facing
	turret_angle = facing
	model.rotation.y = -body_angle


func pick_box() -> AABB:
	var r := (radius + (3.0 if is_infantry else 2.0)) * Game.UNIT
	return AABB(Game.to3d(position, altitude) - Vector3(r, 0, r), Vector3(r * 2.0, maxf(height(), 0.3), r * 2.0))


func _update_visuals(delta: float) -> void:
	_moved = position.distance_to(_last_pos) * Game.UNIT
	moving = _moved > 0.0005
	_last_pos = position
	anim_t += delta
	var turn := 14.0 if is_infantry else (2.6 if flying else 4.5)
	var prev := body_angle
	body_angle = lerp_angle(body_angle, facing, minf(1.0, delta * turn))
	model.rotation.y = -body_angle
	if flying:
		# Decola do hangar, flutua de leve e inclina nas curvas
		_lift = minf(1.0, _lift + delta * 0.6)
		var yaw_rate := angle_difference(prev, body_angle) / maxf(delta, 0.001)
		_bank = lerpf(_bank, clampf(yaw_rate * 0.25, -0.6, 0.6), minf(1.0, delta * 4.0))
		model.rotation.x = _bank
		altitude = Game.AIR_HEIGHT * smoothstep(0.0, 1.0, _lift) + sin(anim_t * 1.7) * 0.06
		root.position = Game.to3d(position, altitude)
		var g: Node3D = get_node("ground")
		g.position = Game.to3d(position, 0.0)
		g.visible = visible
	elif hover:
		model.position.y = 0.04 + sin(anim_t * 2.3) * 0.025
	if turret != null:
		var want := aim_angle if has_target and valid_target(target) else body_angle
		turret_angle = lerp_angle(turret_angle, want, minf(1.0, delta * 6.0))
		turret.rotation.y = -(turret_angle - body_angle)
	_animate_gait(delta, absf(angle_difference(prev, body_angle)))
	if not flying and not is_infantry and legs.is_empty() and limbs.is_empty():
		_animate_vehicle(delta, angle_difference(prev, body_angle) / maxf(delta, 0.001))
	for i in wings.size():
		var flap := sin(anim_t * (38.0 if radius < 14.0 else 4.0)) * (0.5 if radius < 14.0 else 0.22)
		wings[i].rotation.x = flap if i % 2 == 0 else -flap
	for s in spins:
		s.rotation.y += delta * 1.4
	update_flash(delta)


## Marcha procedural. A fase avança com a distância percorrida (um ciclo = dois passos),
## então o ritmo acompanha a velocidade; girar parado também dá passinhos.
## Bípedes: quadril balança, joelho dobra na fase de balanço, tronco sobe e desce,
## torce e balança de lado. Patas: varrem para frente levantadas e voltam apoiadas.
func _animate_gait(delta: float, turned: float) -> void:
	var stepping := moving or turned > 0.004
	walk_w = move_toward(walk_w, 1.0 if stepping else 0.0, delta * (5.0 if stepping else 3.0))
	gait += _moved / (stride * 2.0) * TAU + turned * 1.6
	var w := smoothstep(0.0, 1.0, walk_w)
	_recoil = move_toward(_recoil, 0.0, delta * 1.2)
	if shot_timer > 0.0:
		_recoil = 0.14
	var bob := 0.0
	for l in legs:
		var p: float = gait + l[2]
		var swing := cos(p)                     # > 0: perna indo para frente (no ar)
		l[0].rotation.z = sin(p) * 0.5 * w
		if l[1] != null:
			var lift := pow(maxf(0.0, swing), 1.4) * 1.0
			var load := pow(maxf(0.0, -swing), 2.0) * 0.12   # amortece ao receber o peso
			l[1].rotation.z = -(lift + load) * w
	if not legs.is_empty():
		bob = (cos(gait * 2.0) * 0.5 + 0.5) * stride * 0.07 * w
	# patas longas (veículos) varrem e levantam menos que as dos soldados
	var sweep := 0.38 if is_infantry else 0.27
	var raise := 0.42 if is_infantry else 0.22
	for l in limbs:
		var p: float = gait + l[2]
		var side: float = l[1]
		l[0].rotation.y = -side * sin(p) * sweep * w
		l[0].rotation.x = side * pow(maxf(0.0, cos(p)), 1.3) * raise * w
	if not limbs.is_empty() and not hover:
		# corpo sobe a cada apoio do tripé (2x por ciclo) e balança um pouco
		model.position.y = (cos(gait * 2.0) * 0.5 + 0.5) * stride * 0.06 * w
		model.rotation.x = sin(gait) * 0.025 * w
	var breathe := sin(anim_t * 2.1) * 0.004 * (1.0 - w)
	if torso != null:
		torso.position.y = _torso_y + bob + breathe
		torso.rotation.y = -sin(gait) * 0.14 * w                  # ombros contra os quadris
		torso.rotation.x = cos(gait) * 0.05 * w                   # peso de um lado ao outro
		torso.rotation.z = -0.07 * w + _recoil                    # inclina para frente; coice
	elif not legs.is_empty() and turret != null:
		# Colosso: a cabine acompanha o passo pesado
		turret.position.y = _turret_y + bob - absf(sin(gait)) * stride * 0.03 * w
		turret.rotation.x = cos(gait) * 0.04 * w


## Veículos sem pernas: rodas giram pela distância, as da frente esterçam, as sapatas das
## esteiras correm, a larva ondula e a carroceria reage (empina ao acelerar, mergulha ao
## frear, inclina para fora nas curvas). Hover inclina mais; esteira vibra.
const TREAD := 0.07   # espaçamento das sapatas (igual ao do gerador do Blender)

func _animate_vehicle(delta: float, yaw_rate: float) -> void:
	_roll += _moved
	var spd := _moved / maxf(delta, 0.001)
	var prev_speed := _speed
	_speed = lerpf(_speed, spd, minf(1.0, delta * 8.0))
	_accel = lerpf(_accel, (_speed - prev_speed) / maxf(delta, 0.001), minf(1.0, delta * 6.0))
	var soft := 1.6 if hover else 1.0
	var want_pitch := clampf(_accel * 0.035 * soft, -0.09, 0.09)
	var want_lean := clampf(-yaw_rate * _speed * 0.05 * soft, -0.12, 0.12)
	_pitch = lerpf(_pitch, want_pitch, minf(1.0, delta * 5.0))
	_lean = lerpf(_lean, want_lean, minf(1.0, delta * 5.0))
	model.rotation.z = _pitch
	model.rotation.x = _lean
	if not hover and not treads.is_empty():
		model.position.y = sin(anim_t * 47.0) * 0.004 * clampf(_speed, 0.0, 1.0)
	_steer = lerpf(_steer, clampf(yaw_rate * 0.35, -0.5, 0.5), minf(1.0, delta * 8.0))
	for wh in wheels:
		wh[0].rotation.z = -_roll / float(wh[1])
		if wh[2]:
			wh[0].rotation.y = -_steer
	var off := fposmod(_roll, TREAD)
	for t in treads:
		t[0].position.x = float(t[1]) + off * float(t[2])
	# Larva: onda de contração que corre da cabeça para a cauda
	var w := smoothstep(0.0, 1.0, walk_w)
	for s in segs:
		var ph: float = gait * 1.5 - float(s[2]) * 0.9
		var rest: Vector3 = s[1]
		s[0].position = rest + Vector3(0.0, sin(ph) * 0.03 * w, sin(ph * 0.5) * 0.04 * w)
		s[0].scale = Vector3(1.0 + sin(ph) * 0.08 * w, 1.0 - sin(ph) * 0.04 * w, 1.0 - sin(ph) * 0.04 * w)
	if not segs.is_empty():
		model.position.y = 0.0


func die() -> void:
	if dead:
		return
	if not is_infantry and Game.world != null:
		var w := Wreck.new()
		w.setup(model_name, body_angle, turret_angle - body_angle, position, altitude, team)
		w.visible = visible
		Game.world.add_child(w)
	super.die()
