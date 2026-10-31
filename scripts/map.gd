class_name Map
extends Node3D
## Mapa em grade: terreno, campos de cristal, bloqueio de prédios e pathfinding (AStarGrid2D).
## O chão é um shader procedural (poeira e basalto alienígenas); os cristais são malhas
## instanciadas (MultiMesh) que encolhem conforme são extraídos.

enum { GRASS, ROCK, ORE }

const W := 64
const H := 48
const ORE_MAX := 350.0
const CRYSTALS_PER_CELL := 2

var tiles := PackedInt32Array()
var ore := PackedFloat32Array()
var blocked := PackedByteArray()
var astar := AStarGrid2D.new()
var rng := RandomNumberGenerator.new()
var _dirty_timer := 0.0
var _dirty := false
var _terrain: MeshInstance3D
var _terrain_mat: ShaderMaterial
var _cell_img: Image
var _cell_tex: ImageTexture
var _crystals: MultiMeshInstance3D
var _crystal_cells := PackedInt32Array()   # índice da célula de cada instância
var _crystal_base: Array = []               # Transform3D de cada instância (tamanho cheio)

const TERRAIN_SHADER := """
shader_type spatial;
render_mode specular_schlick_ggx;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform sampler2D detail_tex : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2D cell_tex : filter_linear;
uniform vec2 map_size = vec2(64.0, 48.0);
global uniform sampler2D fog_tex;
global uniform float fog_on;
global uniform vec2 fog_size;
varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	float n1 = texture(noise_tex, p * 0.031).r;
	float n2 = texture(noise_tex, p * 0.13 + vec2(0.37, 0.11)).r;
	float n3 = texture(noise_tex, p * 0.71 + vec2(0.5, 0.2)).r;
	float n4 = texture(noise_tex, p * 2.3).r;
	vec3 basalt = vec3(0.085, 0.075, 0.085);
	vec3 dust = vec3(0.30, 0.205, 0.17);
	vec3 pale = vec3(0.42, 0.34, 0.30);
	vec3 col = mix(basalt, dust, smoothstep(0.32, 0.68, n1));
	col = mix(col, pale, smoothstep(0.62, 0.82, n2) * 0.4);
	col *= 0.82 + 0.25 * n3 + 0.12 * n4;
	// rachaduras
	float cr = abs(texture(noise_tex, p * 0.19 + vec2(0.7, 0.3)).r - 0.5);
	float crack = 1.0 - smoothstep(0.0, 0.025, cr);
	col *= 1.0 - crack * 0.45;
	vec4 cell = texture(cell_tex, p / map_size);
	col = mix(col, basalt * 0.75, cell.g * 0.65);
	// campos de cristal: chão arroxeado com brilho fraco
	vec3 vio = vec3(0.30, 0.16, 0.45);
	col = mix(col, vio * (0.7 + 0.5 * n3), cell.r * 0.65);
	ALBEDO = col;
	ROUGHNESS = 0.88 - cell.r * 0.3 - crack * 0.1;
	NORMAL_MAP = texture(detail_tex, p * 0.45).rgb;
	NORMAL_MAP_DEPTH = 1.4;
	vec3 em = vec3(0.5, 0.22, 1.0) * cell.r * 0.1 * (0.5 + 0.8 * n4);
	float f = 1.0;
	vec2 fuv = p / fog_size;
	bool outside = fuv.x < 0.0 || fuv.y < 0.0 || fuv.x > 1.0 || fuv.y > 1.0;
	if (fog_on > 0.5) {
		f = outside ? 0.0 : texture(fog_tex, fuv).r;
	} else if (outside) {
		f = 0.35;
	}
	ALBEDO *= f;
	EMISSION = em * f;
}
"""


func generate(seed_value: int, base_centers: Array, ore_fields: Array) -> void:
	rng.seed = seed_value
	var n := W * H
	tiles.resize(n)
	tiles.fill(GRASS)
	ore.resize(n)
	ore.fill(0.0)
	blocked.resize(n)
	blocked.fill(0)

	# Formações rochosas (intransponíveis)
	for i in 26:
		var c := Vector2i(rng.randi_range(0, W - 1), rng.randi_range(0, H - 1))
		_fill_circle(c, rng.randi_range(1, 3), ROCK)

	# Área livre ao redor das bases
	for b in base_centers:
		_fill_circle(b, 8, GRASS)

	# Campos de cristal: [centro, raio]
	for f in ore_fields:
		var center: Vector2i = f[0]
		var r: int = f[1]
		for y in range(-r, r + 1):
			for x in range(-r, r + 1):
				var c: Vector2i = center + Vector2i(x, y)
				if in_bounds(c) and Vector2(x, y).length() <= r + 0.3 and tiles[idx(c)] == GRASS:
					tiles[idx(c)] = ORE
					ore[idx(c)] = rng.randf_range(150.0, ORE_MAX)

	astar.region = Rect2i(0, 0, W, H)
	astar.cell_size = Vector2(Game.TILE, Game.TILE)
	astar.offset = Vector2(Game.TILE, Game.TILE) / 2.0
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for y in H:
		for x in W:
			if tiles[y * W + x] == ROCK:
				astar.set_point_solid(Vector2i(x, y), true)
	_build_terrain()
	_build_crystals()


