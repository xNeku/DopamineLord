class_name PlayerVisual
extends Node2D
## Dibuja al personaje con sus piezas (cabeza, pecho, manos, pies) y las anima por código.
## Es solo visual: no guarda posición lógica ni vida. Quien lo use lo mueve y le dice hacia
## dónde mira con set_facing().

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

@onready var _pieces: Node2D = $Pieces
@onready var _head: Sprite2D = $Pieces/Head
@onready var _chest: Sprite2D = $Pieces/Chest
@onready var _hand_l: Sprite2D = $Pieces/HandL
@onready var _hand_r: Sprite2D = $Pieces/HandR

var _time: float = 0.0
var _base: Dictionary = {}


func _ready() -> void:
	for piece: Sprite2D in [_head, _chest, _hand_l, _hand_r]:
		_base[piece] = piece.position
	# Para que cada personaje no respire sincronizado con los demás.
	_time = randf() * TAU
	set_facing(Vector2(1, 1))


func _process(delta: float) -> void:
	_time += delta * idle_speed * TAU
	_bob(_head, 0.0, head_bob)
	_bob(_chest, chest_lag, chest_bob)
	_bob(_hand_l, hand_lag, hand_bob)
	_bob(_hand_r, hand_lag, hand_bob)


## Mira hacia `direction` (en pantalla). Arriba = de espaldas, abajo = de frente.
## Izquierda se dibuja espejando la vista de derecha. Con un vector casi cero no cambia nada.
func set_facing(direction: Vector2) -> void:
	if direction.length_squared() < 0.01:
		return
	if absf(direction.x) > 0.01:
		_pieces.scale.x = -1.0 if direction.x < 0.0 else 1.0
	_head.texture = head_back_texture if direction.y < 0.0 else head_front_texture


func _bob(piece: Sprite2D, lag: float, amount: float) -> void:
	var base: Vector2 = _base[piece]
	piece.position = Vector2(base.x, base.y + sin(_time - lag) * amount)
