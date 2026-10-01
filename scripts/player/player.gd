class_name Player
extends CharacterBody2D
## Un jugador. Aquí vive la lógica (posición, movimiento, salto); lo visual está en
## PlayerVisual. No lee el input: recibe órdenes (set_move_order, request_jump). Así, en red,
## las órdenes de un jugador remoto pueden llegar de otro sitio y esta clase no cambia.

## Capas de colisión (los nombres están en Proyecto > Ajustes > Nombres de capas).
## Mundo: paredes y todo lo que bloquea incluso un salto. Cuerpos: mobs, árboles, minerales,
## que se pueden saltar por encima.
const LAYER_WORLD := 1
const LAYER_BODIES := 2
const LANDING_STEP := 4.0

@export_group("Movimiento")
## Velocidad en píxeles de pantalla por segundo (horizontalmente).
@export var move_speed: float = 90.0
## Proporción de la velocidad vertical respecto a la horizontal. 0.5 porque el tile es 64×32.
@export var iso_y_scale: float = 0.5

@export_group("Salto")
## Distancia del salto en segundos de carrera: distancia = move_speed × este valor.
@export var jump_distance_in_seconds: float = 1.2
## Tope de distancia, para que un buff de velocidad no lo convierta en teletransporte.
@export var jump_max_distance: float = 160.0
## Lo que dura el salto en el aire.
@export var jump_duration: float = 0.4
## Espera entre un salto y el siguiente, desde que aterrizas.
@export var jump_cooldown: float = 0.8

## Orden actual de movimiento: dirección en pantalla, con longitud de 0 a 1.
var move_order: Vector2 = Vector2.ZERO
## Última dirección en la que miró o se movió.
var facing: Vector2 = Vector2(1, 1)
var is_jumping: bool = false
var jump_cooldown_left: float = 0.0

var _jump_from: Vector2
var _jump_to: Vector2
var _jump_time: float = 0.0

@onready var visual: PlayerVisual = $PlayerVisual
@onready var _shape: CollisionShape2D = $CollisionShape2D


func set_move_order(direction: Vector2) -> void:
	move_order = direction.limit_length(1.0)
	if move_order.length_squared() > 0.01:
		facing = move_order


## Orden de saltar hacia `direction` (dirección en pantalla). Devuelve false si no puede:
## ya está en el aire, en recarga, o no hay sitio donde aterrizar.
func request_jump(direction: Vector2) -> bool:
	if is_jumping or jump_cooldown_left > 0.0:
		return false
	if direction.length_squared() < 0.01:
		direction = facing
	var distance := minf(move_speed * jump_distance_in_seconds, jump_max_distance)
	var wanted := position + direction.normalized() * Vector2(1.0, iso_y_scale) * distance
	var landing := _resolve_landing(position, wanted)
	if landing.distance_to(position) < LANDING_STEP:
		return false
	_jump_from = position
	_jump_to = landing
	_jump_time = 0.0
	is_jumping = true
	facing = direction
	return true


func _physics_process(delta: float) -> void:
	if is_jumping:
		_update_jump(delta)
	else:
		jump_cooldown_left = maxf(0.0, jump_cooldown_left - delta)
		var motion := move_order * move_speed
		motion.y *= iso_y_scale
		velocity = motion
		move_and_slide()
		visual.set_walking(move_order.length())

	visual.set_facing(facing if is_jumping else move_order)


## El salto es comprometido: no se puede dirigir en el aire. Va directo de origen a destino
## sin colisionar con nada, porque el destino ya se comprobó al despegar.
func _update_jump(delta: float) -> void:
	_jump_time += delta
	var progress := clampf(_jump_time / jump_duration, 0.0, 1.0)
	position = _jump_from.lerp(_jump_to, progress)
	visual.set_jump_progress(progress)
	visual.set_walking(0.0)
	if progress >= 1.0:
		is_jumping = false
		jump_cooldown_left = jump_cooldown
		visual.set_jump_progress(-1.0)


## Acorta el salto si hace falta: se para antes de una pared y, si el destino cae sobre un
## cuerpo (mob, árbol, mineral), retrocede hasta el último hueco libre.
func _resolve_landing(from: Vector2, to: Vector2) -> Vector2:
	var steps := maxi(1, ceili(from.distance_to(to) / LANDING_STEP))
	var points: Array[Vector2] = []
	for i in range(steps + 1):
		points.append(from.lerp(to, float(i) / steps))

	var last := 0
	for i in range(1, steps + 1):
		if _overlaps(points[i], 1 << (LAYER_WORLD - 1)):
			break
		last = i

	var solid_mask := (1 << (LAYER_WORLD - 1)) | (1 << (LAYER_BODIES - 1))
	while last > 0 and _overlaps(points[last], solid_mask):
		last -= 1
	return points[last]


func _overlaps(point: Vector2, mask: int) -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _shape.shape
	query.transform = Transform2D(0.0, point)
	query.collision_mask = mask
	query.exclude = [get_rid()]
	return not get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()
