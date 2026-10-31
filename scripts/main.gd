extends Node3D
## Cena principal: monta o mundo 3D e cuida da entrada do jogador (seleção, ordens, construção).
##
## A lógica usa coordenadas de chão (pixels de chão). O mouse vira um raio da câmera:
## o ponto onde ele cruza o chão é a posição das ordens, e as caixas das entidades
## decidem o que está sob o cursor.

const PLAYER_BASE := Vector2i(8, 38)
const ENEMY_BASE := Vector2i(55, 10)

var map: Map
var world: Node3D
var fog: Fog
var overlay: Overlay
var cam: RTSCamera
var hud: HUD
var ai: EnemyAI
var pause_menu: PauseMenu

var selection: Array = []
var dragging := false
var drag_start := Vector2.ZERO   # posição na tela
var placing := ""
var _ghost: Node3D
var _ghost_type := ""
var _ghost_area: MeshInstance3D
var _last_ground := Vector2.ZERO


func _ready() -> void:
	Game.reset()

	world = Node3D.new()
	world.name = "World"
	add_child(world)
	Game.world = world

	map = Map.new()
	world.add_child(map)
	Game.map = map
	map.generate(randi(), [PLAYER_BASE, ENEMY_BASE], [
		[Vector2i(18, 35), 3], [Vector2i(45, 15), 3],    # perto das bases
		[Vector2i(32, 24), 4],                            # centro, mais rico
		[Vector2i(13, 12), 3], [Vector2i(51, 36), 3],     # cantos
	])
	map.spawn_props(world)

	fog = Fog.new()
	add_child(fog)
	fog.init()
	Game.fog = fog

	_setup_lights()
	add_child(Tracers.new())

	cam = RTSCamera.new()
	add_child(cam)
	cam.make_current()

	var layer := CanvasLayer.new()
	layer.layer = 0
	add_child(layer)
	overlay = Overlay.new()
	overlay.main = self
	layer.add_child(overlay)
	add_child(Ambience.new())

	hud = HUD.new()
	add_child(hud)
	hud.place_requested.connect(_on_place_requested)
	hud.minimap_clicked.connect(_on_minimap_clicked)
	hud.pause_requested.connect(func(): pause_menu.open())

	pause_menu = PauseMenu.new()
	add_child(pause_menu)

	ai = EnemyAI.new()
	add_child(ai)

	_setup_bases()
	cam.focus(map.cell_center(PLAYER_BASE))
	var f := Game.faction(Game.PLAYER)
	hud.show_message("%s: construa %s → %s e destrua a base inimiga!" % [f["army"], f["buildings"]["power"], f["buildings"]["refinery"]])


## Planeta alienígena: sol branco-azulado, luz de preenchimento violeta, bloom, oclusão de
## ambiente e névoa fria no horizonte.
func _setup_lights() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.02, 0.035)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.55, 0.7)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_strength = 0.9
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.25
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	for lvl in [1, 2, 3, 4]:
		env.set_glow_level(lvl, true)
	env.ssao_enabled = true
	env.ssao_radius = 0.8
	env.ssao_intensity = 1.6
	env.ssao_power = 1.3
	env.ssil_enabled = false
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.08
	env.fog_enabled = true
	env.fog_light_color = Color(0.25, 0.22, 0.35)
	env.fog_density = 0.0015
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.95, 0.88)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.85
	sun.shadow_blur = 1.2
	sun.directional_shadow_max_distance = 50.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.basis = Basis.looking_at(Vector3(0.55, -1.0, -0.6), Vector3.UP)
	add_child(sun)
	# Luz de recorte vinda do lado oposto, fria e arroxeada (dá volume aos modelos)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.55, 0.45, 1.0)
	fill.light_energy = 0.45
	fill.basis = Basis.looking_at(Vector3(-0.6, -0.5, 0.7), Vector3.UP)
	add_child(fill)


