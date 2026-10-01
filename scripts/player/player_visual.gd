class_name PlayerVisual
extends Node2D
## Dibuja al personaje con sus piezas (cabeza, pecho, manos, pies) y las anima por código.
## Es solo visual: no guarda posición lógica ni vida. Quien lo use le dice hacia dónde mira
## (set_facing) y si anda (set_walking).

## Textura de la cabeza vista de frente y de espaldas.
@export var head_front_texture: Texture2D
@export var head_back_texture: Texture2D

@export_group("Idle")
## Ciclos por segundo del movimiento de respiración.
@export var idle_speed: float = 1.6
## Píxeles que sube y baja cada pieza.
@export var head_bob: float = 1.0
@export var chest_bob: float = 0.5
@export var hand_bob: float = 1.5
## Retraso entre piezas (en radianes) para que no se muevan todas a la vez.
@export var chest_lag: float = 0.5
@export var hand_lag: float = 1.0

@export_group("Andar")
## Pasos completos (pie izquierdo y derecho) por segundo cuando va a toda velocidad.
@export var walk_cycles_per_second: float = 2.2
## Píxeles que sube el pie al dar el paso.
@export var step_lift: float = 2.0
## Píxeles que suben y bajan las manos al andar.
@export var walk_hand_swing: float = 2.0
## Píxeles que rebotan cabeza y pecho en cada paso.
@export var walk_body_bounce: float = 1.0
## Rapidez con la que se pasa de idle a andar y al revés.
@export var walk_blend_speed: float = 10.0

@export_group("Salto")
## Altura máxima del salto en píxeles.
@export var jump_height: float = 28.0
## Cuánto se estira el cuerpo en el aire (0.12 = un 12 %).
@export var jump_stretch: float = 0.12
## Cuánto se aplasta al despegar y al aterrizar.
@export var jump_squash: float = 0.18
## Fracción del salto (0 a 0.5) que dura cada aplastamiento, al principio y al final.
@export_range(0.02, 0.5) var jump_squash_window: float = 0.12

@onready var _body: Node2D = $Body
@onready var _pieces: Node2D = $Body/Pieces
@onready var _head: Sprite2D = $Body/Pieces/Head
@onready var _chest: Sprite2D = $Body/Pieces/Chest
@onready var _hand_l: Sprite2D = $Body/Pieces/HandL
@onready var _hand_r: Sprite2D = $Body/Pieces/HandR
@onready var _foot_l: Sprite2D = $Body/Pieces/FootL
@onready var _foot_r: Sprite2D = $Body/Pieces/FootR

var _idle_time: float = 0.0
var _walk_time: float = 0.0
## 0 = quieto, 1 = andando a tope. Se suaviza hacia _walk_target.
var _walk: float = 0.0
var _walk_target: float = 0.0
var _base: Dictionary = {}
## Tamaño de la sombra (1 = en el suelo, menos = en el aire).
var _shadow_scale: float = 1.0


func _ready() -> void:
	for piece: Sprite2D in [_head, _chest, _hand_l, _hand_r, _foot_l, _foot_r]:
		_base[piece] = piece.position
	# Para que cada personaje no respire sincronizado con los demás.
	_idle_time = randf() * TAU
	set_facing(Vector2(1, 1))


func _process(delta: float) -> void:
	_walk = move_toward(_walk, _walk_target, walk_blend_speed * delta)
	_idle_time += delta * idle_speed * TAU
	_walk_time += delta * walk_cycles_per_second * TAU * _walk

	var idle := 1.0 - _walk
	var step := sin(_walk_time)
	var bounce := -absf(step) * walk_body_bounce

	_place(_head, sin(_idle_time) * head_bob * idle + bounce * _walk)
	_place(_chest, sin(_idle_time - chest_lag) * chest_bob * idle + bounce * _walk)
	_place(_hand_l, sin(_idle_time - hand_lag) * hand_bob * idle - step * walk_hand_swing * _walk)
	_place(_hand_r, sin(_idle_time - hand_lag) * hand_bob * idle + step * walk_hand_swing * _walk)
	_place(_foot_l, -maxf(0.0, step) * step_lift * _walk)
	_place(_foot_r, -maxf(0.0, -step) * step_lift * _walk)


## Mira hacia `direction` (en pantalla). Arriba = de espaldas, abajo = de frente.
## Izquierda se dibuja espejando la vista de derecha. Con un vector casi cero no cambia nada.
func set_facing(direction: Vector2) -> void:
	if direction.length_squared() < 0.01:
		return
	if absf(direction.x) > 0.01:
		_pieces.scale.x = -1.0 if direction.x < 0.0 else 1.0
	_head.texture = head_back_texture if direction.y < 0.0 else head_front_texture


## `amount` va de 0 (quieto) a 1 (a toda velocidad). Ajusta cuánto se mueven las piezas.
func set_walking(amount: float) -> void:
	_walk_target = clampf(amount, 0.0, 1.0)


## Progreso del salto de 0 (despega) a 1 (aterriza). Un valor negativo = no está saltando.
## El cuerpo sube con un arco, se estira en el aire y se aplasta al despegar y aterrizar;
## la sombra se queda en el suelo.
func set_jump_progress(progress: float) -> void:
	if progress < 0.0:
		_body.position = Vector2.ZERO
		_body.scale = Vector2.ONE
		_shadow_scale = 1.0
		queue_redraw()
		return
	var lift := sin(PI * progress)
	var squash := maxf(0.0, 1.0 - progress / jump_squash_window)
	squash += maxf(0.0, (progress - (1.0 - jump_squash_window)) / jump_squash_window)
	var scale_y := 1.0 + jump_stretch * lift - jump_squash * squash
	_body.position = Vector2(0.0, -jump_height * lift)
	_body.scale = Vector2(1.0 / scale_y, scale_y)
	_shadow_scale = 1.0 - 0.4 * lift
	queue_redraw()


## Sombra en el suelo, bajo los pies.
func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4) * _shadow_scale)
	draw_circle(Vector2.ZERO, 13.0, Color(0, 0, 0, 0.3))


func _place(piece: Sprite2D, y_offset: float) -> void:
	var base: Vector2 = _base[piece]
	piece.position = Vector2(base.x, base.y + y_offset)
