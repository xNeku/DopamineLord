class_name Mob
extends RefCounted
## Un mob: solo datos. No es un nodo ni un cuerpo físico, porque con cientos a la vez un nodo
## por mob sale caro (física, ordenación por Y, llamadas de dibujo). Quien lo mueve y decide qué
## hace es el MobManager del host; quien lo dibuja, todos juntos, es el MobRenderer.
## En los clientes es un "títere" que sigue lo que llega del host. El salto del mob grande se
## anima aquí, igual en el host y en los clientes.

## Solo en el host: ha aterrizado después de un salto.
signal leap_landed(mob: Mob)

const SMOOTHING := 12.0

## Posición en pantalla.
var position: Vector2 = Vector2.ZERO
## Velocidad deseada en pantalla (px/s). La pone la IA del host; el MobManager la aplica.
var velocity: Vector2 = Vector2.ZERO
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
## Empujón en curso (solo el host): velocidad en pantalla, tiempo que le queda y el daño crítico
## que recibirá si acaba fuera de la vista de `knock_crit_peer`.
var knock_velocity: Vector2 = Vector2.ZERO
var knock_left: float = 0.0
var knock_crit_damage: int = 0
var knock_crit_peer: int = 0
## Ralentización (Lluvia): multiplica su velocidad mientras `slow_left` > 0.
var slow_mult: float = 1.0
var slow_left: float = 0.0
## Posición en el suelo plano, la que usa la rejilla del host. Se refresca cada frame.
var ground_position: Vector2 = Vector2.ZERO
## Solo en el host: lo han empujado este tick y hay que escribir su posición final.
var pushed: bool = false
## Radio en el suelo plano y radio para separarse de otros mobs (copias de los datos, más baratas).
var radius: float = 8.0
var sep_radius: float = 8.0
## Para dibujarlo: tipo de mob en el MobRenderer, destello al recibir un golpe (1 → 0) y altura
## sobre el suelo durante el salto.
var kind: int = 0
var flash_amount: float = 0.0
var lift: float = 0.0

var _target_position: Vector2
var _leap_from: Vector2
var _leap_to: Vector2
var _leap_windup: float = 0.0
var _leap_duration: float = 0.0
var _leap_time: float = 0.0
var _leap_active: bool = false


## Llamar tras fijar `position`.
func setup(id: int, mob_data: MobData, puppet: bool) -> void:
	mob_id = id
	data = mob_data
	is_puppet = puppet
	health = data.max_health
	radius = data.radius
	sep_radius = data.radius * MobManager.SEPARATION
	leap_cooldown_left = data.leap_cooldown * randf()
	_target_position = position


func apply_snapshot(new_position: Vector2, new_health: int, flags: int) -> void:
	_target_position = new_position
	health = new_health
	if not _leap_active:
		windup = (flags & 1) != 0


func set_health(value: int) -> void:
	health = value


func flash() -> void:
	flash_amount = 1.0


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


## Una vez por tick de física, solo en los mobs que lo necesitan: los títeres de los clientes
## (suavizan hacia lo que manda el host) y los que están saltando.
func step(delta: float) -> void:
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
	lift = sin(PI * progress) * data.leap_height
	if progress >= 1.0:
		_leap_active = false
		lift = 0.0
		_target_position = position
		if not is_puppet:
			leap_landed.emit(self)
