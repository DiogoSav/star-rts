class_name HUD
extends CanvasLayer
## Barra lateral de comando: minimapa, suprimentos, energia e botões de produção com ícones.

signal place_requested(type: String)
signal minimap_clicked(ground_pos: Vector2)
signal pause_requested

const SIDEBAR_W := 340
const ACCENT := Color(0.45, 0.85, 1.0)
const TEXT := Color(0.8, 0.88, 0.95)
const BORDER := Color(0.16, 0.34, 0.48)
const PANEL := Color(0.03, 0.05, 0.08, 0.93)

var credits_label: Label
var power_label: Label
var msg_label: Label
var end_label: Label
var minimap: Minimap
var info: InfoPanel
var buttons := {}
var bars := {}
var _msg_timer := 0.0


func _ready() -> void:
	layer = 2
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _make_theme()
	add_child(root)

	var panel := PanelContainer.new()
	root.add_child(panel)
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -SIDEBAR_W
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL
	style.border_color = BORDER
	style.border_width_left = 3
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	margin.add_theme_constant_override("margin_top", 8)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)

	var fac := Game.faction(Game.PLAYER)
	var title := Label.new()
	title.text = "STAR-RTS"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top := HBoxContainer.new()
	box.add_child(top)
	top.add_child(title)
	var menu_b := Button.new()
	menu_b.text = "MENU"
	menu_b.tooltip_text = "Pausa (Esc ou P)"
	menu_b.focus_mode = Control.FOCUS_NONE
	menu_b.add_theme_font_size_override("font_size", 13)
	menu_b.pressed.connect(func(): pause_requested.emit())
	top.add_child(menu_b)
	var side_label := Label.new()
	side_label.text = "%s — %s" % [fac["army"], fac["name"]]
	side_label.add_theme_font_size_override("font_size", 14)
	side_label.add_theme_color_override("font_color", fac["color"])
	box.add_child(side_label)

	minimap = Minimap.new()
	minimap.custom_minimum_size = Vector2(SIDEBAR_W - 24, (SIDEBAR_W - 24) * Map.H / float(Map.W))
	minimap.clicked.connect(func(p): minimap_clicked.emit(p))
	box.add_child(minimap)

	var row := HBoxContainer.new()
	box.add_child(row)
	credits_label = Label.new()
	credits_label.add_theme_font_size_override("font_size", 20)
	credits_label.add_theme_color_override("font_color", ACCENT)
	credits_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(credits_label)
	power_label = Label.new()
	power_label.add_theme_font_size_override("font_size", 15)
	row.add_child(power_label)

	_section(box, "CONSTRUÇÕES", Game.BUILD_ORDER)
	_section(box, "INFANTARIA", fac["infantry"])
	_section(box, "VEÍCULOS", fac["vehicles"])
	_section(box, "NAVES", fac["air"])

	var help := Label.new()
	help.text = "Arrastar: selecionar   ·   Botão dir.: mover / atacar   ·   Ctrl + dir.: andar atacando   ·   WASD: câmera   ·   Esc: cancelar / pausar   ·   P: pausa   ·   K: consertar prédio selecionado   ·   F11: tela cheia"
	help.add_theme_font_size_override("font_size", 13)
	help.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7, 0.8))
	help.position = Vector2(16, 1080 - 30)
	root.add_child(help)

	info = InfoPanel.new()
	root.add_child(info)
	info.anchor_top = 1.0
	info.anchor_bottom = 1.0
	info.offset_left = 12
	info.offset_bottom = -36
	info.grow_vertical = Control.GROW_DIRECTION_BEGIN

	msg_label = Label.new()
	msg_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	msg_label.position = Vector2(20, 18)
	msg_label.add_theme_font_size_override("font_size", 22)
	msg_label.add_theme_color_override("font_color", Color(0.8, 0.95, 1.0))
	msg_label.add_theme_color_override("font_outline_color", Color.BLACK)
	msg_label.add_theme_constant_override("outline_size", 6)
	root.add_child(msg_label)

	end_label = Label.new()
	end_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	end_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	end_label.offset_right = -SIDEBAR_W
	end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	end_label.add_theme_font_size_override("font_size", 64)
	end_label.add_theme_color_override("font_outline_color", Color.BLACK)
	end_label.add_theme_constant_override("outline_size", 12)
	root.add_child(end_label)

	Game.message.connect(show_message)
	Game.game_ended.connect(_on_game_ended)


func _make_theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = 14
	var states := {
		"normal": [Color(0.05, 0.09, 0.13), BORDER],
		"hover": [Color(0.07, 0.14, 0.2), ACCENT.darkened(0.2)],
		"pressed": [Color(0.08, 0.2, 0.28), ACCENT],
		"disabled": [Color(0.03, 0.04, 0.06), Color(0.1, 0.13, 0.17)],
	}
	for s in states:
		var sb := StyleBoxFlat.new()
		sb.bg_color = states[s][0]
		sb.border_color = states[s][1]
		sb.set_border_width_all(1)
		sb.set_content_margin_all(4)
		th.set_stylebox(s, "Button", sb)
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_color("font_color", "Button", TEXT)
	th.set_color("font_hover_color", "Button", Color(0.85, 0.97, 1.0))
	th.set_color("font_pressed_color", "Button", Color(0.85, 0.97, 1.0))
	th.set_color("font_disabled_color", "Button", Color(0.3, 0.36, 0.42))
	th.set_color("font_color", "Label", TEXT)
	th.set_color("font_color", "TooltipLabel", TEXT)
	var tip := StyleBoxFlat.new()
	tip.bg_color = Color(0.03, 0.05, 0.08, 0.96)
	tip.border_color = BORDER
	tip.set_border_width_all(1)
	tip.set_content_margin_all(8)
	th.set_stylebox("panel", "TooltipPanel", tip)
	return th


