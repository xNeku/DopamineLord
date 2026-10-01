class_name SwordRainEffect
extends Node2D
## El círculo de Guerra: espadas que caen del cielo y un anillo que arrastra hacia el centro.
## Todos los jugadores lo dibujan igual porque las espadas salen de la misma semilla. El
## daño y el arrastre los aplica el host, con esas mismas espadas.

const FALL_TIME := 0.25
const STUCK_TIME := 0.5
const SKY_HEIGHT := 110.0

var data: RainSkillData
var swords: Array[Dictionary] = []
var elapsed: float = 0.0


## Las espadas de una Guerra: dónde caen (en el suelo plano, respecto al centro) y cuándo
## aterrizan. Misma semilla, mismas espadas, en cualquier máquina.
static func generate(skill: RainSkillData, seed_value: int) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var result: Array[Dictionary] = []
	for i in skill.sword_count:
		var offset := Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * (skill.radius - skill.sword_radius * 0.5)
		var land := FALL_TIME + (skill.duration - FALL_TIME) * (float(i) + rng.randf()) / skill.sword_count
		result.append({"offset": offset, "land": land})
	return result


func setup(skill: RainSkillData, seed_value: int) -> void:
	data = skill
	swords = generate(skill, seed_value)
	z_index = -1


func _process(delta: float) -> void:
	elapsed += delta
	if elapsed > data.duration + STUCK_TIME + 0.2:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, Iso.Y_SCALE))
	var fade := clampf((data.duration + 0.3 - elapsed) / 0.5, 0.0, 1.0)
	draw_circle(Vector2.ZERO, data.radius, Color(0.55, 0.3, 0.8, 0.12 * fade))
	draw_arc(Vector2.ZERO, data.radius, 0.0, TAU, 40, Color(0.75, 0.5, 1.0, 0.8 * fade), 2.0)
	# Marcas que se mueven hacia el centro: así se lee que arrastra.
	for i in 12:
		var angle := TAU * i / 12.0
		var phase := fmod(elapsed * 1.2 + float(i % 3) / 3.0, 1.0)
		var from := Vector2.from_angle(angle) * data.radius * (1.0 - phase)
		var to := Vector2.from_angle(angle) * data.radius * maxf(1.0 - phase - 0.12, 0.0)
		draw_line(from, to, Color(0.85, 0.7, 1.0, 0.6 * fade), 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	for sword in swords:
		var ground: Vector2 = Iso.to_screen(sword["offset"])
		var land: float = sword["land"]
		var since := elapsed - land
		if since < -FALL_TIME:
			continue
		if since < 0.0:
			# Cayendo: la punta baja desde el cielo.
			var t := 1.0 - (-since / FALL_TIME)
			var tip := ground + Vector2(0, -SKY_HEIGHT * (1.0 - t * t))
			draw_line(tip + Vector2(0, -26), tip, Color(0.9, 0.95, 1.0), 3.0)
			draw_circle(ground, 2.0 + 3.0 * t, Color(1, 1, 1, 0.3 * t))
		elif since < STUCK_TIME:
			# Clavada, con un destello en el impacto.
			var alpha := 1.0 - since / STUCK_TIME
			draw_line(ground + Vector2(0, -26), ground, Color(0.9, 0.95, 1.0, alpha), 3.0)
			draw_set_transform(ground, 0.0, Vector2(1.0, Iso.Y_SCALE))
			draw_circle(Vector2.ZERO, data.sword_radius * (0.4 + since * 2.0), Color(1, 1, 1, 0.35 * alpha))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
