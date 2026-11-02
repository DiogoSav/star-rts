class_name Building
extends Entity
## Prédio: ocupa células da grade, gera ou consome energia, pode produzir ou atirar (torre).

var cell := Vector2i.ZERO
var size := Vector2i.ONE
var aim := Vector2(0, 1)   # direção do canhão da torre (no chão)
var _t := 0.0
var gun: Node3D
var _gun_angle := PI / 2.0
var _burning := false
var built := true
var build_t := 1.0           # progresso da construção (0..1)
var _build_time := 2.5
var _smokes: Array = []
var _spins: Array = []
var _dust: CPUParticles3D
var _frame: MeshInstance3D
var _scan: MeshInstance3D
var _fire_fx: Array = []
var _hum: AudioStreamPlayer3D
var _fire_snd: AudioStreamPlayer3D
## Conserto: recupera REPAIR_RATE da vida por segundo, cobrando repair_cost_per_hp() por ponto
const REPAIR_RATE := 0.05
var repairing := false
var _repair_fx: CPUParticles3D
## Cura em área (prédios com "heal"): a cada HEAL_TICK as unidades do time em volta recuperam vida
const HEAL_TICK := 1.0
const HEAL_COLOR := Color(0.35, 1.0, 0.5)
var _heal_t := 0.0
var _range_ring: MeshInstance3D
## Reciclar devolve esta fração do custo (o prédio some sem explodir)
const RECYCLE_REFUND := 0.8
var recycled := false
## Ponto de reunião (prédios que produzem unidades): as unidades novas andam até lá
var has_rally := false
var rally := Vector2.ZERO
var _rally_mark: Node3D
## Último dano recebido (ms): o minimapa pisca o prédio em vermelho
var hit_at := -100000
var _prev_hp := 0.0


func setup(t: String, tm: int, c: Vector2i) -> void:
	type = t
	team = tm
	cell = c
	data = Game.BUILDINGS[t]
	size = data["size"]
	max_hp = float(data["hp"])
	hp = max_hp
	sight = int(data["sight"])
	armor = "building"
	weapon = data.get("weapon", {})
	position = (Vector2(cell) + Vector2(size) / 2.0) * Game.TILE
	radius = maxi(size.x, size.y) * Game.TILE * 0.5
	_t = randf() * 10.0
	make_visuals(t + "_" + Game.factions[tm])
	gun = model.find_child("gun", true, false)
	if gun != null:
		gun.rotation.y = -_gun_angle
	for n in model.find_children("spin", "Node3D", true, false):
		_spins.append(n)
	# Fumaça/vapor das chaminés (localizadores "smoke" do modelo)
	for m in Models.locators_named(model, "smoke"):
		var s := Fx3D.smoke()
		s.position = Models.local_position(model, m)
		root.add_child(s)
		_smokes.append(s)
	var half := Vector2(size) * 0.5 + Vector2(0.06, 0.06)
	sel_ring = Fx3D.ring(half, 0.07, Color(0.75, 0.95, 1.0, 0.95), true)
	sel_ring.visible = selected
	root.add_child(sel_ring)
	_prev_hp = hp
	if data.has("heal"):
		_range_ring = range_ring(float(data["heal"]["range"]))
		_range_ring.visible = false
		root.add_child(_range_ring)


## Círculo no chão mostrando o alcance da cura (também usado no fantasma ao posicionar).
static func range_ring(range_px: float) -> MeshInstance3D:
	var r := range_px * Game.UNIT
	return Fx3D.ring(Vector2(r, r), 0.06, Color(HEAL_COLOR, 0.55))


## Começa a obra: o prédio é "impresso" de baixo para cima por um feixe holográfico,
## com faíscas e um contorno no terreno. Leva no máximo 3 segundos e só funciona depois.
func start_construction() -> void:
	built = false
	Sfx.build(self)
	build_t = 0.0
	_build_time = 1.5 if size == Vector2i.ONE else 2.5
	for s in _smokes:
		s.emitting = false
	_dust = Fx3D.sparks(Vector2(size), Game.team_color(team))
	root.add_child(_dust)
	var half := Vector2(size) * 0.5 + Vector2(0.1, 0.1)
	_frame = Fx3D.ring(half, 0.06, Color(Game.team_color(team), 0.85), true)
	root.add_child(_frame)
	_scan = Fx3D.scan_plane(Vector2(size), Game.team_color(team))
	root.add_child(_scan)
	_update_construction(0.0)