func _fill_circle(center: Vector2i, r: int, value: int) -> void:
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			var c := center + Vector2i(x, y)
			if in_bounds(c) and Vector2(x, y).length() <= r + rng.randf() * 0.6:
				tiles[idx(c)] = value


# ---------------------------------------------------------------- utilitários

func idx(c: Vector2i) -> int:
	return c.y * W + c.x


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < W and c.y < H


func world_to_cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / Game.TILE), floori(p.y / Game.TILE))


func cell_center(c: Vector2i) -> Vector2:
	return (Vector2(c) + Vector2(0.5, 0.5)) * Game.TILE


func is_walkable(c: Vector2i) -> bool:
	return in_bounds(c) and tiles[idx(c)] != ROCK and blocked[idx(c)] == 0


func is_walkable_world(p: Vector2) -> bool:
	return is_walkable(world_to_cell(p))


func is_buildable(c: Vector2i) -> bool:
	return in_bounds(c) and tiles[idx(c)] == GRASS and blocked[idx(c)] == 0


func set_cells_blocked(origin: Vector2i, size: Vector2i, value: bool) -> void:
	for y in size.y:
		for x in size.x:
			var c := origin + Vector2i(x, y)
			if not in_bounds(c):
				continue
			blocked[idx(c)] = 1 if value else 0
			astar.set_point_solid(c, value or tiles[idx(c)] == ROCK)


func nearest_walkable(c: Vector2i) -> Vector2i:
	if is_walkable(c):
		return c
	for r in range(1, 14):
		for y in range(-r, r + 1):
			for x in range(-r, r + 1):
				if absi(x) != r and absi(y) != r:
					continue
				var n := c + Vector2i(x, y)
				if is_walkable(n):
					return n
	return c


func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var a := nearest_walkable(world_to_cell(from))
	var b := nearest_walkable(world_to_cell(to))
	if not is_walkable(a) or not is_walkable(b):
		return PackedVector2Array()
	return astar.get_point_path(a, b)


# ---------------------------------------------------------------- cristais

func ore_at(c: Vector2i) -> float:
	if not in_bounds(c):
		return 0.0
	return ore[idx(c)]


func take_ore(c: Vector2i, amount: float) -> float:
	if not in_bounds(c) or tiles[idx(c)] != ORE:
		return 0.0
	var i := idx(c)
	var got := minf(amount, ore[i])
	ore[i] -= got
	if ore[i] <= 0.5:
		ore[i] = 0.0
		tiles[i] = GRASS
	_dirty = true
	return got


func nearest_ore(p: Vector2, max_r: int) -> Vector2i:
	var c := world_to_cell(p)
	var best := Vector2i(-1, -1)
	var best_d := INF
	for y in range(maxi(0, c.y - max_r), mini(H, c.y + max_r + 1)):
		for x in range(maxi(0, c.x - max_r), mini(W, c.x + max_r + 1)):
			var i := y * W + x
			if tiles[i] == ORE and ore[i] > 0.0:
				var d := Vector2(x - c.x, y - c.y).length_squared()
				if d < best_d:
					best_d = d
					best = Vector2i(x, y)
	return best


## Os cristais crescem de novo devagar nos campos que ainda existem.
func _process(delta: float) -> void:
	_dirty_timer -= delta
	if _dirty_timer > 0.0:
		return
	_dirty_timer = 0.5
	for i in (0 if Net.is_client() else 6):   # no convidado os cristais vêm do anfitrião
		var j := rng.randi_range(0, W * H - 1)
		if tiles[j] == ORE and ore[j] < ORE_MAX:
			ore[j] = minf(ORE_MAX, ore[j] + 40.0)
			_dirty = true
	if _dirty:
		_dirty = false
		_update_cells()
		_update_crystals()


## Multiplayer: quantidade de cristal de cada célula, em 1 byte (0 = sem cristal).
func ore_bytes() -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(W * H)
	for i in W * H:
		out[i] = 0 if tiles[i] != ORE else clampi(ceili(ore[i] / ORE_MAX * 255.0), 1, 255)
	return out


