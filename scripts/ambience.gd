class_name Ambience
extends CanvasLayer
## Clima de ficção científica: vinheta, gradação fria nas sombras e quente nas luzes,
## granulação leve e poeira cintilante flutuando. Fica entre o mundo e a interface.

const SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float vignette = 0.38;
uniform float grain = 0.018;
uniform float aberration = 0.0012;

void fragment() {
	vec2 d = (SCREEN_UV - 0.5);
	float r = texture(screen_tex, SCREEN_UV + d * aberration * 2.0).r;
	float g = texture(screen_tex, SCREEN_UV).g;
	float b = texture(screen_tex, SCREEN_UV - d * aberration * 2.0).b;
	vec3 c = vec3(r, g, b);
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	// sombras azuladas, luzes levemente quentes
	c += mix(vec3(0.0, 0.012, 0.03), vec3(0.02, 0.01, -0.01), smoothstep(0.2, 0.8, l));
	float v = 1.0 - smoothstep(0.35, 0.95, length(d * vec2(1.2, 1.0)));
	c *= mix(1.0 - vignette, 1.0, v);
	float n = fract(sin(dot(UV * 1000.0 + fract(TIME * 7.3), vec2(12.9898, 78.233))) * 43758.5453);
	c += (n - 0.5) * grain;
	COLOR = vec4(c, 1.0);
}
"""


func _ready() -> void:
	layer = 1
	var post := ColorRect.new()
	post.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER
	mat.shader = sh
	post.material = mat
	add_child(post)

	var size := Vector2(1920, 1080)
	# Poeira do planeta: partículas finas e cintilantes, à deriva
	var dust := CPUParticles2D.new()
	dust.amount = 60
	dust.lifetime = 18.0
	dust.preprocess = 18.0
	dust.position = Vector2(-20, size.y * 0.5)
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(10, size.y * 0.6)
	dust.direction = Vector2(1, -0.15)
	dust.spread = 12.0
	dust.gravity = Vector2.ZERO
	dust.initial_velocity_min = 40.0
	dust.initial_velocity_max = 110.0
	dust.scale_amount_min = 1.0
	dust.scale_amount_max = 2.2
	var g := Gradient.new()
	g.set_color(0, Color(0.6, 0.8, 1.0, 0.0))
	g.add_point(0.2, Color(0.7, 0.85, 1.0, 0.35))
	g.add_point(0.8, Color(0.8, 0.7, 1.0, 0.3))
	g.set_color(g.get_point_count() - 1, Color(0.8, 0.7, 1.0, 0.0))
	dust.color_ramp = g
	add_child(dust)


static func toggle_fullscreen() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