func _section(box: VBoxContainer, title: String, list: Array) -> void:
	var l := Label.new()
	l.text = title
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", ACCENT.darkened(0.25))
	box.add_child(l)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)
	for t in list:
		var b := Button.new()
		b.custom_minimum_size = Vector2(155, 54)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.expand_icon = true
		b.icon = _item_icon(t)
		b.tooltip_text = _tooltip(t)
		b.add_theme_font_size_override("font_size", 13)
		b.pressed.connect(_on_item_pressed.bind(t))
		b.gui_input.connect(_on_item_gui_input.bind(t))
		grid.add_child(b)
		var bar := ColorRect.new()
		bar.color = ACCENT
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(bar)
		buttons[t] = b
		bars[t] = bar


func _item_icon(t: String) -> Texture2D:
	if Game.BUILDINGS.has(t):
		return Game.icon(t + "_" + Game.factions[Game.PLAYER])
	return Game.icon(t)


func _tooltip(t: String) -> String:
	var d := Game.item_data(t)
	var s := "%s\n%s\nCusto: %d   Tempo: %ds" % [Game.item_name(t), d["desc"], d["cost"], int(d["time"])]
	if d.has("hp"):
		s += "   Vida: %d" % d["hp"]
	var req: Array = d["requires"]
	if not req.is_empty():
		var names := req.map(func(r): return Game.item_name(r))
		s += "\nRequer: " + ", ".join(names)
	if Game.UNITS.has(t):
		s += "\nClique: produzir (fila de até %d)   ·   Botão direito: cancelar um" % Game.MAX_QUEUE
	return s


func _short_name(t: String) -> String:
	var d := Game.item_data(t)
	if d.has("short"):
		return d["short"]
	var n := Game.item_name(t)
	return n if n.length() <= 16 else n.get_slice(" ", 0)


func _on_item_pressed(t: String) -> void:
	var cat: String = Game.item_data(t)["category"]
	var job: Dictionary = Game.production[Game.PLAYER].get(cat, {})
	# Prédios: um por vez (depois de pronto, o clique posiciona). Unidades entram na fila.
	if cat == "building" and not job.is_empty():
		if job["done"] and job["type"] == t:
			place_requested.emit(t)
		elif job["type"] != t:
			show_message("Já existe uma construção em andamento")
		return
	Game.start_production(Game.PLAYER, t)


func _on_item_gui_input(event: InputEvent, t: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		var cat: String = Game.item_data(t)["category"]
		Game.cancel_production(Game.PLAYER, cat, t)


func show_message(text: String) -> void:
	msg_label.text = text
	_msg_timer = 4.0


func _on_game_ended(player_won: bool) -> void:
	end_label.text = ("VITÓRIA!" if player_won else "DERROTA") + "\n[R] jogar de novo    [M] menu"
	end_label.add_theme_color_override("font_color",
			Color(0.45, 0.9, 1.0) if player_won else Color(1.0, 0.3, 0.25))


func _process(delta: float) -> void:
	_msg_timer -= delta
	if _msg_timer <= 0.0:
		msg_label.text = ""

	credits_label.text = "Créditos  %d" % int(Game.credits[Game.PLAYER])
	var p := Game.get_power(Game.PLAYER)
	power_label.text = "Energia %d / %d" % [p.x, p.y]
	power_label.add_theme_color_override("font_color",
			Color(0.95, 0.35, 0.25) if p.y > p.x else Color(0.65, 0.85, 0.45))

	for t in buttons:
		var b: Button = buttons[t]
		var data := Game.item_data(t)
		var cat: String = data["category"]
		var job: Dictionary = Game.production[Game.PLAYER].get(cat, {})
		var mine: bool = not job.is_empty() and job["type"] == t
		# Um prédio já pronto continua posicionável mesmo se o produtor for destruído
		b.disabled = not Game.can_produce(Game.PLAYER, t) and not (mine and job["done"])
		var bar: ColorRect = bars[t]
		var n := Game.count_in_production(Game.PLAYER, t)
		var count := "  ×%d" % n if n > 1 else ""
		if mine:
			bar.visible = true
			bar.position = Vector2(2, b.size.y - 5)
			bar.size = Vector2((b.size.x - 4) * float(job["progress"]), 3)
			if job["done"]:
				b.text = "%s\nPRONTO!" % _short_name(t)
			else:
				b.text = "%s\n%d%%%s" % [_short_name(t), int(job["progress"] * 100.0), count]
		elif n > 0:
			bar.visible = false
			b.text = "%s\nna fila%s" % [_short_name(t), count if n > 1 else "  ×1"]
		else:
			bar.visible = false
			b.text = "%s\n%d" % [_short_name(t), data["cost"]]