func apply_ore_bytes(data: PackedByteArray) -> void:
	for i in mini(data.size(), W * H):
		if tiles[i] == ROCK:
			continue
		if data[i] == 0:
			if tiles[i] == ORE:
				tiles[i] = GRASS
				ore[i] = 0.0
				_dirty = true
		else:
			var v := data[i] / 255.0 * ORE_MAX
			if absf(v - ore[i]) > 2.0:
				ore[i] = v
				_dirty = true


## Rochas, pináculos e plantas alienígenas nas células intransponíveis.
func spawn_props(parent: Node3D) -> void:
	var names := ["prop_rock_a", "prop_rock_b", "prop_rock_c", "prop_spire_a", "prop_spire_b",
			"prop_plant", "prop_debris", "prop_crystal"]
	var weights := [4, 4, 3, 2, 2, 1, 1, 1]
	for y in H:
		for x in W:
			if tiles[y * W + x] != ROCK:
				continue
			var p := Models.instantiate(names[_weighted(weights)])
			p.rotation.y = rng.randf() * TAU
			p.scale *= rng.randf_range(1.0, 1.35)
			var jitter := Vector2(rng.randf_range(-4, 4), rng.randf_range(-4, 4))
			p.position = Game.to3d(cell_center(Vector2i(x, y)) + jitter)
			parent.add_child(p)


func _weighted(weights: Array) -> int:
	var total := 0
	for w in weights:
		total += w
	var r := rng.randi_range(0, total - 1)
	for i in weights.size():
		r -= weights[i]
		if r < 0:
			return i
	return 0


# ---------------------------------------------------------------- visual

func _noise_tex(freq: float, normal := false) -> NoiseTexture2D:
	var nz := FastNoiseLite.new()
	nz.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	nz.frequency = freq
	nz.fractal_octaves = 5
	nz.seed = rng.randi()
	var t := NoiseTexture2D.new()
	t.width = 512
	t.height = 512
	t.seamless = true
	t.noise = nz
	t.generate_mipmaps = true
	if normal:
		t.as_normal_map = true
		t.bump_strength = 6.0
	return t


func _build_terrain() -> void:
	_cell_img = Image.create_empty(W, H, false, Image.FORMAT_RGBA8)
	_cell_tex = ImageTexture.create_from_image(_cell_img)
	_update_cells()
	_terrain = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(W + 80, H + 80)
	_terrain.mesh = plane
	_terrain.position = Vector3(W / 2.0, 0, H / 2.0)
	_terrain_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = TERRAIN_SHADER
	_terrain_mat.shader = sh
	_terrain_mat.set_shader_parameter("noise_tex", _noise_tex(0.008))
	_terrain_mat.set_shader_parameter("detail_tex", _noise_tex(0.02, true))
	_terrain_mat.set_shader_parameter("cell_tex", _cell_tex)
	_terrain_mat.set_shader_parameter("map_size", Vector2(W, H))
	_terrain.material_override = _terrain_mat
	_terrain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_terrain)


## Textura de dados por célula para o shader do chão: R = cristal, G = rocha.
func _update_cells() -> void:
	for y in H:
		for x in W:
			var i := y * W + x
			var r := clampf(ore[i] / ORE_MAX, 0.0, 1.0) * 0.6 + (0.4 if tiles[i] == ORE else 0.0)
			var g := 1.0 if tiles[i] == ROCK else 0.0
			_cell_img.set_pixel(x, y, Color(r, g, 0.0))
	_cell_tex.update(_cell_img)


func _build_crystals() -> void:
	var mesh := Models.first_mesh("ore_crystal")
	if mesh == null:
		return
	_crystal_base.clear()
	var cells := PackedInt32Array()
	for i in W * H:
		if tiles[i] == ORE:
			for k in CRYSTALS_PER_CELL:
				cells.append(i)
				var c := Vector2i(i % W, i / W)
				var off := Vector2(rng.randf_range(-9, 9), rng.randf_range(-9, 9))
				var t := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.8, 1.3)),
						Game.to3d(cell_center(c) + off))
				_crystal_base.append(t)
	_crystal_cells = cells
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = cells.size()
	_crystals = MultiMeshInstance3D.new()
	_crystals.multimesh = mm
	add_child(_crystals)
	_update_crystals()


func _update_crystals() -> void:
	if _crystals == null:
		return
	var mm := _crystals.multimesh
	for k in _crystal_cells.size():
		var i := _crystal_cells[k]
		var f := clampf(ore[i] / ORE_MAX, 0.0, 1.0)
		var s := 0.0 if tiles[i] != ORE else 0.35 + 0.65 * f
		var t: Transform3D = _crystal_base[k]
		mm.set_instance_transform(k, Transform3D(t.basis.scaled(Vector3.ONE * maxf(s, 0.001)), t.origin))
