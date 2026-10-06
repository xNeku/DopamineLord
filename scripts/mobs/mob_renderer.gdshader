shader_type canvas_item;
// Dibuja todos los mobs de una MultiMesh. Datos por mob (INSTANCE_CUSTOM):
//   x = tipo, y = vida (0..1) o, si el mob está muriendo, -(progreso 0..1), z = destello (0..1) + 2 si
//   está avisando de un golpe, w = altura del salto.
// Cada parte de la malla lleva su número en COLOR.r * 8 (ver mob_renderer.gd).

uniform vec4 kind_color[16];
uniform float kind_radius[16];
uniform float kind_style[16]; // 0 cuerpo a cuerpo, 1 a distancia, 2 saltador

varying flat float v_part;
varying flat vec4 v_data;

void vertex() {
	int part = int(COLOR.r * 8.0 + 0.5);
	int kind = int(INSTANCE_CUSTOM.x + 0.5);
	float u = kind_radius[kind];
	float style = kind_style[kind];
	float health = INSTANCE_CUSTOM.y;
	float lift = INSTANCE_CUSTOM.w;
	bool ghost = health < 0.0;
	// Al morir se encoge hacia el suelo.
	float shrink = ghost ? 1.0 - 0.45 * clamp(-health, 0.0, 1.0) : 1.0;
	float bar_width = max(18.0, u * 1.4 * 1.8);
	float bar_y = -u * 1.4 * 2.0 - 8.0 - lift;
	v_part = float(part);
	v_data = INSTANCE_CUSTOM;
	if (part == 0) {
		VERTEX = VERTEX * u * (1.0 - lift / 200.0) * shrink;
	} else if (part == 1) {
		VERTEX = VERTEX * u * shrink + vec2(0.0, -lift);
	} else if (part == 2) {
		VERTEX = style > 0.5 && style < 1.5 ? VERTEX * u * shrink + vec2(0.0, -lift) : vec2(0.0);
	} else if (part == 3) {
		VERTEX = style > 1.5 ? VERTEX * u * shrink + vec2(0.0, -lift) : vec2(0.0);
	} else if (ghost) {
		VERTEX = vec2(0.0);
	} else if (part == 4) {
		VERTEX = vec2((UV.x - 0.5) * bar_width, bar_y + UV.y * 3.0);
	} else {
		VERTEX = vec2(-bar_width * 0.5 + UV.x * bar_width * health, bar_y + UV.y * 3.0);
	}
}

void fragment() {
	int part = int(v_part + 0.5);
	int kind = int(v_data.x + 0.5);
	bool windup = v_data.z > 1.5;
	bool ghost = v_data.y < 0.0;
	float flash = windup ? v_data.z - 2.0 : v_data.z;
	if (ghost) {
		flash = 0.85;
		windup = false;
	}
	float fade = ghost ? 1.0 - clamp(-v_data.y, 0.0, 1.0) : 1.0;
	if (part == 0) {
		COLOR = vec4(0.0, 0.0, 0.0, 0.3);
	} else if (part == 1) {
		vec3 body = mix(kind_color[kind].rgb, vec3(1.0), flash);
		if (windup) {
			body = mix(body, vec3(1.0, 0.9, 0.2), 0.5 + 0.5 * sin(TIME * 30.0));
		}
		COLOR = vec4(body, 1.0);
	} else if (part == 2) {
		COLOR = vec4(0.1, 0.25, 0.1, 1.0);
	} else if (part == 3) {
		COLOR = vec4(0.35, 0.1, 0.05, 1.0);
	} else if (part == 4) {
		COLOR = vec4(0.0, 0.0, 0.0, 0.6);
	} else {
		COLOR = vec4(0.8, 0.2, 0.2, 1.0);
	}
	COLOR.a *= fade;
}
