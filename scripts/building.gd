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


## Começa a obra: o prédio é "impresso" de baixo para cima por um feixe holográfico,
## com faíscas e um contorno no terreno. Leva no máximo 3 segundos e só funciona depois.
func start_construction() -> void:
	built = false
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
	built = true
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
	if type == "refinery":
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
	if not built:
		_update_construction(delta)
		return
	var powered := not Game.low_power(team) or int(data["power"]) > 0
	for s in _spins:
		s.rotation.y += delta * (0.8 if powered else 0.1)
	if not _burning and hp < max_hp * 0.5:
		_start_burning()
	if gun != null:
		_gun_angle = lerp_angle(_gun_angle, aim.angle(), minf(1.0, delta * 6.0))
		gun.rotation.y = -_gun_angle
	update_flash(delta)
	if Game.game_over or weapon.is_empty():
		return
	cooldown -= delta
	shot_timer -= delta
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
	var top := box.end.y
	for i in 2:
		var p := Vector3((i * 2 - 1) * size.x * 0.22, top * (0.85 - i * 0.15), -size.y * 0.1)
		var f := Fx3D.fire()
		f.position = p
		root.add_child(f)
		var s := Fx3D.smoke(true)
		s.position = p + Vector3(0, 0.1, 0)
		root.add_child(s)


func die() -> void:
	if dead:
		return
	Game.map.set_cells_blocked(cell, size, false)
	for i in 3:
		var off := Vector2(randf_range(-1, 1) * size.x, randf_range(-1, 1) * size.y) * 10.0
		Game.spawn_explosion(position + off, radius * 0.8, 0.2)
	super.die()
