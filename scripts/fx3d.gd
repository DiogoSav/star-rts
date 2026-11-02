class_name Fx3D
extends RefCounted
## Peças visuais 3D reaproveitadas: anéis de seleção, fumaça, fogo, faíscas, rastros e clarões.

static var _quad_cache := {}
static var _glow_cache := {}


## Material sem iluminação (anéis, marcadores). `alpha` < 1 liga a transparência.
static func flat_material(color: Color, depth_test := true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = not depth_test
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## Material que brilha (passa do limiar do bloom).
static func glow_material(color: Color, energy := 4.0) -> StandardMaterial3D:
	var key := "%s|%s" % [color, energy]
	if _glow_cache.has(key):
		return _glow_cache[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(color.r * energy, color.g * energy, color.b * energy, color.a)
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_glow_cache[key] = m
	return m


## Contorno achatado no chão (plano XZ). `half` = meia-largura/meia-profundidade;
## com `square` faz um retângulo, senão uma elipse.
static func outline_mesh(half: Vector2, width: float, square := false) -> ArrayMesh:
	var pts: Array = []
	if square:
		pts = [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)]
	else:
		for i in 40:
			var a := TAU * i / 40.0
			pts.append(Vector2(cos(a) * half.x, sin(a) * half.y))
	var v := PackedVector3Array()
	var n := pts.size()
	for i in n:
		var p: Vector2 = pts[i]
		var inner: Vector2
		if square:
			inner = p - Vector2(signf(p.x), signf(p.y)) * width
		else:
			inner = p * (1.0 - width / maxf(half.x, half.y))
		v.append(Vector3(p.x, 0, p.y))
		v.append(Vector3(inner.x, 0, inner.y))
	var idx := PackedInt32Array()
	for i in n:
		var a := i * 2
		var b := ((i + 1) % n) * 2
		idx.append_array([a, b, a + 1, b, b + 1, a + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func ring(half: Vector2, width: float, color: Color, square := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = outline_mesh(half, width, square)
	mi.material_override = flat_material(color)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position.y = 0.02
	return mi


## Quadrado com borda suave (partículas redondas). `additive` para luzes e brilhos.
static func _particle_quad(size: float, additive := false) -> QuadMesh:
	var key := "%s|%s" % [size, additive]
	if _quad_cache.has(key):
		return _quad_cache[key]
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never%s;
uniform float energy = 1.0;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0, 0, 0), vec4(0, length(MODEL_MATRIX[1].xyz), 0, 0), vec4(0, 0, length(MODEL_MATRIX[2].xyz), 0), vec4(0, 0, 0, 1));
}
void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float a = smoothstep(1.0, 0.2, d);
	ALBEDO = COLOR.rgb * energy;
	ALPHA = COLOR.a * a;
}
""" % (", blend_add" if additive else "")
	mat.shader = sh
	mat.set_shader_parameter("energy", 1.5 if additive else 1.0)
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = mat
	_quad_cache[key] = q
	return q


static func _ramp(a: Color, b: Color) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, a)
	g.set_color(1, b)
	return g


static func _grow(from: float, to: float) -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0, from))
	c.add_point(Vector2(1, to))
	return c


## Vapor das chaminés e respiros.
static func smoke(heavy := false) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 18 if heavy else 10
	p.lifetime = 3.2
	p.preprocess = 3.2
	p.mesh = _particle_quad(0.4)
	p.direction = Vector3(0.25, 1, 0)
	p.spread = 14.0
	p.gravity = Vector3(0.22, 0.12, 0.05)
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.55
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.1
	p.scale_amount_curve = _grow(0.4, 2.2 if heavy else 1.7)
	var c := Color(0.1, 0.09, 0.1, 0.7) if heavy else Color(0.55, 0.6, 0.65, 0.3)
	p.color_ramp = _ramp(c, Color(c.r + 0.05, c.g + 0.05, c.b + 0.05, 0.0))
	return p


## Faíscas de obra subindo da área do prédio (`area` em células).
static func sparks(area: Vector2, color: Color) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = int(clampf(area.x * area.y * 14.0, 16.0, 90.0))
	p.lifetime = 1.0
	p.mesh = _particle_quad(0.09, true)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(area.x * 0.5, 0.05, area.y * 0.5)
	p.direction = Vector3.UP
	p.spread = 40.0
	p.gravity = Vector3(0, -2.0, 0)
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 2.0
	p.scale_amount_curve = _grow(1.0, 0.2)
	p.color_ramp = _ramp(color.lightened(0.4), Color(color, 0.0))
	return p


## Brilho verde subindo de uma unidade que está sendo curada (dispara uma vez e se apaga).
static func heal_burst(size: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.6
	p.amount = 8
	p.lifetime = 0.9
	p.mesh = _particle_quad(0.1, true)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = size
	p.direction = Vector3.UP
	p.spread = 15.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 0.8
	p.scale_amount_curve = _grow(1.0, 0.3)
	p.color_ramp = _ramp(Color(0.5, 1.0, 0.55), Color(0.3, 1.0, 0.4, 0.0))
	return p


## Plano holográfico que sobe enquanto o prédio é construído.
static func scan_plane(area: Vector2, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = area + Vector2(0.15, 0.15)
	mi.mesh = plane
	mi.material_override = glow_material(Color(color, 0.35), 2.5)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func fire() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 16
	p.lifetime = 0.7
	p.mesh = _particle_quad(0.2, true)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.12
	p.direction = Vector3.UP
	p.spread = 20.0
	p.gravity = Vector3(0, 0.6, 0)
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 0.5
	p.scale_amount_curve = _grow(1.3, 0.3)
	p.color_ramp = _ramp(Color(1.0, 0.7, 0.3, 1.0), Color(0.8, 0.15, 0.05, 0.0))
	return p


## Rastro de projétil (coordenadas globais: fica no ar depois que o projétil passa).
static func trail(color: Color, big := false) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 40
	p.lifetime = 0.35
	p.mesh = _particle_quad(0.12 if big else 0.08, true)
	p.local_coords = false
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.1
	p.spread = 180.0
	p.scale_amount_curve = _grow(1.0, 0.1)
	p.color_ramp = _ramp(Color(color, 0.9), Color(color, 0.0))
	return p


## Chama dos motores das naves.
static func engine_trail(color: Color) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 24
	p.lifetime = 0.45
	p.mesh = _particle_quad(0.1, true)
	p.local_coords = false
	p.gravity = Vector3.ZERO
	p.direction = Vector3(-1, 0, 0)
	p.spread = 6.0
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.5
	p.scale_amount_curve = _grow(1.0, 0.05)
	p.color_ramp = _ramp(Color(color.lightened(0.5), 0.9), Color(color, 0.0))
	return p


## Clarão na boca da arma.
static func muzzle_flash(big: bool, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.08 if big else 0.045
	s.height = s.radius * 2.0
	s.radial_segments = 10
	s.rings = 5
	mi.mesh = s
	mi.material_override = glow_material(color.lightened(0.3), 2.5)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	return mi