func _setup_bases() -> void:
	var pf := Game.faction(Game.PLAYER)
	var ef := Game.faction(Game.ENEMY)
	# Jogador: só o centro de comando e algumas tropas
	Game.spawn_building("cy", Game.PLAYER, Vector2i(6, 37))
	for i in 3:
		Game.spawn_unit(pf["infantry"][0], Game.PLAYER, map.cell_center(Vector2i(10 + i, 35)))
	Game.spawn_unit(pf["starter_tank"], Game.PLAYER, map.cell_center(Vector2i(11, 37)))

	# Inimigo: base pronta
	var e := Game.ENEMY
	Game.spawn_building("cy", e, Vector2i(52, 6))
	Game.spawn_building("power", e, Vector2i(56, 6))
	Game.spawn_building("power", e, Vector2i(59, 6))
	Game.spawn_building("barracks", e, Vector2i(56, 9))
	Game.spawn_building("refinery", e, Vector2i(52, 10))
	Game.spawn_building("factory", e, Vector2i(58, 11))
	Game.spawn_building("turret", e, Vector2i(49, 14))
	Game.spawn_building("turret", e, Vector2i(54, 14))
	Game.spawn_building("starport", e, Vector2i(48, 6))
	for i in 2:
		Game.spawn_unit(ef["infantry"][i], e, map.cell_center(Vector2i(52 + i, 15)))


func screen_mouse() -> Vector2:
	return get_viewport().get_mouse_position()


## Ponto do chão sob o mouse, em pixels de chão.
func ground_mouse() -> Vector2:
	var g = cam.ground_at(screen_mouse())
	if g != null:
		_last_ground = Game.to_ground(g)
	return _last_ground


# ---------------------------------------------------------------- entrada

func _process(_delta: float) -> void:
	var alive := selection.filter(func(s): return is_instance_valid(s) and not s.dead)
	if alive.size() != selection.size():
		selection = alive
		hud.info.set_selection(selection)
	# Se o botão foi solto em cima da barra lateral, o evento não chega aqui
	if dragging and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		dragging = false
		_finish_selection(screen_mouse())
	_update_ghost()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R and Game.game_over:
			get_tree().reload_current_scene()
		elif event.keycode == KEY_M and Game.game_over:
			get_tree().change_scene_to_file("res://scenes/menu.tscn")
		elif event.keycode == KEY_ESCAPE:
			# Esc cancela o que estiver em andamento; sem nada para cancelar, pausa
			if placing != "":
				placing = ""
			elif not selection.is_empty():
				_set_selection([])
			else:
				pause_menu.open()
		elif event.keycode == KEY_P:
			pause_menu.open()
		elif event.keycode == KEY_K and not Game.game_over:
			toggle_repair_selected()
		elif event.keycode == KEY_F11:
			Ambience.toggle_fullscreen()
		return
	if Game.game_over or not (event is InputEventMouseButton):
		return

	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if placing != "":
				_try_place()
			else:
				dragging = true
				drag_start = event.position
		elif dragging:
			dragging = false
			_finish_selection(event.position)
	elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if placing != "":
			placing = ""
		else:
			_command(ground_mouse(), event.ctrl_pressed)


func _set_selection(list: Array) -> void:
	for s in selection:
		if is_instance_valid(s):
			s.selected = false
	selection = list
	for s in selection:
		s.selected = true
	hud.info.set_selection(selection)


func _finish_selection(end: Vector2) -> void:
	var rect := Rect2(drag_start, end - drag_start).abs()
	var picked: Array = []
	if rect.size.length() < 6.0:
		var e = _entity_at()
		if e != null and e.team == Game.PLAYER:
			picked.append(e)
	else:
		for e in Game.entities:
			if e is Unit and e.team == Game.PLAYER:
				var c: Vector3 = e.center3d()
				if not cam.is_position_behind(c) and rect.has_point(cam.unproject_position(c)):
					picked.append(e)
	_set_selection(picked)


## Entidade sob o mouse: o raio da câmera contra a caixa de cada uma.
## Unidades têm prioridade; entre várias, ganha a mais próxima da câmera.
func _entity_at():
	var from := cam.project_ray_origin(screen_mouse())
	var dir := cam.project_ray_normal(screen_mouse())
	for pass_units in [true, false]:
		var best = null
		var best_d := INF
		for e in Game.entities:
			if (e is Unit) != pass_units or not e.visible:
				continue
			var hit = e.pick_box().intersects_ray(from, dir)
			if hit != null:
				var d := from.distance_to(hit)
				if d < best_d:
					best_d = d
					best = e
		if best != null:
			return best
	return null


