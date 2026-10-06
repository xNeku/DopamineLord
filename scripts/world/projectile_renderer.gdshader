shader_type canvas_item;
// Dibuja los proyectiles de los jugadores con una MultiMesh. Datos por proyectil (INSTANCE_CUSTOM):
//   x = tipo (color y forma van en los uniformes), y = radio,
//   z, w = dirección en pantalla (flechas) o, en la bola de nieve, z = giro.
// El número de cada parte de la malla va en UV.x (ver projectile_manager.gd).
// `layer`: 0 pinta solo las sombras, 1 solo los cuerpos (así las sombras quedan debajo de todo).

uniform vec4 kind_color[32];
uniform float kind_shape[32]; // 0 bola, 1 flecha, 2 bola de nieve
uniform int layer = 0;

varying flat float v_part;
varying flat float v_kind;

vec2 rotate_by(vec2 p, vec2 along) {
	return vec2(p.x * along.x - p.y * along.y, p.x * along.y + p.y * along.x);
}

void vertex() {
	int part = int(UV.x + 0.5);
	int kind = int(INSTANCE_CUSTOM.x + 0.5);
	float r = INSTANCE_CUSTOM.y;
	float shape = kind_shape[kind];
	vec2 up = vec2(0.0, -12.0);
	vec2 v = VERTEX;
	vec2 result = vec2(0.0); // por defecto la parte se esconde (todos los vértices en el mismo punto)
	if (part == 0) {
		if (layer == 0) {
			result = v * r * 0.8;
		}
	} else if (layer == 1) {
		if (part == 1) {
			if (shape < 0.5) result = up + v * r;
		} else if (part == 2) {
			if (shape != 1.0) result = up + v * r;
		} else if (part == 3) {
			if (shape < 0.5) result = up + v * r;
		} else if (part == 4) {
			if (shape > 0.5 && shape < 1.5) {
				vec2 p = vec2(v.x * r, v.y * max(2.0, r * 0.6) * 0.5);
				result = up + rotate_by(p, INSTANCE_CUSTOM.zw);
			}
		} else if (part == 5) {
			if (shape > 0.5 && shape < 1.5) {
				result = up + rotate_by((v + vec2(1.5, 0.0)) * r, INSTANCE_CUSTOM.zw);
			}
		} else if (part == 6) {
			if (shape > 1.5) {
				float angle = INSTANCE_CUSTOM.z + UV.y * 2.0943951;
				result = up + (v + vec2(cos(angle), sin(angle)) * 0.5) * r;
			}
		} else {
			if (shape > 1.5) result = up + v * r;
		}
	}
	VERTEX = result;
	v_part = float(part);
	v_kind = float(kind);
}

void fragment() {
	int part = int(v_part + 0.5);
	vec3 c = kind_color[int(v_kind + 0.5)].rgb;
	if (part == 0) {
		COLOR = vec4(0.0, 0.0, 0.0, 0.25);
	} else if (part == 1) {
		COLOR = vec4(c, 0.3);
	} else if (part == 2 || part == 4) {
		COLOR = vec4(c, 1.0);
	} else if (part == 3) {
		COLOR = vec4(mix(c, vec3(1.0), 0.6), 1.0);
	} else if (part == 5) {
		COLOR = vec4(mix(c, vec3(1.0), 0.4), 1.0);
	} else if (part == 6) {
		COLOR = vec4(c * 0.75, 1.0);
	} else {
		COLOR = vec4(c * 0.6, 1.0);
	}
}
