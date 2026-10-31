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


func command_move(goal: Vector2) -> void:
	super.command_move(goal)
	state = "manual"


func command_attack_move(goal: Vector2) -> void:
	super.command_attack_move(goal)
	state = "manual"


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
				ore_cell = Game.map.nearest_ore(position, 24)
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
				if Game.map.world_to_cell(position) == ore_cell:
					state = "harvest"
				else:
					state = "seek"
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
				if position.distance_to(refinery.dock_position()) < 40.0:
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
