class_name Models
extends RefCounted
## Carrega os modelos .glb gerados no Blender (art_src/blender) e prepara os materiais.
##
## Os materiais do Blender viram um shader PBR próprio que soma detalhes procedurais
## (linhas de painel no metal, textura orgânica nos insetos), a cor do time, brilho
## emissivo e a névoa de guerra. Cada material é reconhecido pelo nome (o "papel"):
## hull, dark, metal, accent, team, glow, engine, glass, chitin, flesh, bone, crystal...
##
## Grupos móveis do Blender viram Node3D com o mesmo nome (turret, gun, leg_*, wing_*,
## torso, spin). Localizadores são nós "loc_<nome>_<n>" e recebem o meta "locator".
## Eixos: X = frente, Y = cima, Z = direita. 1 unidade = 1 célula do mapa.

const UNIT := 1.0
const DIR := "res://models/"

const SHADER := """
shader_type spatial;
render_mode cull_back;

uniform vec4 albedo : source_color = vec4(1.0);
uniform float metallic = 0.0;
uniform float roughness = 0.5;
uniform vec3 emission : source_color = vec3(0.0);
uniform float emission_energy = 0.0;
uniform float panels = 0.0;
uniform float organic = 0.0;
uniform float team_mask = 0.0;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 team_color : source_color = vec4(0.0);
uniform float no_fog = 0.0;
global uniform sampler2D fog_tex;
global uniform float fog_on;
global uniform vec2 fog_size;
varying vec3 wpos;
varying vec3 opos;
varying vec3 onrm;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x),
			mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
			mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	opos = VERTEX;
	onrm = NORMAL;
}

void fragment() {
	vec3 tc = team_color.a > 0.5 ? team_color.rgb : albedo.rgb;
	vec3 base = mix(albedo.rgb, tc, team_mask);
	float rough = roughness;
	if (panels > 0.0) {
		// Linhas de painel em projeção triplanar no espaço do objeto
		vec3 n = abs(onrm);
		vec3 q = opos * 7.0;
		vec2 uv = n.x > max(n.y, n.z) ? q.zy : (n.y > n.z ? q.xz : q.xy);
		uv.y += floor(uv.x) * 0.5;
		vec2 g = abs(fract(uv) - 0.5);
		float line = smoothstep(0.465, 0.49, max(g.x, g.y));
		float grime = vnoise(opos * 11.0);
		base *= (1.0 - line * 0.45 * panels) * (0.9 + 0.2 * grime);
		rough = clamp(rough + (vnoise(opos * 41.0) - 0.5) * 0.25 * panels + line * 0.2, 0.04, 1.0);
	}
	if (organic > 0.0) {
		float n1 = vnoise(opos * 12.0);
		float n2 = vnoise(opos * 37.0);
		float veins = smoothstep(0.42, 0.5, n1) * smoothstep(0.58, 0.5, n1);
		base *= 0.78 + 0.4 * n1 * organic;
		base += veins * tc * 0.25 * organic;
		rough = clamp(rough + (n2 - 0.5) * 0.35 * organic, 0.05, 1.0);
	}
	float f = 1.0;
	if (fog_on > 0.5 && no_fog < 0.5) {
		vec2 fuv = wpos.xz / fog_size;
		f = (fuv.x < 0.0 || fuv.y < 0.0 || fuv.x > 1.0 || fuv.y > 1.0) ? 0.0 : texture(fog_tex, fuv).r;
	}
	ALBEDO = base * tint.rgb * f;
	METALLIC = metallic;
	ROUGHNESS = rough;
	vec3 em = emission * emission_energy;
	if (team_mask > 0.5 && emission_energy > 0.0) {
		em = tc * emission_energy;
	}
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	em += tc * rim * 0.18;
	EMISSION = em * tint.a * f;
}
"""

