class_name Entity
extends Node
## Base comum de unidades e prédios: vida, time, arma e o modelo 3D (do Blender).
##
## A lógica continua no plano do chão: `position` é um Vector2 em pixels de chão (TILE = 32).
## O nó `root` fica no ponto correspondente do mundo 3D (na altitude, para naves) e
## carrega o modelo e os anéis.

var type := ""
var team := 0
var data: Dictionary = {}
var hp := 1.0
var max_hp := 1.0
var radius := 8.0
var sight := 5
var armor := "light"
var dead := false
var flying := false
var altitude := 0.0

var weapon: Dictionary = {}
var cooldown := 0.0
var target: Entity = null
var has_target := false
var shot_timer := 0.0
var shot_to := Vector3.ZERO   # ponto 3D atingido pelo último tiro
var _barrel := 0              # alterna entre bocas de arma (naves com dois canhões)
var _hit_t := 0.0

var root: Node3D              # no chão (ou na altitude de voo), sem escala
var model: Node3D             # modelo do Blender
var model_name := ""
var box := AABB()             # AABB do modelo, em unidades do mundo
var model_scale := 1.0
var muzzles: Array = []
var muzzle: Node3D
var flash: MeshInstance3D
var sel_ring: MeshInstance3D

var position := Vector2.ZERO:
	set(v):
		position = v
		if root != null:
			root.position = Game.to3d(v, altitude)

var visible := true:
	set(v):
		visible = v
		if root != null:
			root.visible = v

var selected := false:
	set(v):
		selected = v
		if sel_ring != null:
			sel_ring.visible = v


func make_visuals(name_3d: String) -> void:
	model_name = name_3d
	root = Node3D.new()
	root.position = Game.to3d(position, altitude)
	root.visible = visible
	add_child(root)
	model = Models.instantiate(name_3d)
	box = Models.aabb(name_3d)
	root.add_child(model)
	Models.set_team(model, Game.team_color(team))
	muzzles = Models.locators_named(model, "muzzle")
	muzzle = muzzles[0] if not muzzles.is_empty() else null
	if muzzle != null:
		flash = Fx3D.muzzle_flash(_heavy_weapon(), shot_color())
		muzzle.add_child(flash)


func _heavy_weapon() -> bool:
	return String(weapon.get("type", "")) in Game.PROJECTILE_WEAPONS


## Altura do modelo, em unidades do mundo.
func height() -> float:
	return maxf(box.end.y, 0.12) * model_scale


## Altura do centro do corpo (para mirar os tiros).
func body_height() -> float:
	return height() * 0.55


func center3d() -> Vector3:
	return Game.to3d(position, altitude + body_height())


## Ponto logo acima do modelo (barra de vida).
func top3d() -> Vector3:
	return Game.to3d(position, altitude + height() + 0.12)


## Caixa clicável no mundo 3D.
func pick_box() -> AABB:
	var r := maxf(radius, 8.0) * Game.UNIT
	return AABB(Game.to3d(position, altitude) - Vector3(r, 0, r), Vector3(r * 2.0, height(), r * 2.0))


func muzzle_point() -> Vector3:
	if muzzle != null and muzzle.is_inside_tree():
		return muzzle.global_position
	return Game.to3d(position, altitude + height())


func set_target(e: Entity) -> void:
	target = e
	has_target = e != null


func valid_target(t) -> bool:
	return is_instance_valid(t) and not t.dead


## A arma consegue atingir `e`? (naves só com armas antiaéreas; algumas naves não atiram no solo)
func can_hit(e) -> bool:
	if weapon.is_empty():
		return false
	if e.flying:
		return weapon.get("air", false)
	return weapon.get("ground", true)


func in_range(t) -> bool:
	return position.distance_to(t.position) - t.radius <= float(weapon["range"])


func fire() -> void:
	if cooldown > 0.0:
		return
	cooldown = float(weapon["cooldown"])
	if muzzles.size() > 1:
		_barrel = (_barrel + 1) % muzzles.size()
		muzzle.remove_child(flash)
		muzzle = muzzles[_barrel]
		muzzle.add_child(flash)
	shot_to = target.center3d()
	shot_timer = 0.09
	var wtype := String(weapon["type"])
	if wtype in Game.PROJECTILE_WEAPONS:
		var p := Projectile.new()
		p.setup(self, target, float(weapon["damage"]), wtype)
		Game.world.add_child(p)
	else:
		target.take_damage(float(weapon["damage"]), wtype)


func take_damage(amount: float, weapon_type: String) -> void:
	if dead:
		return
	var mult: float = Game.ARMOR_MULT.get(weapon_type, {}).get(armor, 1.0)
	hp -= amount * mult
	_hit_t = 0.12
	if hp <= 0.0:
		die()


func die() -> void:
	if dead:
		return
	dead = true
	Game.spawn_explosion(position, radius * 1.6 + 6.0, altitude + body_height() * 0.5)
	Game.remove_entity(self)
	queue_free()


func shot_color() -> Color:
	return Game.faction(team)["shot"]


func update_flash(delta: float) -> void:
	if flash != null:
		flash.visible = shot_timer > 0.0
	if _hit_t > 0.0:
		_hit_t -= delta
		Models.set_hit(model, maxf(_hit_t, 0.0) * 3.0)
