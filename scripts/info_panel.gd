class_name InfoPanel
extends PanelContainer
## Painel no canto inferior esquerdo com os detalhes da seleção: uma unidade ou prédio
## (ícone, vida, blindagem, arma, estado, produção) ou um resumo de várias unidades.

const ARMOR_NAMES := {"light": "leve", "medium": "média", "heavy": "pesada", "building": "prédio"}
const WEAPON_NAMES := {"rifle": "rajada leve", "smg": "curto alcance", "mg": "pulso rápido",
		"sniper": "precisão", "at": "antiblindagem", "cannon": "plasma pesado", "missile": "mísseis"}
const HARVEST_STATES := {"seek": "Procurando cristais", "to_ore": "Indo até os cristais",
		"harvest": "Extraindo cristais", "return": "Voltando à refinaria",
		"to_refinery": "Voltando à refinaria", "unload": "Descarregando", "manual": "Movendo"}

var selection: Array = []
var _single: HBoxContainer
var _icon: TextureRect
var _name: Label
var _sub: Label
var _hp_back: ColorRect
var _hp_fill: ColorRect
var _hp_text: Label
var _stats: Label
var _multi: VBoxContainer
var _multi_title: Label
var _grid: GridContainer


func _ready() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = HUD.PANEL
	sb.border_color = HUD.BORDER
	sb.set_border_width_all(2)
	sb.set_content_margin_all(10)
	add_theme_stylebox_override("panel", sb)
	custom_minimum_size = Vector2(600, 150)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_single = HBoxContainer.new()
	_single.add_theme_constant_override("separation", 14)
	add_child(_single)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(160, 120)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_single.add_child(_icon)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 3)
	_single.add_child(col)
	_name = Label.new()
	_name.add_theme_font_size_override("font_size", 21)
	_name.add_theme_color_override("font_color", HUD.ACCENT)
	col.add_child(_name)
	_sub = Label.new()
	_sub.add_theme_font_size_override("font_size", 13)
	_sub.add_theme_color_override("font_color", Color(0.55, 0.65, 0.75))
	col.add_child(_sub)
	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 8)
	col.add_child(hp_row)
	_hp_back = ColorRect.new()
	_hp_back.color = Color(0, 0, 0, 0.85)
	_hp_back.custom_minimum_size = Vector2(220, 10)
	_hp_back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hp_row.add_child(_hp_back)
	_hp_fill = ColorRect.new()
	_hp_back.add_child(_hp_fill)
	_hp_text = Label.new()
	_hp_text.add_theme_font_size_override("font_size", 14)
	hp_row.add_child(_hp_text)
	_stats = Label.new()
	_stats.add_theme_font_size_override("font_size", 14)
	col.add_child(_stats)

	_multi = VBoxContainer.new()
	add_child(_multi)
	_multi_title = Label.new()
	_multi_title.add_theme_font_size_override("font_size", 19)
	_multi_title.add_theme_color_override("font_color", HUD.ACCENT)
	_multi.add_child(_multi_title)
	_grid = GridContainer.new()
	_grid.columns = 5
	_grid.add_theme_constant_override("h_separation", 10)
	_multi.add_child(_grid)
	visible = false


func set_selection(list: Array) -> void:
	selection = list
	visible = not list.is_empty()
	_single.visible = list.size() == 1
	_multi.visible = list.size() > 1
	if list.size() == 1:
		var e = list[0]
		_icon.texture = Game.icon(e.model_name)
		_name.text = Game.item_name(e.type, e.team)
		var fac := Game.faction(e.team)
		var kind := "Prédio" if e is Building else ("Infantaria" if e.is_infantry else ("Nave" if e.flying else "Veículo"))
		_sub.text = "%s  ·  %s" % [kind, fac["army"]]
	elif list.size() > 1:
		_build_groups()


