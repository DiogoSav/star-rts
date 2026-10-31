class_name Projectile
extends Node3D
## Projétil visível (míssil, plasma, orbe): voa da boca da arma até o alvo, perseguindo-o,
## e só então aplica o dano e explode.

const SPEEDS := {"at": 9.0, "cannon": 14.0, "missile": 11.0}

var target: Entity = null
var team := 0
var damage := 0.0
var wtype := ""
var color := Color.WHITE
var speed := 12.0
var goal := Vector3.ZERO
var _t := 0.0
var _arc := 0.0
var _start := Vector3.ZERO
var _trail: CPUParticles3D


func setup(shooter: Entity, t: Entity, dmg: float, weapon_type: String) -> void:
	target = t
	team = shooter.team
	damage = dmg
	wtype = weapon_type
	color = shooter.shot_color()
	speed = SPEEDS.get(weapon_type, 12.0)
	position = shooter.muzzle_point()
	_start = position
	goal = t.center3d()
	# mísseis e orbes sobem um pouco antes de cair no alvo
	_arc = 0.0 if weapon_type == "cannon" else randf_range(0.3, 0.7)
	visible = shooter.visible or t.visible


func _ready() -> void:
	var core := MeshInstance3D.new()
	var s := SphereMesh.new()
	var big := wtype == "cannon"
	s.radius = 0.07 if big else 0.045
	s.height = s.radius * (5.0 if wtype == "missile" else 3.0)
	core.mesh = s
	core.rotation.x = PI / 2.0
	core.material_override = Fx3D.glow_material(color, 2.5)
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(core)
	_trail = Fx3D.trail(color, big)
	add_child(_trail)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 0.7
	light.omni_range = 1.4
	add_child(light)


func _process(delta: float) -> void:
	if Game.game_over:
		queue_free()
		return
	if is_instance_valid(target) and not target.dead:
		goal = target.center3d()
	var dist := _start.distance_to(goal)
	_t += delta * speed / maxf(dist, 0.5)
	var k := minf(_t, 1.0)
	var p := _start.lerp(goal, k)
	p.y += sin(k * PI) * _arc * dist * 0.25
	if p.distance_squared_to(position) > 0.000001:
		look_at(p, Vector3.UP)
	position = p
	if _t >= 1.0:
		_impact()


func _impact() -> void:
	var g := Game.to_ground(goal)
	Game.spawn_explosion(g, 9.0 if wtype == "cannon" else 6.0, goal.y, color)
	if is_instance_valid(target) and not target.dead:
		target.take_damage(damage, wtype)
	# o rastro continua um pouco depois do impacto
	_trail.emitting = false
	remove_child(_trail)
	get_parent().add_child(_trail)
	_trail.global_position = position
	get_tree().create_timer(_trail.lifetime + 0.1).timeout.connect(_trail.queue_free)
	queue_free()
