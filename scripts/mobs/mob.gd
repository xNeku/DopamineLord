class_name Mob
extends CharacterBody2D
## Un mob. Guarda su estado y se dibuja. Quien decide qué hace (moverse, atacar, disparar,
## morir) es el MobManager del host. En los clientes es un "títere" que sigue lo que llega.
## El salto del mob grande se anima aquí, igual en el host y en los clientes.

## Solo en el host: ha aterrizado después de un salto.
signal leap_landed(mob: Mob)

const SMOOTHING := 12.0

var mob_id: int = 0
var data: MobData
var health: int = 0
var is_puppet: bool = false
## Está avisando de un golpe o de un salto (telegrafiado).
var windup: bool = false
var windup_left: float = 0.0
var attack_cooldown_left: float = 0.0
var leap_cooldown_left: float = 0.0
## Arrastre de una skill (en pantalla, px/s). Solo el host lo usa.
var pull_velocity: Vector2 = Vector2.ZERO
## Solo en el host: ya ha muerto y se está quitando. Nada más puede golpearlo.
var dying: bool = false
## Posición en el suelo plano, la que usa la rejilla del host. Se refresca cada frame.
var ground_position: Vector2 = Vector2.ZERO

var _target_position: Vector2
var _flash: float = 0.0
var _leap_from: Vector2
var _leap_to: Vector2
var _leap_windup: float = 0.0
var _leap_duration: float = 0.0
var _leap_time: float = 0.0
var _leap_active: bool = false
## Altura sobre el suelo durante el salto.
var _lift: float = 0.0


## Llamar tras fijar la posición y antes de añadirlo al árbol.
func setup(id: int, mob_data: MobData, puppet: bool) -> void:
	mob_id = id
	data = mob_data
	is_puppet = puppet
	health = data.max_health
	leap_cooldown_left = data.leap_cooldown * randf()
	name = "Mob%d" % id
	_target_position = position
	collision_layer = 2
	collision_mask = 3
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = data.radius
	shape.shape = circle
	add_child(shape)


func apply_snapshot(new_position: Vector2, new_health: int, flags: int) -> void:
	_target_position = new_position
	health = new_health
	if not _leap_active:
		windup = (flags & 1) != 0


func set_health(value: int) -> void:
	health = value
	queue_redraw()


func flash() -> void:
	_flash = 1.0


func is_leaping() -> bool:
	return _leap_active


## Empieza un salto: primero avisa (`windup`), luego vuela hasta `to` en `duration`.
func start_leap(from: Vector2, to: Vector2, windup_time: float, duration: float) -> void:
	_leap_from = from
	_leap_to = to
	_leap_windup = windup_time
	_leap_duration = duration
	_leap_time = 0.0
	_leap_active = true
	velocity = Vector2.ZERO


func _physics_process(delta: float) -> void:
	if _leap_active:
		_update_leap(delta)
	elif is_puppet:
		position = position.lerp(_target_position, 1.0 - exp(-SMOOTHING * delta))


func _update_leap(delta: float) -> void:
	_leap_time += delta
	if _leap_time < _leap_windup:
		windup = true
		return
	windup = false
	var progress := clampf((_leap_time - _leap_windup) / _leap_duration, 0.0, 1.0)
	position = _leap_from.lerp(_leap_to, progress)
	_lift = sin(PI * progress) * data.leap_height
	if progress >= 1.0:
		_leap_active = false
		_lift = 0.0
		_target_position = position
		if not is_puppet:
			leap_landed.emit(self)


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 6.0)
	if _flash > 0.0 or windup or _leap_active:
		queue_redraw()


func _draw() -> void:
	if data == null:
		return
	var radius := data.radius * 1.4
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, Iso.Y_SCALE))
	draw_circle(Vector2.ZERO, data.radius * 1.5 * (1.0 - _lift / 200.0), Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var color := data.color.lerp(Color.WHITE, _flash)
	if windup:
		color = color.lerp(Color(1.0, 0.9, 0.2), 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.03))
	var center := Vector2(0, -radius - _lift)
	draw_circle(center, radius, color)
	if data.ai == MobData.Ai.RANGED:
		draw_arc(center, radius * 0.6, -1.0, 1.0, 8, Color(0.1, 0.25, 0.1), 2.0)
	elif data.ai == MobData.Ai.LEAPER:
		draw_arc(center, radius, 0.0, TAU, 24, Color(0.35, 0.1, 0.05), 3.0)
		for i in 5:
			var angle := -PI * (0.15 + 0.7 * i / 4.0)
			draw_line(center + Vector2.from_angle(angle) * radius, center + Vector2.from_angle(angle) * (radius + 6.0), Color(0.35, 0.1, 0.05), 2.0)
	var ratio := clampf(float(health) / data.max_health, 0.0, 1.0)
	var bar := Vector2(maxf(18.0, radius * 1.8), 3)
	var top := Vector2(-bar.x * 0.5, -radius * 2.0 - 8.0 - _lift)
	draw_rect(Rect2(top, bar), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(top, Vector2(bar.x * ratio, bar.y)), Color(0.8, 0.2, 0.2))
