class_name MainMenu
extends Control
## Menu inicial: fundo 3D (céu estrelado, planeta e naves passando), tela de título
## (Jogar / Sair) e a escolha da raça do jogador e do inimigo.

const ACCENT := Color(0.45, 0.85, 1.0)

const SKY_SHADER := """
shader_type sky;

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

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * vnoise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float n = fbm(d * 2.5 + vec3(TIME * 0.003, 0.0, 0.0));
	float n2 = fbm(d * 5.0 + vec3(3.1));
	vec3 neb = mix(vec3(0.20, 0.05, 0.30), vec3(0.02, 0.18, 0.32), n2);
	vec3 col = vec3(0.005, 0.008, 0.02) + neb * pow(smoothstep(0.35, 0.85, n), 2.0) * 0.9;
	vec3 q = d * 220.0;
	vec3 cell = floor(q);
	float h = hash(cell);
	float s = smoothstep(0.42, 0.0, length(fract(q) - 0.5)) * step(0.985, h);
	float tw = 0.6 + 0.4 * sin(TIME * (1.0 + h * 4.0) + h * 40.0);
	col += vec3(0.85, 0.9, 1.0) * s * tw * 2.5;
	vec3 q2 = d * 700.0;
	col += vec3(0.7, 0.75, 1.0) * step(0.993, hash(floor(q2))) * 0.6;
	COLOR = col;
}
"""

const PLANET_SHADER := """
shader_type spatial;
uniform sampler2D noise_tex : repeat_enable;
varying vec3 onrm;
void vertex() {
	onrm = NORMAL;
}
void fragment() {
	vec2 uv = vec2(atan(onrm.z, onrm.x) / 6.2831 + TIME * 0.002, acos(onrm.y) / 3.1416);
	float n = texture(noise_tex, uv * vec2(2.0, 1.0)).r;
	float n2 = texture(noise_tex, uv * vec2(8.0, 4.0)).r;
	vec3 a = vec3(0.32, 0.18, 0.16);
	vec3 b = vec3(0.12, 0.08, 0.16);
	vec3 c = mix(b, a, smoothstep(0.35, 0.7, n));
	c = mix(c, vec3(0.55, 0.42, 0.35), smoothstep(0.65, 0.85, n2) * 0.4);
	ALBEDO = c;
	ROUGHNESS = 0.9;
	// luzes de cidades no lado escuro
	EMISSION = vec3(0.4, 0.7, 1.0) * step(0.78, n2) * step(0.5, n) * 0.6;
}
"""