func _command(pos: Vector2, attack_move: bool) -> void:
	var units := selection.filter(func(s): return s is Unit)
	if units.is_empty():
		return
	var target = _entity_at()
	if target != null and target.team != Game.PLAYER:
		for u in units:
			u.command_attack(target)
		overlay.add_marker(target.position, Color(1, 0.3, 0.25))
		return

	# Formação em grade ao redor do ponto clicado
	var n := units.size()
	var cols := ceili(sqrt(n))
	var rows := ceili(float(n) / cols)
	for i in n:
		var col := i % cols
		var row := floori(float(i) / cols)
		var off := Vector2(col - (cols - 1) / 2.0, row - (rows - 1) / 2.0) * 24.0
		if attack_move:
			units[i].command_attack_move(pos + off)
		else:
			units[i].command_move(pos + off)
	overlay.add_marker(pos, Color(1, 0.6, 0.3) if attack_move else Color(0.95, 0.85, 0.5))


func _on_minimap_clicked(ground_pos: Vector2) -> void:
	cam.focus(ground_pos)


# ---------------------------------------------------------------- construção

## Liga/desliga o conserto dos prédios selecionados (tecla K ou botão no painel).
## O conserto é sempre pedido prédio a prédio; nada é consertado automaticamente.
func toggle_repair_selected() -> void:
	for e in selection:
		if not (e is Building) or e.team != Game.PLAYER:
			continue
		if e.repairing:
			e.set_repairing(false)
			hud.show_message("Conserto interrompido")
		elif not e.can_repair():
			hud.show_message("Este prédio não precisa de conserto")
		else:
			e.set_repairing(true)
			hud.show_message("Consertando %s: %d créditos para recuperar tudo" % [
					Game.item_name(e.type), e.repair_cost_total()])


func _on_place_requested(type: String) -> void:
	placing = type
	hud.show_message("Clique para posicionar (perto da sua base). Botão direito cancela.")


func placement_cell() -> Vector2i:
	var size: Vector2i = Game.BUILDINGS[placing]["size"]
	var m := ground_mouse() / Game.TILE
	return Vector2i(floori(m.x - size.x / 2.0 + 0.5), floori(m.y - size.y / 2.0 + 0.5))


func _try_place() -> void:
	if Game.place_building(placing, Game.PLAYER, placement_cell()):
		placing = ""
	else:
		hud.show_message("Local inválido: precisa ser terreno livre, perto da sua base")


## Fantasma do prédio que está sendo posicionado, verde ou vermelho conforme o local.
func _update_ghost() -> void:
	if placing != _ghost_type:
		if _ghost != null:
			_ghost.queue_free()
			_ghost = null
		_ghost_type = placing
		if placing != "":
			_ghost = Node3D.new()
			var m := Models.instantiate(placing + "_" + Game.factions[Game.PLAYER])
			m.name = "model"
			_ghost.add_child(m)
			var size: Vector2i = Game.BUILDINGS[placing]["size"]
			_ghost_area = MeshInstance3D.new()
			var plane := PlaneMesh.new()
			plane.size = Vector2(size)
			_ghost_area.mesh = plane
			_ghost_area.position.y = 0.03
			_ghost_area.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_ghost.add_child(_ghost_area)
			add_child(_ghost)
	if _ghost == null:
		return
	var size: Vector2i = Game.BUILDINGS[placing]["size"]
	var cell := placement_cell()
	var ok := Game.can_place(placing, Game.PLAYER, cell)
	_ghost.position = Game.to3d((Vector2(cell) + Vector2(size) / 2.0) * Game.TILE)
	var col := Color(0.3, 0.85, 1.0) if ok else Color(1.0, 0.25, 0.15)
	Models.set_ghost(_ghost.get_node("model"), Color(col, 0.6))
	_ghost_area.material_override = Fx3D.flat_material(Color(col, 0.25))
