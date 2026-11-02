class_name Harvester
extends Unit
## Coletor: procura minério, enche, volta para a refinaria e descarrega em créditos.

const CAPACITY := 500.0
const HARVEST_RATE := 60.0   # minério por segundo
const UNLOAD_RATE := 250.0   # créditos por segundo

var cargo := 0.0
var state := "seek"
var ore_cell := Vector2i(-1, -1)
var refinery: Building = null
var think := 0.0
## Campo de trabalho: onde coletou por último (ou para onde o jogador mandou). Depois de
## descarregar o coletor volta para ele, por mais longe que esteja da refinaria.
var field := Vector2(-1, -1)


func command_move(goal: Vector2) -> void:
	super.command_move(goal)
	state = "manual"
	field = goal


func command_attack_move(goal: Vector2) -> void:
	super.command_attack_move(goal)
	state = "manual"
	field = goal


## Cristal para coletar: perto do campo de trabalho; senão perto do coletor; senão o mais
## próximo no mapa inteiro.
func _find_ore() -> Vector2i:
	var c := Vector2i(-1, -1)
	if field.x >= 0.0:
		c = Game.map.nearest_ore(field, 8)
	if c.x < 0:
		c = Game.map.nearest_ore(position, 24)
	if c.x < 0:
		c = Game.map.nearest_ore(position, maxi(Map.W, Map.H))
	return c


func _arrived() -> bool:
	return path_index >= path.size()


func _process(delta: float) -> void:
	super._process(delta)
	if Game.game_over or Net.is_client():
		return # no convidado a coleta roda no anfitrião
	think -= delta
	match state:
		"manual":
			if _arrived():
				state = "seek"
				think = 0.0
		"seek":
			if cargo >= CAPACITY:
				state = "return"
			elif think <= 0.0:
				think = 1.0
				ore_cell = _find_ore()
				if ore_cell.x >= 0:
					_set_path(Game.map.cell_center(ore_cell))
					state = "to_ore"
				elif cargo > 0.0:
					state = "return"
		"to_ore":
			if Game.map.ore_at(ore_cell) <= 0.0:
				state = "seek"
				think = 0.0
			elif _arrived():
				# Outro coletor pode estar na célula: colhe de perto mesmo assim
				if position.distance_to(Game.map.cell_center(ore_cell)) < Game.TILE * 1.6:
					state = "harvest"
					field = Game.map.cell_center(ore_cell)
				else:
					state = "seek"
					think = 0.5
		"harvest":
			var got := Game.map.take_ore(ore_cell, HARVEST_RATE * delta)
			cargo += got
			if cargo >= CAPACITY:
				cargo = CAPACITY
				state = "return"
			elif got <= 0.0:
				state = "seek"
				think = 0.0
		"return":
			refinery = Game.nearest_building(team, "refinery", position)
			if refinery == null:
				state = "seek"
				think = 2.0
			else:
				_set_path(refinery.dock_position())
				state = "to_refinery"
		"to_refinery":
			if not valid_target(refinery):
				state = "return"
			elif _arrived():
				if position.distance_to(refinery.dock_position()) < Game.TILE * 1.7:
					state = "unload"
				else:
					state = "return"
		"unload":
			if not valid_target(refinery):
				state = "return"
				return
			var amount := minf(cargo, UNLOAD_RATE * delta)
			cargo -= amount
			Game.credits[team] += amount
			if cargo <= 0.0:
				cargo = 0.0
				state = "seek"
				think = 0.0