const ATMO_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_front, depth_draw_never;
uniform vec4 color : source_color = vec4(0.35, 0.6, 1.0, 1.0);
void fragment() {
	float rim = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.5);
	ALBEDO = color.rgb * rim * 2.5;
}
"""

var title_page: VBoxContainer
var faction_page: VBoxContainer
var _ships: Array = []
var _enemy_buttons := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_space()

	title_page = _page()
	_title(title_page, "Legião Solar  ×  Núcleo Sintético  ×  Enxame Kheth")
	var ships := HBoxContainer.new()
	ships.alignment = BoxContainer.ALIGNMENT_CENTER
	ships.add_theme_constant_override("separation", 30)
	title_page.add_child(ships)
	for id in ["hum_heavy", "rob_heavy", "ins_heavy"]:
		ships.add_child(_pic(Game.icon(id), Vector2(256, 192)))
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 14)
	buttons.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	buttons.custom_minimum_size = Vector2(360, 0)
	title_page.add_child(buttons)
	buttons.add_child(_menu_button("JOGAR", func(): _show_page(faction_page)))
	if not OS.has_feature("web"):   # no navegador o jogo não pode fechar a aba
		buttons.add_child(_menu_button("SAIR", func(): get_tree().quit()))

	faction_page = _page()
	_title(faction_page, "escolha a sua raça")
	faction_page.visible = false

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 26)
	faction_page.add_child(row)
	for f in Game.FACTIONS:
		row.add_child(_faction_card(f))

	var enemy_row := HBoxContainer.new()
	enemy_row.alignment = BoxContainer.ALIGNMENT_CENTER
	enemy_row.add_theme_constant_override("separation", 10)
	faction_page.add_child(enemy_row)
	var el := Label.new()
	el.text = "Inimigo:"
	el.add_theme_font_size_override("font_size", 20)
	el.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	enemy_row.add_child(el)
	for key in ["", "hum", "rob", "ins"]:
		var b := make_button("Aleatório" if key == "" else Game.FACTIONS[key]["army"])
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(210, 44)
		b.add_theme_font_size_override("font_size", 18)
		b.pressed.connect(_set_enemy.bind(key))
		enemy_row.add_child(b)
		_enemy_buttons[key] = b
	_set_enemy(Game.enemy_choice)

	var help := Label.new()
	help.text = "Arrastar: selecionar   ·   Botão direito: mover / atacar   ·   Ctrl + botão direito: andar atacando\nWASD / bordas: câmera   ·   Roda: zoom   ·   Clique no minimapa: ir para o local   ·   F11: tela cheia"
	if OS.has_feature("web"):
		help.text = help.text.replace("WASD / bordas: câmera", "WASD / setas: câmera")
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 16)
	help.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	faction_page.add_child(help)
	var back := _menu_button("VOLTAR", func(): _show_page(title_page))
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.custom_minimum_size = Vector2(240, 46)
	faction_page.add_child(back)

	add_child(Ambience.new())


# ---------------------------------------------------------------- fundo 3D

func _build_space() -> void:
	var svc := SubViewportContainer.new()
	svc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	svc.stretch = true
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(svc)
	var vp := SubViewport.new()
	vp.msaa_3d = Viewport.MSAA_4X
	svc.add_child(vp)

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SKY_SHADER
	sm.shader = sh
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.32, 0.45)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 1.0
	env.glow_bloom = 0.05
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)

	var cam := Camera3D.new()
	cam.fov = 50.0
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.5, 9), Vector3(0, 0.2, 0))

	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.92, 0.82)
	sun.light_energy = 1.6
	vp.add_child(sun)
	sun.look_at_from_position(Vector3.ZERO, Vector3(-1.0, -0.35, -0.5))

	# Planeta com atmosfera
	var planet := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 9.0
	sphere.height = 18.0
	sphere.radial_segments = 96
	sphere.rings = 48
	planet.mesh = sphere
	var pm := ShaderMaterial.new()
	var psh := Shader.new()
	psh.code = PLANET_SHADER
	pm.shader = psh
	var nz := FastNoiseLite.new()
	nz.frequency = 0.012
	nz.fractal_octaves = 6
	var nt := NoiseTexture2D.new()
	nt.width = 1024
	nt.height = 512
	nt.seamless = true
	nt.noise = nz
	pm.set_shader_parameter("noise_tex", nt)
	planet.material_override = pm
	planet.position = Vector3(4.5, -9.8, -6.0)
	vp.add_child(planet)
	var atmo := MeshInstance3D.new()
	var s2 := SphereMesh.new()
	s2.radius = 9.5
	s2.height = 19.0
	s2.radial_segments = 96
	s2.rings = 48
	atmo.mesh = s2
	var am := ShaderMaterial.new()
	var ash := Shader.new()
	ash.code = ATMO_SHADER
	am.shader = ash
	atmo.material_override = am
	atmo.position = planet.position
	vp.add_child(atmo)

	# Naves das três raças cruzando a cena
	var specs := [
		["hum_gunship", Vector3(-9, 1.6, -3.0), 0.55, 1.6],
		["hum_fighter", Vector3(-6, 2.3, -2.0), 1.6, 1.4],
		["hum_fighter", Vector3(-6.8, 2.0, -1.4), 1.6, 1.4],
		["rob_gunship", Vector3(-14, 0.4, -5.0), 0.4, 1.8],
		["rob_fighter", Vector3(-3, 3.0, -4.0), 1.2, 1.4],
		["ins_gunship", Vector3(-20, 2.4, -7.0), 0.5, 2.2],
		["ins_fighter", Vector3(-11, 1.0, 0.5), 1.9, 1.2],
		["ins_fighter", Vector3(-12, 1.3, 1.0), 1.9, 1.2],
	]
	for s in specs:
		var m := Models.instantiate(s[0])
		m.scale = Vector3.ONE * float(s[3])
		m.position = s[1]
		m.rotation.y = -0.18
		vp.add_child(m)
		var key: String = String(s[0]).get_slice("_", 0)
		Models.set_team(m, Game.FACTIONS[key]["color"])
		for loc in Models.locators_named(m, "engine"):
			var tr := Fx3D.engine_trail(Game.FACTIONS[key]["shot"])
			tr.amount = 40
			tr.lifetime = 0.8
			loc.add_child(tr)
		_ships.append([m, float(s[2]), randf() * 10.0, s[1].y])


func _process(delta: float) -> void:
	for s in _ships:
		var m: Node3D = s[0]
		s[2] += delta
		m.position += Vector3(cos(m.rotation.y), 0, sin(m.rotation.y)) * s[1] * delta
		m.position.y = s[3] + sin(s[2] * 0.8) * 0.15
		m.rotation.x = sin(s[2] * 0.6) * 0.08
		if m.position.x > 14.0:
			m.position.x = -16.0
			m.position.z -= 0.0
		for wing in m.find_children("wing_*", "Node3D", true, false):
			wing.rotation.x = sin(s[2] * 30.0) * 0.4 * (1 if wing.name == "wing_l" else -1)
		for sp in m.find_children("spin", "Node3D", true, false):
			sp.rotation.y += delta


# ---------------------------------------------------------------- páginas

func _page() -> VBoxContainer:
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 18)
	add_child(col)
	return col


func _title(page: VBoxContainer, subtitle: String) -> void:
	var title := Label.new()
	title.text = "STAR-RTS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 96)
	title.add_theme_color_override("font_color", Color(0.8, 0.95, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0.05, 0.25, 0.45))
	title.add_theme_constant_override("outline_size", 16)
	title.add_theme_color_override("font_shadow_color", Color(0.3, 0.7, 1.0, 0.5))
	title.add_theme_constant_override("shadow_outline_size", 30)
	page.add_child(title)
	var sub := Label.new()
	sub.text = subtitle
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 24)
	sub.add_theme_color_override("font_color", Color(0.65, 0.78, 0.9))
	page.add_child(sub)


func _show_page(page: Control) -> void:
	title_page.visible = page == title_page
	faction_page.visible = page == faction_page


func _set_enemy(key: String) -> void:
	Game.enemy_choice = key
	for k in _enemy_buttons:
		_enemy_buttons[k].button_pressed = k == key


## Botão grande no estilo do menu (também usado pelo menu de pausa).
static func make_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 54)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 24)
	for s in ["normal", "hover", "pressed"]:
		var bs := StyleBoxFlat.new()
		bs.bg_color = {"normal": Color(0.03, 0.06, 0.1, 0.85), "hover": Color(0.06, 0.13, 0.2, 0.9),
				"pressed": Color(0.08, 0.22, 0.32, 0.95)}[s]
		bs.border_color = ACCENT.darkened(0.55 if s == "normal" else 0.1)
		bs.set_border_width_all(2)
		bs.set_corner_radius_all(3)
		b.add_theme_stylebox_override(s, bs)
	b.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	b.add_theme_color_override("font_hover_color", Color(0.9, 1.0, 1.0))
	b.add_theme_color_override("font_pressed_color", Color(0.9, 1.0, 1.0))
	return b


func _menu_button(text: String, action: Callable) -> Button:
	var b := make_button(text)
	b.pressed.connect(action)
	return b


func _faction_card(f: String) -> Control:
	var fac: Dictionary = Game.FACTIONS[f]
	var col: Color = fac["color"]
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.04, 0.07, 0.82)
	sb.border_color = col.darkened(0.3)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", sb)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var name_l := Label.new()
	name_l.text = String(fac["army"]).to_upper()
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.add_theme_font_size_override("font_size", 32)
	name_l.add_theme_color_override("font_color", col)
	box.add_child(name_l)
	var race := Label.new()
	race.text = fac["name"]
	race.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	race.add_theme_color_override("font_color", Color(0.65, 0.72, 0.8))
	box.add_child(race)

	# Desfile da tropa: soldados, veículos e naves da raça
	for list in [fac["infantry"], fac["vehicles"], fac["air"]]:
		var r := HBoxContainer.new()
		r.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_child(r)
		for id in list:
			var big: bool = list == fac["air"]
			r.add_child(_pic(Game.icon(id), Vector2(150, 100) if big else Vector2(110, 82)))

	var desc := Label.new()
	desc.text = fac["desc"]
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_color_override("font_color", Color(0.7, 0.78, 0.86))
	box.add_child(desc)

	var b := Button.new()
	b.text = "COMANDAR"
	b.custom_minimum_size = Vector2(0, 54)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 24)
	for s in ["normal", "hover", "pressed"]:
		var bs := StyleBoxFlat.new()
		bs.bg_color = col.darkened(0.82 if s == "normal" else (0.65 if s == "hover" else 0.5))
		bs.border_color = col.darkened(0.15)
		bs.set_border_width_all(2)
		bs.set_corner_radius_all(3)
		b.add_theme_stylebox_override(s, bs)
	b.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
	b.pressed.connect(_start.bind(f))
	box.add_child(b)
	return panel


func _pic(tex: Texture2D, pic_size: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = pic_size
	return r


func _start(f: String) -> void:
	Game.player_faction = f
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F11:
		Ambience.toggle_fullscreen()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_show_page(title_page)