func finish_construction() -> void:
	var was_building := not built
	built = true
	if was_building and team == Game.local_team:
		Sfx.ui("building_ready")
	# Zumbido do gerador de energia (som de ambiente, só perto dele)
	if type == "power" and _hum == null:
		_hum = Sfx.loop3d("ambience/reactor", root, -14.0, "Ambiente", 14.0)
	build_t = 1.0
	model.position = Vector3.ZERO
	model.scale = Vector3.ONE
	for s in _smokes:
		s.emitting = true
	if _dust != null:
		_dust.emitting = false
		get_tree().create_timer(2.0).timeout.connect(_dust.queue_free)
		_dust = null
	if _frame != null:
		_frame.queue_free()
		_frame = null
	if _scan != null:
		_scan.queue_free()
		_scan = null
	if type == "refinery" and not Net.is_client():
		Game.spawn_unit(Game.faction(team)["harvester"], team, dock_position())


func _update_construction(delta: float) -> void:
	build_t = minf(1.0, build_t + delta / _build_time)
	var k := 1.0 - pow(1.0 - build_t, 2.0)   # desacelera no fim
	var h := box.end.y
	model.scale = Vector3(1.0, maxf(k, 0.02), 1.0)
	model.position = Vector3(randf_range(-0.005, 0.005), 0.0, randf_range(-0.005, 0.005))
	if _scan != null:
		_scan.position.y = h * k + 0.02
	if build_t >= 1.0:
		finish_construction()


## Ponto logo abaixo do prédio, onde unidades aparecem e coletores descarregam.
func exit_position() -> Vector2:
	var c := Vector2i(cell.x + size.x / 2, cell.y + size.y)
	return Game.map.cell_center(Game.map.nearest_walkable(c))


func dock_position() -> Vector2:
	return exit_position()


func body_height() -> float:
	return minf(height() * 0.5, 0.8)


func pick_box() -> AABB:
	var half := Vector2(size) * 0.5
	var c := Game.to3d(position)
	return AABB(c - Vector3(half.x, 0, half.y), Vector3(half.x * 2.0, height(), half.y * 2.0))


func _process(delta: float) -> void:
	_t += delta
	# Dano percebido pela queda da vida (no convidado ela vem do anfitrião)
	if hp < _prev_hp - 0.01:
		hit_at = Time.get_ticks_msec()
		if team == Game.local_team:
			Sfx.building_attacked(self)
	_prev_hp = hp
	if _rally_mark != null:
		_rally_mark.visible = selected and has_rally
	if not built:
		_update_construction(delta)
		return
	var powered := not Game.low_power(team) or int(data["power"]) > 0
	for s in _spins:
		s.rotation.y += delta * (0.8 if powered else 0.1)
	if repairing and not Net.is_client():
		_repair(delta)
	if _range_ring != null:
		_range_ring.visible = selected
		_heal_t -= delta
		if _heal_t <= 0.0:
			_heal_t = HEAL_TICK
			_heal_area()
	if not _burning and hp < max_hp * 0.5:
		_start_burning()
	elif _burning and hp > max_hp * 0.6:
		_stop_burning()
	if gun != null:
		_gun_angle = lerp_angle(_gun_angle, aim.angle(), minf(1.0, delta * 6.0))
		gun.rotation.y = -_gun_angle
	update_flash(delta)
	cooldown -= delta
	shot_timer -= delta
	if Game.game_over or weapon.is_empty() or Net.is_client():
		return # no convidado a torre só mira e mostra os tiros vindos do anfitrião
	if Game.low_power(team):
		return # torres desligam sem energia
	if not (has_target and valid_target(target) and in_range(target)):
		set_target(Game.nearest_enemy(position, team, float(weapon["range"]), self))
	if has_target and valid_target(target) and in_range(target):
		aim = (target.position - position).normalized()
		if absf(angle_difference(_gun_angle, aim.angle())) < 0.3:
			fire()


## Danificado: fogo, faíscas e fumaça preta sobre o telhado.
func _start_burning() -> void:
	_burning = true
	if _fire_snd == null:
		_fire_snd = Sfx.loop3d("ambience/fire", root, -8.0, "Ambiente", 16.0)
	var top := box.end.y
	for i in 2:
		var p := Vector3((i * 2 - 1) * size.x * 0.22, top * (0.85 - i * 0.15), -size.y * 0.1)
		var f := Fx3D.fire()
		f.position = p
		root.add_child(f)
		var s := Fx3D.smoke(true)
		s.position = p + Vector3(0, 0.1, 0)
		root.add_child(s)
		_fire_fx.append_array([f, s])


## Consertado acima de 60%: o fogo apaga (a fumaça termina de subir e some).
func _stop_burning() -> void:
	_burning = false
	for p in _fire_fx:
		p.emitting = false
		get_tree().create_timer(p.lifetime + 0.2).timeout.connect(p.queue_free)
	_fire_fx.clear()
	if _fire_snd != null:
		_fire_snd.queue_free()
		_fire_snd = null