## Camada aditiva por cima do modelo no instante em que ele leva dano
const HIT_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, blend_add, depth_draw_never;

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 1.5);
	ALBEDO = vec3(0.9, 0.85, 0.75) * (0.35 + rim);
}
"""

const GHOST_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, blend_add, depth_draw_never;
uniform vec4 ghost : source_color = vec4(1.0, 1.0, 1.0, 0.5);

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	ALBEDO = ghost.rgb * (0.25 + rim * 0.9);
	ALPHA = ghost.a;
}
"""

## Energia emissiva e detalhes por papel do material
const ROLES := {
	"glow": {"emit": 2.0}, "engine": {"emit": 2.6}, "glass": {"emit": 0.6},
	"crystal": {"emit": 0.9}, "team": {"team": 1.0},
	"hull": {"panels": 1.0}, "dark": {"panels": 0.7}, "metal": {"panels": 0.4},
	"accent": {"panels": 0.6}, "chitin": {"organic": 1.0}, "flesh": {"organic": 1.0},
	"bone": {"organic": 0.6}, "rock": {"organic": 0.7}, "plant": {"organic": 0.8},
}

static var _cache := {}
static var _shader: Shader
static var _ghost_shader: Shader
static var _ghost_mat: ShaderMaterial
static var _hit_mat: ShaderMaterial
## Variantes de material (cor do time, tinta, névoa): chave -> ShaderMaterial. Sem
## "instance uniform", que estoura o limite do WebGL/OpenGL com muitas peças animadas.
static var _variants := {}


## Nova instância do modelo `name` (models/<name>.glb). A preparação é feita uma vez só.
static func instantiate(name: String) -> Node3D:
	return _entry(name)["node"].duplicate()


## AABB do modelo, em unidades do mundo (pose de repouso).
static func aabb(name: String) -> AABB:
	return _entry(name)["aabb"]


## Primeira malha do modelo, já com os materiais do jogo (para MultiMesh, ex.: cristais).
static func first_mesh(name: String) -> Mesh:
	for mi in _entry(name)["node"].find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = mi.mesh.duplicate()
		for s in m.get_surface_count():
			m.surface_set_material(s, mi.get_surface_override_material(s))
		return m
	return null


static func locators(node: Node) -> Array:
	var out: Array = []
	for n in node.find_children("loc_*", "Node3D", true, false):
		out.append(n)
	return out


static func locator(node: Node, loc_name: String) -> Node3D:
	for m in locators(node):
		if m.get_meta("locator", "") == loc_name:
			return m
	return null


static func locators_named(node: Node, loc_name: String) -> Array:
	return locators(node).filter(func(m): return m.get_meta("locator", "") == loc_name)


## Posição de um nó do modelo em relação à raiz do modelo.
static func local_position(model: Node3D, node: Node3D) -> Vector3:
	var t := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != model:
		t = (n as Node3D).transform * t
		n = n.get_parent()
	return t.origin


static func _meshes(node: Node) -> Array:
	return node.find_children("*", "MeshInstance3D", true, false)


## Tinta multiplicada (ex.: carcaça queimada). alpha = intensidade do brilho emissivo.
static func set_tint(node: Node, color: Color, ignore_fog := false) -> void:
	for mi in _meshes(node):
		mi.material_override = null
	_apply(node, {"tint": color, "no_fog": 1.0 if ignore_fog else 0.0})


static func set_team(node: Node, color: Color) -> void:
	_apply(node, {"team_color": Color(color, 1.0)})


## Clarão ao levar dano: uma camada aditiva enquanto `amount` > 0.
static func set_hit(node: Node, amount: float) -> void:
	if _hit_mat == null:
		_hit_mat = ShaderMaterial.new()
		var sh := Shader.new()
		sh.code = HIT_SHADER
		_hit_mat.shader = sh
	for mi in _meshes(node):
		mi.material_overlay = _hit_mat if amount > 0.0 else null


