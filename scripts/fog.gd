class_name Fog
extends Node
## Névoa de guerra: escuro total onde nunca foi visto, penumbra onde já foi explorado.
## Uma textura pequena (1 pixel por célula, filtro linear) vira o parâmetro global
## `fog_tex`, que os shaders do chão e dos modelos usam para escurecer o mundo 3D.

const UNSEEN := 0.0
const SEEN := 0.4
const FADE := 5.0   # velocidade da transição entre visível e explorado

var explored := PackedByteArray()
var visible_cells := PackedByteArray()
var _timer := 0.0
var _level := PackedFloat32Array()
var _bytes := PackedByteArray()
var _img: Image
var _tex: ImageTexture


func init() -> void:
	var n := Map.W * Map.H
	explored.resize(n)
	explored.fill(0)
	visible_cells.resize(n)
	visible_cells.fill(0)
	_level.resize(n)
	_level.fill(UNSEEN)
	_bytes.resize(n)
	_bytes.fill(0)
	_img = Image.create_from_data(Map.W, Map.H, false, Image.FORMAT_L8, _bytes)
	_tex = ImageTexture.create_from_image(_img)
	RenderingServer.global_shader_parameter_set("fog_tex", _tex)
	RenderingServer.global_shader_parameter_set("fog_size", Vector2(Map.W, Map.H))
	RenderingServer.global_shader_parameter_set("fog_on", 1.0)


func _exit_tree() -> void:
	RenderingServer.global_shader_parameter_set("fog_on", 0.0)


func is_visible_at(p: Vector2) -> bool:
	var c := Game.map.world_to_cell(p)
	return Game.map.in_bounds(c) and visible_cells[Game.map.idx(c)] == 1


func _process(delta: float) -> void:
	if Game.map == null:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = 0.2
		_update_cells()
	# Transição suave do brilho de cada célula
	var step := delta * FADE
	for i in _level.size():
		var want := UNSEEN if explored[i] == 0 else (SEEN if visible_cells[i] == 0 else 1.0)
		_level[i] = move_toward(_level[i], want, step)
		_bytes[i] = int(_level[i] * 255.0)
	_img.set_data(Map.W, Map.H, false, Image.FORMAT_L8, _bytes)
	_tex.update(_img)


func _update_cells() -> void:
	visible_cells.fill(0)
	for e in Game.entities:
		if e.team != Game.PLAYER or e.dead:
			continue
		var c: Vector2i = Game.map.world_to_cell(e.position)
		var r: int = e.sight
		if e is Building:
			r += 1
		for y in range(-r, r + 1):
			for x in range(-r, r + 1):
				if x * x + y * y > r * r:
					continue
				var n: Vector2i = c + Vector2i(x, y)
				if Game.map.in_bounds(n):
					var i: int = Game.map.idx(n)
					visible_cells[i] = 1
					explored[i] = 1
	# Inimigos só aparecem na área visível (prédios ficam visíveis depois de explorados)
	for e in Game.entities:
		if e.team == Game.PLAYER:
			continue
		var i: int = Game.map.idx(Game.map.world_to_cell(e.position))
		if e is Building:
			e.visible = explored[i] == 1
		else:
			e.visible = visible_cells[i] == 1