func _build_groups() -> void:
	for c in _grid.get_children():
		c.queue_free()
	var counts := {}
	var order: Array = []
	for e in selection:
		if not counts.has(e.model_name):
			counts[e.model_name] = 0
			order.append(e.model_name)
		counts[e.model_name] += 1
	_multi_title.text = "%d unidades selecionadas" % selection.size()
	for m in order:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 0)
		var pic := TextureRect.new()
		pic.texture = Game.icon(m)
		pic.custom_minimum_size = Vector2(96, 72)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		cell.add_child(pic)
		var l := Label.new()
		var data := Game.item_data(m) if Game.UNITS.has(m) else {}
		l.text = "%s ×%d" % [data.get("short", m), counts[m]]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 13)
		cell.add_child(l)
		_grid.add_child(cell)


func _process(_delta: float) -> void:
	if selection.size() != 1 or not is_instance_valid(selection[0]):
		return
	var e = selection[0]
	var f := clampf(e.hp / e.max_hp, 0.0, 1.0)
	_hp_fill.size = Vector2(_hp_back.custom_minimum_size.x * f, _hp_back.custom_minimum_size.y)
	_hp_fill.color = Color(0.9, 0.2, 0.15) if f <= 0.25 else (Color(0.95, 0.7, 0.2) if f <= 0.5 else Color(0.45, 0.8, 0.3))
	_hp_text.text = "Vida %d / %d" % [ceili(e.hp), int(e.max_hp)]
	_stats.text = _building_stats(e) if e is Building else _unit_stats(e)


func _weapon_line(w: Dictionary) -> String:
	if w.is_empty():
		return "Desarmado"
	var targets := "solo e ar" if w.get("air", false) and w.get("ground", true) else ("só ar" if w.get("air", false) else "só solo")
	return "Arma: %s  ·  dano %d  ·  alcance %.1f  ·  %.1f tiros/s  ·  %s" % [
			WEAPON_NAMES.get(w["type"], w["type"]), w["damage"], float(w["range"]) / Game.TILE,
			1.0 / float(w["cooldown"]), targets]


func _unit_stats(u: Unit) -> String:
	var lines: Array = []
	lines.append("Blindagem %s  ·  velocidade %.1f  ·  visão %d" % [
			ARMOR_NAMES.get(u.armor, u.armor), u.speed / Game.TILE, u.sight])
	lines.append(_weapon_line(u.weapon))
	var state := "Parado"
	if u is Harvester:
		state = "%s  ·  carga %d / %d" % [HARVEST_STATES.get(u.state, ""), int(u.cargo), int(Harvester.CAPACITY)]
	elif u.has_target and u.valid_target(u.target):
		state = "Em combate"
	elif not u.is_idle():
		state = "Andando atacando" if u.attack_move else "Movendo"
	lines.append("Estado: " + state)
	return "\n".join(lines)


func _building_stats(b: Building) -> String:
	var lines: Array = []
	if not b.built:
		lines.append("Em construção: %d%%" % int(b.build_t * 100.0))
	var p: int = b.data["power"]
	var power := ("Gera %d de energia" % p) if p > 0 else ("Consome %d de energia" % -p)
	if p < 0 and Game.low_power(b.team):
		power += "  ·  SEM ENERGIA SUFICIENTE"
	lines.append(power)
	if not b.weapon.is_empty():
		lines.append(_weapon_line(b.weapon))
	var cat: String = b.data["produces"]
	if cat != "":
		var job: Dictionary = Game.production[b.team].get(cat, {})
		var line := "Produz %s" % Game.CATEGORY_NAMES[cat]
		if not job.is_empty():
			var item: String = Game.item_name(job["type"], b.team)
			line += "  ·  %s: %s" % [item, "pronto" if job["done"] else "%d%%" % int(job["progress"] * 100.0)]
		lines.append(line)
	elif b.type == "refinery":
		lines.append("Recebe os cristais dos coletores e gera créditos")
	return "\n".join(lines)