## Troca os materiais de cada peça pela variante com estes parâmetros (em cache).
static func _apply(node: Node, params: Dictionary) -> void:
	for mi in _meshes(node):
		for s in mi.mesh.get_surface_count():
			var cur = mi.get_surface_override_material(s)
			if not (cur is ShaderMaterial):
				continue
			var key := "%d|%s" % [cur.get_instance_id(), params]
			if not _variants.has(key):
				var v: ShaderMaterial = cur.duplicate()
				for p in params:
					v.set_shader_parameter(p, params[p])
				_variants[key] = v
			mi.set_surface_override_material(s, _variants[key])


## Holograma semitransparente (posicionamento de construção).
static func set_ghost(node: Node, color: Color) -> void:
	if _ghost_shader == null:
		_ghost_shader = Shader.new()
		_ghost_shader.code = GHOST_SHADER
		_ghost_mat = ShaderMaterial.new()
		_ghost_mat.shader = _ghost_shader
	_ghost_mat.set_shader_parameter("ghost", color)
	for mi in _meshes(node):
		mi.material_override = _ghost_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Libera os modelos-base guardados no cache (chamado ao fechar o jogo).
static func clear_cache() -> void:
	for e in _cache.values():
		e["node"].free()
	_cache.clear()
	_shader = null
	_ghost_shader = null
	_ghost_mat = null
	_hit_mat = null
	_variants.clear()
	Fx3D._quad_cache.clear()
	Fx3D._glow_cache.clear()


# ---------------------------------------------------------------- montagem

static func _entry(name: String) -> Dictionary:
	if not _cache.has(name):
		_cache[name] = _build(name)
	return _cache[name]


static func _build(name: String) -> Dictionary:
	var path := DIR + name + ".glb"
	var scene: PackedScene = load(path) if ResourceLoader.exists(path) else null
	if scene == null:
		push_error("Modelo não encontrado: " + path)
		return {"node": Node3D.new(), "aabb": AABB(Vector3(-0.3, 0, -0.3), Vector3(0.6, 0.6, 0.6))}
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var root: Node3D = scene.instantiate()
	root.name = name
	var mats := {}
	var box := AABB()
	var first := true
	for mi in _meshes(root):
		var mesh: Mesh = mi.mesh
		for s in mesh.get_surface_count():
			var src: Material = mi.get_active_material(s)
			var key := src.resource_name if src != null else "hull"
			if not mats.has(key):
				mats[key] = _convert(src, key, name.begins_with("ins_") or name.ends_with("_ins"))
			mi.set_surface_override_material(s, mats[key])
		var t := _to_root(root, mi)
		var b: AABB = t * mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	for n in root.find_children("loc_*", "Node3D", true, false):
		var parts := String(n.name).split("_")
		n.set_meta("locator", parts[1] if parts.size() > 1 else "")
	return {"node": root, "aabb": box}


static func _to_root(root: Node3D, n: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var c: Node = n
	while c != null and c != root:
		t = (c as Node3D).transform * t
		c = c.get_parent()
	return t


static func _convert(src: Material, role: String, bio := false) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	var base := Color(0.6, 0.6, 0.6)
	var metal := 0.0
	var rough := 0.6
	var emit := Color.BLACK
	if src is BaseMaterial3D:
		base = src.albedo_color
		metal = src.metallic
		rough = src.roughness
		if src.emission_enabled:
			emit = src.emission
	var r: Dictionary = ROLES.get(role.get_slice(".", 0), {})
	if bio and (role == "hull" or role == "dark"):
		r = {"organic": 0.8}
	mat.set_shader_parameter("albedo", base)
	mat.set_shader_parameter("metallic", metal)
	mat.set_shader_parameter("roughness", rough)
	mat.set_shader_parameter("emission", emit if emit != Color.BLACK else base)
	mat.set_shader_parameter("emission_energy", float(r.get("emit", 0.0)))
	mat.set_shader_parameter("panels", float(r.get("panels", 0.0)))
	mat.set_shader_parameter("organic", float(r.get("organic", 0.0)))
	mat.set_shader_parameter("team_mask", float(r.get("team", 0.0)))
	return mat