## Cura as unidades do time dentro do alcance. Várias estações não se somam: cada unidade
## é curada no máximo uma vez por HEAL_TICK. No convidado só mostra o brilho (a vida vem
## nos snapshots do anfitrião).
func _heal_area() -> void:
	if Game.game_over or Game.low_power(team):
		return
	var heal: Dictionary = data["heal"]
	var r2: float = float(heal["range"]) ** 2
	var now := Time.get_ticks_msec()
	for e in Game.entities:
		if not (e is Unit) or e.team != team or e.dead or e.hp >= e.max_hp:
			continue
		if e.position.distance_squared_to(position) > r2 or now - e.healed_at < HEAL_TICK * 900.0:
			continue
		e.healed_at = now
		if not Net.is_client():
			e.hp = minf(e.max_hp, e.hp + e.max_hp * float(heal["rate"]) * HEAL_TICK)
		if e.visible:
			var fx := Fx3D.heal_burst(maxf(e.box.size.x, e.box.size.z) * 0.35)
			Game.world.add_child(fx)
			fx.global_position = e.center3d()
			fx.emitting = true
			fx.finished.connect(fx.queue_free)


## Valor devolvido ao reciclar.
func recycle_value() -> int:
	return int(float(data["cost"]) * RECYCLE_REFUND)


func can_recycle() -> bool:
	return type != "cy" and not dead


## Desmonta o prédio e devolve RECYCLE_REFUND do custo (só no anfitrião; o convidado só
## vê o efeito).
func recycle() -> void:
	if not can_recycle():
		return
	recycled = true
	if not Net.is_client():
		Game.credits[team] += recycle_value()
		Game.notify(team, "%s reciclado: +%d créditos" % [Game.item_name(type, team), recycle_value()])
		Net.send_recycled(net_id)
	die()


func produces_units() -> bool:
	return data["produces"] in ["infantry", "vehicle", "air"]


func set_rally(p: Vector2) -> void:
	has_rally = true
	rally = p
	if _rally_mark == null:
		_rally_mark = Node3D.new()
		var pole := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.025
		cyl.bottom_radius = 0.025
		cyl.height = 0.9
		pole.mesh = cyl
		pole.position.y = 0.45
		pole.material_override = Fx3D.flat_material(Color(0.85, 0.9, 1.0))
		_rally_mark.add_child(pole)
		var flag := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.4, 0.25)
		flag.mesh = q
		flag.position = Vector3(0.2, 0.75, 0)
		flag.material_override = Fx3D.flat_material(Game.team_color(team))
		flag.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED
		_rally_mark.add_child(flag)
		_rally_mark.add_child(Fx3D.ring(Vector2(0.35, 0.35), 0.05, Color(Game.team_color(team), 0.8)))
		Game.world.add_child(_rally_mark)
	_rally_mark.position = Game.to3d(rally)


func _exit_tree() -> void:
	if _rally_mark != null:
		_rally_mark.queue_free()


## Custo por ponto de vida: metade do custo do prédio dividida pela vida máxima.
func repair_cost_per_hp() -> float:
	return float(data["cost"]) * 0.5 / max_hp


## Custo para consertar tudo o que falta agora.
func repair_cost_total() -> int:
	return ceili((max_hp - hp) * repair_cost_per_hp())


func can_repair() -> bool:
	return built and not dead and hp < max_hp


func set_repairing(on: bool) -> void:
	repairing = on and can_repair()
	if repairing and _repair_fx == null:
		_repair_fx = Fx3D.sparks(Vector2(size) * 0.6, Color(0.4, 1.0, 0.55))
		_repair_fx.amount = 24
		_repair_fx.position.y = box.end.y * 0.6
		root.add_child(_repair_fx)
	if _repair_fx != null:
		_repair_fx.emitting = repairing


func _repair(delta: float) -> void:
	var amount := minf(max_hp * REPAIR_RATE * delta, max_hp - hp)
	var cost := amount * repair_cost_per_hp()
	if Game.credits[team] < cost:
		# Sem créditos o conserto para; o jogador precisa pedir de novo
		set_repairing(false)
		Game.notify(team, "Créditos insuficientes: conserto interrompido")
		return
	Game.credits[team] -= cost
	hp += amount
	if hp >= max_hp:
		hp = max_hp
		set_repairing(false)


func die() -> void:
	if dead:
		return
	Game.map.set_cells_blocked(cell, size, false)
	if recycled:
		# Reciclado: some com faíscas e o som de obra, sem explosão
		var fx := Fx3D.sparks(Vector2(size), Game.team_color(team))
		fx.one_shot = true
		Game.world.add_child(fx)
		fx.global_position = Game.to3d(position)
		fx.emitting = true
		fx.finished.connect(fx.queue_free)
		Sfx.build(self)
		dead = true
		Game.remove_entity(self)
		queue_free()
		return
	for i in 3:
		var off := Vector2(randf_range(-1, 1) * size.x, randf_range(-1, 1) * size.y) * 10.0
		Game.spawn_explosion(position + off, radius * 0.8, 0.2)
	super.die()
