class_name RTSCamera
extends Camera3D
## Câmera de RTS em perspectiva, inclinada olhando para o norte.
## WASD/setas ou mouse nas bordas (só no PC) movem o ponto de foco; a roda aproxima e afasta.

const SPEED := 16.0          # células por segundo (na distância padrão)
const EDGE := 12.0
const PITCH := deg_to_rad(54.0)
const DIST_MIN := 8.0
const DIST_MAX := 34.0

var target := Vector3(8, 0, 38)  # ponto do chão no centro da área de jogo (mundo 3D)
var dist := 17.0
var _dist_goal := 17.0


func _ready() -> void:
	fov = 38.0
	near = 0.2
	far = 200.0
	_apply()


func _process(delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		dir.x -= 1
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		dir.x += 1
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		dir.y -= 1
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		dir.y += 1

	var vp := get_viewport()
	var mp := vp.get_mouse_position()
	var vs := vp.get_visible_rect().size
	# Na Web a câmera só anda pelo teclado (o mouse sai do canvas toda hora no navegador)
	var edge_scroll := not OS.has_feature("web")
	if edge_scroll and DisplayServer.window_is_focused() and Rect2(Vector2.ZERO, vs).has_point(mp):
		if mp.x < EDGE:
			dir.x -= 1
		elif mp.x > vs.x - EDGE:
			dir.x += 1
		if mp.y < EDGE:
			dir.y -= 1
		elif mp.y > vs.y - EDGE:
			dir.y += 1

	if dir != Vector2.ZERO:
		var d := dir.normalized() * SPEED * delta * (dist / 17.0)
		target += Vector3(d.x, 0, d.y)
	dist = lerpf(dist, _dist_goal, minf(1.0, delta * 10.0))
	clamp_to_map()
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_dist_goal = clampf(_dist_goal / 1.15, DIST_MIN, DIST_MAX)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_dist_goal = clampf(_dist_goal * 1.15, DIST_MIN, DIST_MAX)


## Centraliza a área de jogo num ponto do chão (pixels de chão).
func focus(ground: Vector2) -> void:
	target = Game.to3d(ground)
	clamp_to_map()
	_apply()


func clamp_to_map() -> void:
	target.x = clampf(target.x, 0.0, Map.W)
	target.z = clampf(target.z, 0.0, Map.H + 2.0)


func _apply() -> void:
	var offset := Vector3(0, sin(PITCH), cos(PITCH)) * dist
	position = target + offset
	basis = Basis.looking_at(-offset, Vector3.UP)
	# A barra lateral cobre a direita da tela: desloca a câmera para o foco ficar
	# no centro da parte livre.
	var vs := get_viewport().get_visible_rect().size
	var view_w := 2.0 * dist * tan(deg_to_rad(fov) / 2.0) * vs.x / vs.y
	h_offset = HUD.SIDEBAR_W / 2.0 / vs.x * view_w


## Ponto do chão (mundo 3D) sob uma posição da tela, ou null.
func ground_at(screen: Vector2):
	var from := project_ray_origin(screen)
	var dir := project_ray_normal(screen)
	if dir.y > -0.001:
		return null
	return from + dir * (-from.y / dir.y)
