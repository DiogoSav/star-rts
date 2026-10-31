class_name Explosion
extends Node3D
## Explosão: bola de fogo, faíscas, fumaça, onda de choque no chão e um clarão de luz.
## `size` é o raio aproximado no chão (pixels de chão); `color` tinge o núcleo.

const DURATION := 1.6

var size := 16.0
var color := Color(1.0, 0.55, 0.2)
var t := 0.0
var light: OmniLight3D
var shock: MeshInstance3D
var _parts: Array = []


func _ready() -> void:
	var k := clampf(size / 16.0, 0.3, 2.6)
	var core := CPUParticles3D.new()
	core.one_shot = true
	core.explosiveness = 0.95
	core.amount = int(10 + 14 * k)
	core.lifetime = 0.55
	core.mesh = Fx3D._particle_quad(0.35 * k, true)
	core.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	core.emission_sphere_radius = 0.08 * k
	core.spread = 180.0
	core.gravity = Vector3(0, 0.5, 0)
	core.initial_velocity_min = 0.3 * k
	core.initial_velocity_max = 1.2 * k
	core.scale_amount_curve = Fx3D._grow(0.6, 1.6)
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.95, 0.8, 1.0))
	g.add_point(0.25, Color(color.lightened(0.2), 0.9))
	g.set_color(g.get_point_count() - 1, Color(color.darkened(0.6), 0.0))
	core.color_ramp = g
	_add(core)

	var sparks := CPUParticles3D.new()
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.amount = int(8 + 12 * k)
	sparks.lifetime = 0.8
	sparks.mesh = Fx3D._particle_quad(0.06, true)
	sparks.direction = Vector3.UP
	sparks.spread = 80.0
	sparks.gravity = Vector3(0, -6.0, 0)
	sparks.initial_velocity_min = 1.5 * k
	sparks.initial_velocity_max = 4.0 * k
	sparks.color_ramp = Fx3D._ramp(Color(1.0, 0.85, 0.5, 1.0), Color(color, 0.0))
	_add(sparks)

	if size >= 8.0:
		var smoke := CPUParticles3D.new()
		smoke.one_shot = true
		smoke.explosiveness = 0.8
		smoke.amount = int(6 + 6 * k)
		smoke.lifetime = 1.5
		smoke.mesh = Fx3D._particle_quad(0.45 * k)
		smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		smoke.emission_sphere_radius = 0.15 * k
		smoke.direction = Vector3.UP
		smoke.spread = 60.0
		smoke.gravity = Vector3(0.1, 0.4, 0)
		smoke.initial_velocity_min = 0.2
		smoke.initial_velocity_max = 0.6 * k
		smoke.scale_amount_curve = Fx3D._grow(0.5, 2.0)
		smoke.color_ramp = Fx3D._ramp(Color(0.12, 0.1, 0.1, 0.65), Color(0.2, 0.2, 0.22, 0.0))
		_add(smoke)

	if size >= 10.0 and position.y < 0.4:
		shock = Fx3D.ring(Vector2.ONE * 0.5, 0.12, Color(color.lightened(0.4), 0.8))
		shock.material_override = Fx3D.glow_material(Color(color.lightened(0.3), 0.7), 2.0)
		shock.position.y = 0.03 - position.y
		add_child(shock)

	if visible:
		light = OmniLight3D.new()
		light.light_color = color.lightened(0.2)
		light.omni_range = clampf(size / 6.0, 1.5, 6.0)
		light.light_energy = 2.2
		light.position.y = 0.3
		add_child(light)


func _add(p: CPUParticles3D) -> void:
	p.emitting = true
	add_child(p)
	_parts.append(p)


func _process(delta: float) -> void:
	t += delta
	if t >= DURATION:
		queue_free()
		return
	if light != null:
		light.light_energy = 2.2 * maxf(0.0, 1.0 - t / 0.35)
	if shock != null:
		var s := 0.3 + t * size / 7.0
		shock.scale = Vector3(s, 1, s)
		shock.visible = t < 0.45
