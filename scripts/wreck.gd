class_name Wreck
extends Node3D
## Carcaça queimada de um veículo, nave ou criatura destruída. Naves caem girando antes
## de bater no chão. Solta fumaça e afunda no chão depois de um tempo.

const LIFETIME := 40.0

var t := 0.0
var fire: CPUParticles3D
var _model: Node3D
var _fall := 0.0
var _spin := 0.0
var _ground := Vector2.ZERO
var _top := 0.3


func setup(model_name: String, body_angle: float, turret_rel: float, pos: Vector2, height := 0.0, team := 0) -> void:
	_ground = pos
	position = Game.to3d(pos, height)
	_fall = height
	_spin = randf_range(-3.0, 3.0)
	_model = Models.instantiate(model_name)
	_model.rotation.y = -body_angle
	var turret: Node3D = _model.find_child("turret", true, false)
	if turret != null:
		turret.rotation.y = -turret_rel + randf_range(-0.4, 0.4)
	add_child(_model)
	Models.set_team(_model, Game.team_color(team))
	Models.set_tint(_model, Color(0.22, 0.2, 0.2, 0.0))
	_top = Models.aabb(model_name).end.y
	var smoke := Fx3D.smoke(true)
	smoke.position.y = _top
	add_child(smoke)
	fire = Fx3D.fire()
	fire.position.y = _top * 0.8
	add_child(fire)


func _process(delta: float) -> void:
	t += delta
	if t > LIFETIME:
		queue_free()
		return
	if _fall > 0.0:
		# Nave abatida: cai acelerando, girando e inclinada
		_fall = maxf(0.0, _fall - delta * (1.0 + t * 5.0))
		position.y = _fall
		_model.rotation.y += _spin * delta
		_model.rotation.x = minf(0.6, _model.rotation.x + delta)
		if _fall <= 0.0:
			Game.spawn_explosion(_ground, 18.0, 0.1)
		return
	if t > 12.0 and fire.emitting:
		fire.emitting = false
	if t > LIFETIME - 5.0:
		position.y = -(t - (LIFETIME - 5.0)) / 5.0 * maxf(_top, 0.3)
