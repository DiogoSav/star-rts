class_name Minimap
extends Control
## Radar: terreno, névoa, unidades (inimigos só quando visíveis) e a área da câmera.
## Clique ou arraste para mover a câmera.

signal clicked(ground_pos: Vector2)

const C_MUD := Color(0.2, 0.15, 0.14)
const C_RUBBLE := Color(0.08, 0.07, 0.08)
const C_SCRAP := Color(0.6, 0.3, 0.95)

var _img: Image
var _tex: ImageTexture
var _timer := 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP
	_img = Image.create_empty(Map.W, Map.H, false, Image.FORMAT_RGBA8)
	_tex = ImageTexture.create_from_image(_img)


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0 and Game.map != null and Game.fog != null:
		_timer = 0.5
		var m := Game.map
		var f := Game.fog
		for y in Map.H:
			for x in Map.W:
				var i := y * Map.W + x
				var c := C_MUD
				if m.tiles[i] == Map.ROCK:
					c = C_RUBBLE
				elif m.tiles[i] == Map.ORE:
					c = C_SCRAP
				if f.explored[i] == 0:
					c = Color(0.02, 0.02, 0.02)
				elif f.visible_cells[i] == 0:
					c = c.darkened(0.45)
				_img.set_pixel(x, y, c)
		_tex.update(_img)
	queue_redraw()


func _cell_size() -> Vector2:
	return size / Vector2(Map.W, Map.H)


func _draw() -> void:
	draw_texture_rect(_tex, Rect2(Vector2.ZERO, size), false)
	var k := _cell_size() / Game.TILE
	for e in Game.entities:
		if e.team != Game.PLAYER and not e.visible:
			continue
		var col: Color = Game.team_color(e.team).lightened(0.15)
		if e is Unit and e.flying:
			var q: Vector2 = e.position * k
			draw_colored_polygon(PackedVector2Array([q + Vector2(0, -3), q + Vector2(3, 2), q + Vector2(-3, 2)]), col)
		elif e is Building:
			draw_rect(Rect2(Vector2(e.cell) * _cell_size(), Vector2(e.size) * _cell_size()), col)
		else:
			draw_rect(Rect2(e.position * k - Vector2(1.5, 1.5), Vector2(3, 3)), col)
	# Área vista pela câmera: os cantos da parte livre da tela projetados no chão
	var cam := get_viewport().get_camera_3d() as RTSCamera
	if cam != null:
		var vs := get_viewport().get_visible_rect().size
		var corners := [Vector2(0, 0), Vector2(vs.x - HUD.SIDEBAR_W, 0),
				Vector2(vs.x - HUD.SIDEBAR_W, vs.y), Vector2(0, vs.y)]
		var pts := PackedVector2Array()
		for c in corners:
			var g = cam.ground_at(c)
			if g == null:
				pts.clear()
				break
			var q: Vector2 = Game.to_ground(g) * k
			pts.append(q.clamp(Vector2.ZERO, size))
		if pts.size() == 4:
			pts.append(pts[0])
			draw_polyline(pts, HUD.ACCENT, 1.0)
	draw_rect(Rect2(Vector2.ZERO, size), HUD.BORDER, false, 1.0)


func _gui_input(event: InputEvent) -> void:
	var press: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	var drag: bool = event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
	if press or drag:
		clicked.emit(event.position / _cell_size() * Game.TILE)
		accept_event()
