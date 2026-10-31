class_name Overlay
extends Control
## Desenha na tela, por cima do mundo 3D: barras de vida e de carga, aviso de falta de
## energia, caixa de seleção e marcadores de ordem (projetados no chão).

var main = null
var markers: Array = []   # [posição no chão, tempo restante, cor]
var _t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func add_marker(pos: Vector2, color: Color) -> void:
	markers.append([pos, 0.5, color])


func _process(delta: float) -> void:
	_t += delta
	for m in markers:
		m[1] -= delta
	markers = markers.filter(func(m): return m[1] > 0.0)
	queue_redraw()


func _draw() -> void:
	if main == null or main.cam == null:
		return
	var cam: Camera3D = main.cam
	var k := clampf(17.0 / main.cam.dist, 0.6, 1.8)   # barras acompanham o zoom

	for e in Game.entities:
		if not e.visible or e.dead:
			continue
		var top: Vector3 = e.top3d()
		if cam.is_position_behind(top):
			continue
		var p := cam.unproject_position(top)
		var w := 0.0
		if e is Building:
			w = e.size.x * 24.0 * k
			if Game.low_power(e.team) and int(e.data["power"]) < 0:
				var blink := int(_t * 2.0) % 2 == 0
				draw_circle(p + Vector2(w / 2.0 + 8.0, 2.0), 4.0 * k,
						Color(1, 0.2, 0.15) if blink else Color(0.4, 0.08, 0.05))
		else:
			w = (16.0 if e.is_infantry else maxf(26.0, e.radius * 2.6)) * k
		if e is Building and not e.built:
			p = cam.unproject_position(Game.to3d(e.position, 0.6))
			_bar(p, w, e.build_t, HUD.ACCENT)
			continue
		if e.selected or e.hp < e.max_hp:
			_bar(p, w, clampf(e.hp / e.max_hp, 0.0, 1.0), _hp_color(e.hp / e.max_hp))
		if e is Harvester and e.cargo > 0.0:
			_bar(p + Vector2(0, 5), w, e.cargo / Harvester.CAPACITY, Color(0.65, 0.35, 1.0))

	if main.dragging:
		var rect := Rect2(main.drag_start, get_local_mouse_position() - main.drag_start).abs()
		draw_rect(rect, Color(0.45, 0.85, 1.0, 0.08))
		draw_rect(rect, HUD.ACCENT, false, 1.0)

	for m in markers:
		var f: float = m[1] / 0.5
		var c: Color = m[2]
		c.a = f
		var r := (4.0 + 10.0 * (1.0 - f))
		var pts := PackedVector2Array()
		for i in 21:
			var a := TAU * i / 20.0
			var g: Vector2 = m[0] + Vector2(cos(a), sin(a)) * r
			pts.append(cam.unproject_position(Game.to3d(g, 0.03)))
		draw_polyline(pts, c, 2.0)


func _bar(p: Vector2, w: float, f: float, col: Color) -> void:
	draw_rect(Rect2(p.x - w / 2.0 - 1, p.y - 1, w + 2, 5), Color(0, 0, 0, 0.8))
	draw_rect(Rect2(p.x - w / 2.0, p.y, w * f, 3), col)


func _hp_color(f: float) -> Color:
	if f <= 0.25:
		return Color(0.9, 0.2, 0.15)
	if f <= 0.5:
		return Color(0.95, 0.7, 0.2)
	return Color(0.45, 0.8, 0.3)
