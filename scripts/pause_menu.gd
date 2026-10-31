class_name PauseMenu
extends CanvasLayer
## Menu de pausa: congela a partida e oferece continuar, reiniciar, voltar ao menu ou sair.
## Abre com Esc (quando não há nada para cancelar), P ou o botão MENU da barra lateral.

var _root: Control


func _ready() -> void:
	layer = 3
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = HUD.PANEL
	sb.border_color = HUD.BORDER
	sb.set_border_width_all(2)
	sb.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(380, 0)
	_root.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var title := Label.new()
	title.text = "PAUSADO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", HUD.ACCENT)
	box.add_child(title)
	_button(box, "CONTINUAR", close)
	if not Net.active:   # no multiplayer não dá para reiniciar a partida dos dois
		_button(box, "REINICIAR PARTIDA", func():
			get_tree().paused = false
			get_tree().reload_current_scene())
	_button(box, "SAIR PARA O MENU" if Net.active else "MENU PRINCIPAL", func():
		get_tree().paused = false
		Net.leave()
		get_tree().change_scene_to_file("res://scenes/menu.tscn"))
	if not OS.has_feature("web"):
		_button(box, "SAIR DO JOGO", func(): get_tree().quit())
	visible = false


func _button(box: VBoxContainer, text: String, action: Callable) -> void:
	var b := MainMenu.make_button(text)
	b.pressed.connect(action)
	box.add_child(b)


func open() -> void:
	if Game.game_over or Net.waiting:
		return
	visible = true
	get_tree().paused = not Net.active   # no multiplayer o jogo continua rodando


func close() -> void:
	visible = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_P:
			close()
			get_viewport().set_input_as_handled()
