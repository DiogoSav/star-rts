class_name Tracers
extends MeshInstance3D
## Raios das armas rápidas (fuzis, blasters, pulso, ácido): uma faixa brilhante, virada
## para a câmera, da boca da arma até o alvo. Projéteis pesados ficam com Projectile.

var _mesh := ImmediateMesh.new()


func _ready() -> void:
	mesh = _mesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(1.8, 1.8, 1.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = mat


func _process(_delta: float) -> void:
	_mesh.clear_surfaces()
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var started := false
	for e in Game.entities:
		if e.shot_timer <= 0.0 or e.weapon.is_empty() or not e.visible:
			continue
		var wtype := String(e.weapon["type"])
		if wtype in Game.PROJECTILE_WEAPONS:
			continue
		if not started:
			_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
			started = true
		var a: Vector3 = e.muzzle_point()
		var b: Vector3 = e.shot_to
		var col: Color = e.shot_color()
		var f: float = clampf(e.shot_timer / 0.09, 0.0, 1.0)
		# núcleo branco fino + halo colorido mais largo
		for layer in [[0.05 if wtype == "sniper" else 0.035, Color(col, 0.35 * f)], [0.012, Color(1, 1, 1, f)]]:
			var w: float = layer[0]
			var c: Color = layer[1]
			var side := (b - a).cross(cam.global_position - a).normalized() * w
			for p in [a - side, a + side, b + side, a - side, b + side, b - side]:
				_mesh.surface_set_color(c)
				_mesh.surface_add_vertex(p)
	if started:
		_mesh.surface_end()
