class_name BotInput
extends Node
## Controla a un Player como lo haría un jugador: camina en cuadrado y salta cada pocos
## segundos. Sirve para probar el coop con varias instancias en la misma máquina.

const ROUTE: Array[Vector2] = [Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0), Vector2(0, -1)]
const LEG_SECONDS := 1.5
const JUMP_EVERY := 2.5

var _time: float = 0.0
var _next_jump: float = JUMP_EVERY
var _next_skill: float = 1.0
var _skill_slot: int = 0

@onready var _player: Player = get_parent()


func _physics_process(delta: float) -> void:
	_time += delta
	var direction := ROUTE[int(_time / LEG_SECONDS) % ROUTE.size()]
	_player.set_move_order(direction)
	_player.request_attack(direction)
	if _time >= _next_skill:
		_next_skill += 1.2
		_player.request_skill(_skill_slot % 4, direction, _player.position + Iso.to_screen(direction * 70.0))
		_skill_slot += 1
	if _time >= _next_jump:
		_next_jump += JUMP_EVERY
		_player.request_jump(direction)
